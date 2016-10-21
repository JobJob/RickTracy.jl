module RickTracy

export TraceItem,
@snap, @snapat, @snapNth, @snapatNth, snap_everyNth,
@initsnaps, @snapall, @snapallat,
@clearsnaps, brandnewsnaps, clearsnaps, next_global_location,
snaps_at, @snaps_at, snapvals, @snapvals, snapitems, @snapitems,
allsnaps, @allsnaps, _num_trace_locations, happysnaps

using DataStructures

type TraceItem{T}
    location::String
    exprstr::String
    val::T
    ts::Float64 #time stamp
end
TraceItem{T}(location, exprstr, val::T) = TraceItem{T}(location, exprstr, val, time())

_num_trace_locations = 0

__init__() = begin
    global _num_trace_locations = 0
    global location_counts = DefaultDict(String, Int, 0) #number of times tracepoint at each location has been hit (but not necessarily logged)
    global tracked_exprs = Dict{String, Bool}()
    global happysnaps = Vector{TraceItem}()
    global autotrack = true
end

next_global_location() = begin
    global _num_trace_locations
    _num_trace_locations += 1
    "$_num_trace_locations"
end

brandnewsnaps() = begin
    empty!(happysnaps)
    empty!(location_counts)
    empty!(tracked_exprs)
    global _num_trace_locations = 0
end

clearsnaps(exprstr) = begin
    #find snaps that match key, and remove them from the happysnaps vector
    filter!((st)->st.exprstr == exprstr, happysnaps) #slow
end

set_autotrack(on::Bool) = global autotrack = on
get_autotrack() = autotrack

"""
adds a trace entry in happy snaps
adds exprstr to set of tracked expressions
"""
snap_everyNth(location, N, exprstrs, vals) = begin
#     @show "-------------" location N exprstrs vals
    location_counts[location]%N == 0 &&
        for (exprstr, val) in zip(exprstrs, vals)
            snap(location, exprstr, val)
            tracked_exprs[exprstr] = true
        end
    location_counts[location] += 1
end

snap(location, exprstr, val) = push!(happysnaps, TraceItem(location, exprstr, val))

#helpers
pluck(objarr, sym) = map((obj)->getfield(obj, sym), objarr)

# get snaps
snaps_at(location) = filter((ti)->ti.location == "$location", happysnaps)
snapitems(exprstr) = filter((ti)->ti.exprstr == exprstr, happysnaps)
snapvals(exprstr) = pluck(snapitems(exprstr), :val)
allsnaps() = copy(happysnaps)

macro snaps_at(location_expr)
    locstr = "$location_expr"
    :(snaps_at($locstr))
end

macro snapvals(expr)
    exprstr = "$expr"
    :(snapvals($exprstr))
end

macro snapitems(expr)
    exprstr = "$expr"
    :(snapitems($exprstr))
end

macro allsnaps() :(allsnaps()) end

macro clearsnaps()
    :(brandnewsnaps())
end

macro initsnaps(exprs...)
    res = :()
    for expr in exprs
        exprstr = "$expr" #expr as a string
        res = :($res; clearsnaps($exprstr))
    end
    res |> esc
end

"""
Very similar to just calling @snapAtNth in the loop
"""
macro snapallatNth(location, N)
    res = quote
        exprstrs = []; vals=[]
        for exprstr in keys(tracked_exprs)
            push!(exprstrs, exprstr)
            push!(vals, eval(parse(exprstr)))
        end
        snap_everyNth($location, $N, exprstrs, vals) #eval(parse(exprstr)))
    end
    res = :($res; happysnaps)
    res |> esc
end

macro snapall()
    location = next_global_location()
    :(@snapallatNth($location, 1)) |> esc
end

macro snapallat(location)
    :(@snapallatNth($location, 1)) |> esc
end

macro snapatNth(location, N, exprs)
    res = :(exprstrs = []; vals=[])
    for expr in exprs
        exprstr = "$expr"
        res = :($res; push!(exprstrs, $exprstr); push!(vals, $expr))
    end
    res = :($res; snap_everyNth($location, $N, exprstrs, vals))
    res = :($res; happysnaps)
    res |> esc
end

"""
Take a snap/trace of a variable/expression.
e.g.

    fred = "flintstone"
    barney = 10

    @snap fred barney
    @snapvals fred

outputs:

    1-element Array{String,1}:
    "flintstone"

By default the variable/expression will be added to the watch list,
and logged/snapped on subsequent calls to @snapall. To disable this
behaviour call RickTracy.set_autotrack(false).

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

see `@snap` docs for more details
"""
macro snapNth(N, exprs...)
    location = next_global_location() #initialised once each location @snap is called (at compile time)
    :(@snapatNth($location, $N, $exprs)) |> esc
end

"""
Take a snap/trace of a variable/expression, and provide a location
String to identify the trace site.

e.g.

    fred = "flintstone"
    barney = 10
    @snapat "bedrock" fred barney
    @snaps_at "bedrock"

outputs:

    TraceItem{String}("bedrock","fred","flintstone",1.47705e9)
    TraceItem{Int64}("bedrock","barney",10,1.47705e9)

also useful try:

    @snapat @__LINE__ fred barney

see `@snap` docs for more details
"""
macro snapat(location, exprs...)
    :(@snapatNth($location, 1, $exprs)) |> esc
end

"""
NOT WORKING YET, if it did work, prob good to just make this the default for @snap
Waiting on https://github.com/JuliaLang/julia/issues/9577


Take a snap/trace of a variable/expression, setting the line
number as the location
e.g.

    fred = "flintstone"
    barney = 10
    @snapln fred barney

see `@snap` docs for more details
"""
macro snapln(exprs...)
    :(@snapatNth(string(@__LINE__), 1, $exprs)) |> esc
end

end
