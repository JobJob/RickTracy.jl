# RickTracy
This package makes it easy to trace the values of variables over the runtime of your program, and provides some tools to use these traces to analyse your code or the system you are modelling.

#### Tracing
```
@watch i j excitement  # set the variables you want to trace
for i in 1:10
   for j in 1:10
      excitement = i*j
      @snapall  # take a snapshot of their values
   end
end

#save them to disk if you like
savetraces(path="sometraces.jld")
```

#### Analysis

The `@replay` macro is a bit like a poor man's reversible debugger; it uses [Interact](https://github.com/JuliaGizmos/Interact.jl) to allow you to step forward and backward through "time" (trace points in your program) and automatically assigns the variables traced in the original program to the values they had, enabling easier analysis:
```
loadtraces(path="sometraces.jld")
res = @replay (i,j)->begin
   "when i was $i and j was $j excitement was $excitement"
end
```
![replay demo in IJulia](/images/replay_excitement_med.gif?raw=true "replay demo in IJulia")

You can also export your traces as a DataFrame for arbitrary querying and use convenience functions to easily plot values of your variables over time, or under specific conditions.

It's still a little immature, but so far I've found it helpful in analysing both simulation code and algorithms for agent learning in virtual enviroments.

### Warning

The package is pretty rough around the edges and is relatively untested, so there's every chance lots of things won't work. Please feel free to report bugs and submit PRs.

(Also: this README contains bad Rick and Morty references)

### Install
`Pkg.clone("https://github.com/JobJob/RickTracy.jl")`

### Basic Usage
```
using RickTracy

for i in 1:10
    @snap i i^2
    @snap location=mrmeeseeks i^2 i^3
    @snap loc=morty "$i personal space"
end

@plotvals i i^2
```
![i and i^2 graph](/images/plotvalsii^2.png?raw=true "i and i^2 graph")

To get the values of all traced expressions at a named location use
```
@tracevals location=morty
```
n.b. `loc=morty` or `l=morty` both work in place of `location=morty`

Returns:
```
10-element Array{String,1}:
 "1 personal space"
 "2 personal space"
 "3 personal space"
 "4 personal space"
 "5 personal space"
 "6 personal space"
 "7 personal space"
 "8 personal space"
 "9 personal space"
 "10 personal space"
```

Other ways to specify a trace location name:
```
@snap location="descriptive location name" var1 var2
#or
@snap l=@__LINE__ var1 var2 #n.b. @__LINE__ gives the line num in the src file
```
To get all (or some of) your traces as a DataFrame, use `@tracesdf`, e.g.:
```
@tracesdf
@tracesdf loc=morty
@tracesdf i i^2
```

### Conditional Tracing
Sometimes you only want to take a snapshot/trace every, say, 12th time the line is hit, to do so use `@snap everyN=12` or simply `@snap N=12` (`every` and `N` are valid aliases for  `everyN`)

##### Example

The following takes a snap/trace of a variable/expression every 2 times
the tracepoint is hit:

    for person in ["wilma", "fred", "betty", "barney"]
        @snap N=2 person
    end
    @tracevals person

returns:

    2-element Array{String,1}:
     "wilma"
     "betty"

Conditional tracing can be done using the `iff` keyword (aliases: `when`, `onlyif`):
```
@resetallsnaps
for i in 1:10
    #snap every third iteration
    @snap i iff=(i%3 == 0)

    #don't snap every 4th iteration, and only if i < 5
    @snap i loc=loopcity when=i%2 != 0 && i < 5
end
@tracevals i
```
results in:
```
6-element Array{Int64,1}:
 1
 2
 3
 3
 6
 9
```
 a subsequent call to `@tracevals loc=loopcity i` gives:
```
 2-element Array{Int64,1}:
1
3
```

### Accessing your Traces
Use the commands below to return traces in various formats. When called with no arguments all traces are returned. To limit the results to a specific location and expressions, append `loc=some_location expr1 expr2 expr3 ...` to the command.

---

```
@tracevals [loc=some_location] [expr1] [expr2] [expr3] ...
```
returns a vector of the values of traced expressions. E.g.

```
@tracevals
```
returns a single vector containing the values of all traced expressions at all locations.
```
@tracevals loc=loopcity i
```
returns the values of variable `i` at location `loopcity`

---

```
@plotvals [loc=any_location] [expr1] [expr2] [expr3] ...
```
returns a plot of the values of all traced expressions.
N.b. will break if any values are non-numeric and probably in
lots of other cases too.

---

```
@tracevalsdic [loc=a_location] [expr1] [expr2] [expr3] ...
```
returns a Dict mapping expressions=>the values the traced variables/expressions took.

---

```
@tracesdf [loc=any_location] [expr1] [expr2] [expr3] ...
```
returns a DataFrame with columns `:location`, `:exprstr`, `:val`, `:ts`, with each row holding a single snapshot of one expression at one trace location.

---

```
@tracesdic [loc=any_location] [expr1] [expr2] [expr3] ...
```
returns a `Dict{Symbol, Vector{Any}}` with keys `:location`, `:exprstr`, `:val`, `:ts`, with values being a vector of the value for that field for all snaps.

---

```
@traceitems [loc=any_location] [expr1] [expr2] [expr3] ...
```
returns a Vector of all the raw `TraceItem ` snaps.

#### The TraceItem type
Here's the definition of the `TraceItem` type:
```
type TraceItem{T}
    location::String
    exprstr::String
    val::T
    ts::Float64 #time stamp
end
```

---

### Watch and Snapall

 If you have a number of variables of interest that you want to snap at multiple locations in your code, you can use the combination of `@watch`, `@snapall` to easily take snapshots of all their values.

Example:
```
@watch fred barney bambam

fred = "1"
barney = "2"
bambam = "3"
@snapall

for i in 1:10
    fred = 2i
    barney = 10i
    bambam = 100i
    @snapall
end
@tracevals bambam
```
returns:
```
11-element Array{Any,1}:
"3"
100
200
300
400
500
600
700
800
900
1000
```
Note that by default `@snap` adds each variable/expression passed to it to the watch list. These variables/expressions will then be logged/snapped on calls to `@snapall` that are below the `@snap` (i.e. are parsed/loaded later than the `@snap` call). You can disable the autowatch behaviour with
`RickTracy.set_autowatch(false)` somewhere near the top of your code.

Example

```
rick = 9001
morty = 0
@snap rick
for i in 1:5
    morty = i
    rick += i
    @snapall
    @snap morty
end
@tracevals rick
```
returns:

```
6-element Array{Int64,1}:
 9001
 9002
 9004
 9007
 9011
 9016
 ```

Note that `@tracevals morty` returns:
```
5-element Array{Int64,1}:
1
2
3
4
5
```
i.e. `morty` is only logged with the explicit call to `@snap morty`, not the `@snapall`  (else `@tracevals morty` would return [1,1,2,2,3,3,...]). This is despite the fact that the `@snap morty` call in the first loop iteration precedes the `@snapall` in the second iteration at runtime. The key take away is that `@snapall` only logs expressions `@watch`ed or `@snap`ped above it (compiled before it), since the adding of expressions to the watch list happens at compile/macro-expansion time, not at runtime.

#### Related functions
`@unwatch expr`: stop watching an expression

`@unwatchall`: clear the watchlist

### Clearance (Clarence)
`@clearsnaps expr`: delete all the snapshots for an expression

`@clearallsnaps`: delete all the snapshots for all expressions

`@resetallsnaps`: delete all the snapshots for all expressions, clear all location counters (for everyN qualifiers), remove all watched expressions.
