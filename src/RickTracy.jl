module RickTracy

export TraceItem,
@snap, @snapat, @snapNth, @snapatNth, snap_everyNth, @snapif, @snapifat,
@watch, @unwatch, @unwatchall, @snapall, @snapallat, @snapallatNth,
clearsnaps, @clearsnaps, @clearallsnaps, brandnewsnaps!, next_global_location,
snapsat, @snapsat, snapvals, @snapvals, snapitems, @snapitems,
snapsatvals, @snapsatvals,
allsnaps, @allsnaps, _num_trace_locations, happysnaps

using DataStructures

type TraceItem{T}
    location::String
    exprstr::String
    val::T
    ts::Float64 #time stamp
end
TraceItem{T}(location, exprstr, val::T) = TraceItem{T}(location, exprstr, val, time())

__init__() = begin
    global _num_trace_locations = 0
    global location_counts = DefaultDict(String, Int, 0) #number of times tracepoint at each location has been hit (but not necessarily logged)
    global watched_exprs = Dict{String, Bool}()
    global happysnaps = Vector{TraceItem}()
    global autowatch = true
end

###############################################################################
# Clearance Clarence
###############################################################################

brandnewsnaps!() = begin
    empty!(happysnaps)
    empty!(location_counts)
    empty!(watched_exprs)
    global _num_trace_locations = 0
end

macro clearallsnaps()
    :(brandnewsnaps!()) |> esc
end

clearsnaps(exprstr) = begin
    #find snaps that match key, and remove them from the happysnaps vector
    filter!((st)->st.exprstr == exprstr, happysnaps) #slow
end

macro clearsnaps(exprs...)
    res = :()
    for expr in exprs
        exprstr = "$expr" #expr as a string
        res = :($res; clearsnaps(exprstr))
    end
    res |> esc
end

macro clearunwatch(exprs...)
    :(@unwatch exprs; @clearsnaps(exprs)) |> esc
end

###############################################################################
# Trace View/Accessor Functions
###############################################################################
snapsat(location) = filter((ti)->ti.location == "$location", happysnaps)
snapitems(exprstr) = filter((ti)->ti.exprstr == exprstr, happysnaps)
snapvals(exprstr) = pluck(snapitems(exprstr), :val)
snapsatvals(location, exprstr) = begin
    snapitems = filter(happysnaps) do (ti)
        ti.exprstr == exprstr && ti.location == location
    end
    pluck(snapitems, :val)
end
allsnaps() = copy(happysnaps)

macro snapsat(location_expr)
    locstr = "$location_expr"
    :(snapsat($locstr)) |> esc
end

macro snapsatvals(location_expr, expr)
    locstr = "$location_expr"
    exprstr = "$expr"
    :(snapsatvals($locstr, $exprstr)) |> esc
end

macro snapvals(expr)
    exprstr = "$expr"
    :(snapvals($exprstr)) |> esc
end

macro snapitems(expr)
    exprstr = "$expr"
    :(snapitems($exprstr)) |> esc
end

###############################################################################
# Watched Expressions / Snapall
###############################################################################
set_autowatch(on::Bool) = global autowatch = on
get_autowatch() = autowatch

watched_exprstrs() = keys(watched_exprs)

watch_exprstr(exprstr) = begin
    watched_exprs[exprstr] = true
end

unwatch_exprstr(exprstr) = begin
    delete!(watched_exprs, exprstr)
end

macro watch(exprs...)
    for expr in exprs
        exprstr = "$expr" #expr as a string
        watch_exprstr(exprstr) #called at macro expansion time, not run time
    end
    :()
end

macro unwatch(exprs...)
    for expr in exprs
        exprstr = "$expr" #expr as a string
        unwatch_exprstr(exprstr)
    end
    :()
end

macro unwatchall()
    empty!(watched_exprs)
    :()
end

macro allsnaps()
    :(allsnaps()) |> esc
end

"""
A little too much like snapatNth for my liking
"""
macro snapallatNth(location, N)
    exprs = map(parse, watched_exprstrs())
    :(@snapatNth $location $N $exprs) |> esc
end

macro snapall()
    location = next_global_location()
    :(@snapallatNth($location, 1)) |> esc
end

macro snapallat(location)
    :(@snapallatNth($location, 1)) |> esc
end

###############################################################################
# Make regular snaps
###############################################################################
"""
adds a trace entry in happysnaps for each expr in exprstrs with
corresponding val from vals
"""
snap_everyNth(location, N, exprstrs, vals) = begin
#     @show "-------------" location N exprstrs vals
    location_counts[location]%N == 0 &&
        for (exprstr, val) in zip(exprstrs, vals)
            snap(location, exprstr, val)
        end
    location_counts[location] += 1
end

snap(location, exprstr, val) = push!(happysnaps, TraceItem(location, exprstr, val))

