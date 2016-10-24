# RickTracy
*Futuristic* Code Tracing for Julia

## Intro
This package makes it easy to trace values of your variables (or other expressions) over time.

Example use cases:
* debugging
* logging
* storing values of multiple variables over time, without having to create your own Arrays/Dicts/etc for each variable, e.g. in simulation code

Basic usage:

    Pkg.clone("https://github.com/JobJob/RickTracy.jl")
    using RickTracy

    fred = "flintstone"
    barney = 10

    #take a snapshot of the values of the variables fred and barney
    @snap fred barney
    @tracevals fred

outputs:

    1-element Array{String,1}:
    "flintstone"

A numbered location string will be added to the trace entry to identify
the code location.

    @tracevalsat 1 barney

outputs:

    1-element Array{Int64,1}:
    10

To specify your own location use:

    @snapat "decriptive location name" var1 var2
    #or try
    @snapat @__LINE__ var1 var2

Sometimes you only want to trace every say 12th time the line is hit, to do so use `@snapNth`

e.g. the following takes a snap/trace of a variable/expression every 2 times
the tracepoint is hit:

    for person in ["wilma", "fred", "betty", "barney"]
        @snapNth 2 person
    end
    @tracevals person

returns:

    2-element Array{String,1}:
     "wilma"
     "betty"

Conditional tracing can be done using the `@snapif` and `@snapifat`
for example:

    for i in 1:10
        @snapif i%3 == 0 i
        @snapifat i%4 ==0 i
    end
    @tracevals i

results in:

    5-element Array{Int64,1}:
     3
     4
     6
     8
     9
a subsequent call to `@tracevalsat "loopcity" i` gives:

    2-element Array{Int64,1}:
    4
    8

 By default the variable/expression will be added to the watch list,
 and logged/snapped on calls to `@snapall` that are parsed/loaded later than
 any calls to any of the `@snap...` macros. To disable this behaviour call
 RickTracy.set_autowatch(false).

`@snapall` example:

    @watch fred barney bambam

    fred = "1"
    barney = "2"
    bambam = "3"
    @snapall

    for i in 1:10
        fred = 2*i
        barney = 10*i
        bambam = 100*i
        @snapall
    end
    @tracevals bambam

outputs:

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
