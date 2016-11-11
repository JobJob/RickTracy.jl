# RickTracy
### Intro
This package makes it easy to trace values of your variables (or other expressions) throughout the runtime of our program.

Example use cases:
* debugging
* logging
* easily recording the progression of values for variables of interest, e.g. in simulation code

###Install
`Pkg.clone("https://github.com/JobJob/RickTracy.jl")`

###Basic usage
```
using RickTracy

for i in 1:10
    @snap i i^2
    @snap loc=morty "$i personal space"
end

@plotexprvals i^2
```
![i^2 graph](/images/i^2 graph.png?raw=true "i^2 graph")

To get the values of all traces at a named location use
```
@tracevals location=morty
```
n.b. `loc` and `l` are valid aliases for the `location` keyword.

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
@snap location="decriptive location name" var1 var2
#or
@snap loc=@__LINE__ var1 var2
```
To get all your traces as a DataFrame:
```
@tracesdf
#or
@tracesdf loc=morty
#or
@tracesdf i i^2
```

###Conditional Tracing
Sometimes you only want to trace every, say, 12th time the line is hit, to do so use `@snap everyN=12` or simply `@snap N=12` (`every` and `N` are valid aliases for  `everyN`)

#####Example:

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
N.b. all commands that return your trace results below, can generally be limited to a particular tracepoint location or expression(s), using loc=some_location and the expression(s).
`@tracevals [loc=some_location] [expr1] [expr2] [expr3] ...`: returns a vector of the values of all traced expressions at all tracepoints.

`@plotexprvals [loc=any_location] [expr1] [expr2] [expr3] ...`: Make a plot of the values of all traced expressions.
N.b. will break if any values are non-numeric and probably in
lots of other cases too.

`@tracevalsdic [loc=a_location] [expr1] [expr2] [expr3] ...`: returns a Dict mapping expressions=>values all traced variables/expressions took.

`@tracesdf [loc=any_location] [expr1] [expr2] [expr3] ...`: returns a DataFrame with columns `:location`, `:exprstr`, `:val`, `:ts`, with each row holding a single snapshot of one expression at one trace location.

`@tracesdic [loc=any_location] [expr1] [expr2] [expr3] ...`: returns a Dict{Symbol, Vector{Any}} with keys `:location`, `:exprstr`, `:val`, `:ts`, with values being a vector of the value for that field for all snaps.

`@traceitems [loc=any_location] [expr1] [expr2] [expr3] ...`: returns a Vector of all the raw `TraceItem ` snaps.

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

###Clearance (Clarence)
`@clearsnaps expr`: delete all the snapshots for an expression

`@clearallsnaps`: delete all the snapshots for all expressions

`@resetallsnaps`: delete all the snapshots for all expressions, clear all location counters (for everyN qualifiers), remove all watched expressions.