macro snapatNth(location, N, exprs)
    res = :(exprstrs = []; vals=[])
    for expr in exprs
        exprstr = "$expr"
        res = :($res; push!(exprstrs, $exprstr); push!(vals, $expr))
        autowatch && watch_exprstr(exprstr) #called at macro expansion time, not run time
    end
    res = :($res; snap_everyNth($location, $N, exprstrs, vals))
    res = :($res; happysnaps)
    res |> esc
end

"""
Take a snap/trace of a variable/expression.
#example

    fred = "flintstone"
    barney = 10

    @snap fred barney
    @snapvals fred

outputs:

    1-element Array{String,1}:
    "flintstone"

By default the variable/expression will be added to the watch list,
and logged/snapped on calls to `@snapall` that are parsed/loaded later than
this call.. To disable this behaviour call RickTracy.set_autowatch(false).

A numbered location string will be added to the trace entry to identify
the code location. To specify your own location use:

    @snapat "decriptive location name" var1 var2
    #or
    @snapat @__LINE__ var1 var2
"""
macro snap(exprs...)
    location = next_global_location() #initialised once each location @snap is called (at compile time)
    :(@snapatNth($location, 1, $exprs)) |> esc
end

"""
Take a snap/trace of a variable/expression every N times
the tracepoint is passed
#example

    for person in ["wilma", "fred", "betty", "barney"]
        @snapNth 2 person
    end
    @snapvals person

returns:

    2-element Array{String,1}:
     "wilma"
     "betty"

By default the variable/expression will be added to the watch list,
and logged/snapped on calls to `@snapall` that are parsed/loaded later than
this call.. To disable this behaviour call RickTracy.set_autowatch(false).
"""
macro snapNth(N, exprs...)
    location = next_global_location() #initialised once each location @snap is called (at compile time)
    :(@snapatNth($location, $N, $exprs)) |> esc
end

"""
Take a snap/trace of a variable/expression, and provide a location
String to identify the trace site.

#example

    fred = "flintstone"
    barney = 10
    @snapat "bedrock" fred barney
    @snapsat "bedrock"

outputs:

    TraceItem{String}("bedrock","fred","flintstone",1.47705e9)
    TraceItem{Int64}("bedrock","barney",10,1.47705e9)

also useful try:

    @snapat @__LINE__ fred barney

By default the variable/expression will be added to the watch list,
and logged/snapped on calls to `@snapall` that are parsed/loaded later than
this call.. To disable this behaviour call RickTracy.set_autowatch(false).
"""
macro snapat(location, exprs...)
    :(@snapatNth($location, 1, $exprs)) |> esc
end

"""
`snapif(condexpr, exprs...)`

Take a snap/trace of a variable/expression, iff condition evaluates
to true

#example

    for i in 1:10
        @snapif i%3 == 0 i
    end
    @snapvals i

outputs:

    3-element Array{Int64,1}:
     3
     6
     9

 By default the variable/expression will be added to the watch list,
 and logged/snapped on calls to `@snapall` that are parsed/loaded later than
this call.. To disable this behaviour call RickTracy.set_autowatch(false).
"""
macro snapif(condexpr, exprs...)
    location = next_global_location()
    :(if $condexpr
            @snapatNth($location, 1, $exprs)
    end) |> esc
end

"""
`snapifat(condexpr, location, exprs...)`

Take a snap/trace of a variable/expression, iff condition evaluates
to true, and set location at the location provide

#example

    for i in 1:10
        @snapifat i%3 == 0 "looptown" i
    end
    @snapsat "looptown"

outputs:

    3-element Array{RickTracy.TraceItem,1}:
     RickTracy.TraceItem{Int64}("looptown","i",3,1.47711e9)
     RickTracy.TraceItem{Int64}("looptown","i",6,1.47711e9)
     RickTracy.TraceItem{Int64}("looptown","i",9,1.47711e9)

 By default the variable/expression will be added to the watch list,
 and logged/snapped on calls to `@snapall` that are parsed/loaded later than
 this call.. To disable this behaviour call RickTracy.set_autowatch(false).
"""
macro snapifat(condexpr, location, exprs...)
    :(if $condexpr
        @snapatNth($location, 1, $exprs)
    end) |> esc
end

"""
NOT WORKING YET, if it did work, prob good to just make this the default for @snap
Waiting on https://github.com/JuliaLang/julia/issues/9577


Take a snap/trace of a variable/expression, setting the line
number as the location
#example

    fred = "flintstone"
    barney = 10
    @snapln fred barney

see `@snap` docs for more details
"""
macro snapln(exprs...)
    :(@snapatNth(string(@__LINE__), 1, $exprs)) |> esc
end

###############################################################################
# Helpers
###############################################################################
pluck(objarr, sym) = map((obj)->getfield(obj, sym), objarr)

next_global_location() = begin
    global _num_trace_locations
    _num_trace_locations += 1
    "$_num_trace_locations"
end
end
