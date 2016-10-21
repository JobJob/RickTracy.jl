# RickTracy
*Futuristic* Code Tracing for Julia

Basic usage:
    Pkg.clone("https://github.com/JobJob/RickTracy")
    using RickTracy

    fred = "flintstone"
    barney = 10

    @snap fred barney
    @snapvals fred

outputs:

    1-element Array{String,1}:
    "flintstone"

A numbered location string will be added to the trace entry to identify
the code location.

    @snapsat 1

outputs:

    2-element Array{RickTracy.TraceItem,1}:
     RickTracy.TraceItem{String}("1","fred","flintstone",1.47706e9)
     RickTracy.TraceItem{Int64}("1","barney",10,1.47706e9)

To specify your own location use:

    @snapat "decriptive location name" var1 var2
    #or try
    @snapat @__LINE__ var1 var2

Sometimes you only want to trace every 12th time, to do so use `@snapNth`

Take a snap/trace of a variable/expression every N times
the site
e.g.

    for person in ["wilma", "fred", "betty", "barney"]
        @snapNth 2 person
    end
    @snapvals person

returns:

    2-element Array{String,1}:
     "wilma"
     "betty"


By default all variables/expressions `@snap`ed will be added to the watch list,
and logged/snapped on subsequent calls to `@snapall`. To disable this
behaviour call RickTracy.set_autotrack(false)

`@snapall` example:

    @initsnaps fred barney bambam

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
    @snapvals bambam

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
