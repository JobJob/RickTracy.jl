###############################################################################
# Trace View/Accessor Functions
###############################################################################
export @tracevals, @traceitems, @tracevalsdic, @tracesdf, @tracesdic,
@plotvals, @savetraces, @loadtraces, setsnaps

"""
`setsnaps(traces::Vector{TraceItem})`

Set the global RickTracy.happysnaps used by default in traceviews to traces.
Useful when loading traces from file
"""
function setsnaps(traces::Vector{TraceItem})
    global happysnaps = traces
end

"""
`tracevals(query, snaps=happysnaps)`
Get the values of the `snaps` that match `query`
"""
tracevals(query=Dict{Symbol, Any}(), snaps=happysnaps) = begin
    pluck(traceitems(query, snaps), :val)
end

"""
`traceitems(query, snaps=happysnaps)`
Get all TraceItems from `snaps` that match the `query`
"""
traceitems(query=Dict(), snaps=happysnaps) = filterquery(query, snaps)

"""
`tracevalsdic(query, snaps=happysnaps)`
Get a Dict{String, Vector{Any}} mapping expressions => a vector of the values
they held at your tracepoints that match `query`
"""
tracevalsdic(query=Dict{Symbol, Any}(), snaps=happysnaps) = begin
    res = DefaultDict(String, Vector{Any}, Vector{Any})
    for si in traceitems(query, snaps)
        push!(res[si.exprstr], si.val)
    end
    res
end

"""
`tracesdic(traces=happysnaps)`
Get a Dict{Symbol, Vector{Any}} mapping attributes of your TraceItems
(:location, :exprstr, :val, :ts) => the vector of values of that attribute for
traces that match `query`
"""
tracesdic(query=Dict{Symbol, Any}(), snaps=happysnaps) = begin
    fulldic = Dict{Symbol, Vector{Any}}()
    traces = traceitems(query, snaps)
    foreach(fieldnames(TraceItem)) do attr
        fulldic[attr] = pluck(traces, attr)
    end
    fulldic
end

"""
`tracesdf(query, snaps=happysnaps)`
Get a DataFrame from your traces that match `query`
"""
tracesdf(query=Dict{Symbol, Any}(), snaps=happysnaps) = begin
    @eval import DataFrames
    DataFrames.DataFrame(tracesdic(query, snaps))
end

"""
Plot the values your expr string took
"""
plotvals(query=Dict{Symbol, Any}(), snaps=happysnaps) = begin
    dicsnaps = tracevalsdic(query, snaps)
    #for some reason transposing a vector of strings throws a depwarn
    #so we use hcat with '...' instead of collect(keys(dicsnaps))'
    @eval import Plots
    Plots.plot(collect(values(dicsnaps)),
        label=reshape(collect(keys(dicsnaps)), 1, length(dicsnaps)))
end

function parse_query_args(exprs; kwargspec=trace_kwargspec, no_defaults=true, kwargs...)
    query, kwextras, exprs, arginfo =
        kwargparse(kwargspec, exprs; no_defaults=no_defaults, kwargs...)
    !isempty(exprs) && (query[:exprstr] = map(string, exprs))
    query, kwextras, exprs, arginfo
end

getquery(exprs) = parse_query_args(exprs)[1]

function getpath_varname_query(exprs; path="traces.jld", varname="traces")
    kwargspec = filter(trace_kwargspec) do k,v; k != :_and_the_rest end
    query, kwextras, exprs, arginfo =
        parse_query_args(exprs; kwargspec=kwargspec)
    path    = get(kwextras, :path,    path)
    varname = get(kwextras, :varname, varname)
    path, varname, query
end

function savetraces(; traces=traceitems(), path="traces.jld", varname="traces")
    @show path varname
    JLD.save(path, varname, traces)
end

function loadtraces(; path="traces.jld", varname="traces", asdefault=true)
    traces = JLD.load(path, varname)
    asdefault && (global happysnaps = traces)
    traces
end


"""
`@tracevals [loc=some_location] [expr1] [expr2] [expr3] ...`
returns a vector of all the values that variables/expressions
took at all tracepoints, optionally limited to a particular tracepoint location or expression(s).
"""
macro tracevals(exprs...)
    query = getquery(exprs)
    :(RickTracy.tracevals($query))
end

"""
`@traceitems [loc=any_location] [expr1] [expr2] [expr3] ...`
returns a Vector of all the raw `TraceItem ` snaps, optionally
limited to a particular tracepoint location or expression(s).
"""
macro traceitems(exprs...)
    query = getquery(exprs)
    :(RickTracy.traceitems($query))
end

"""
`@tracevalsdic [loc=a_location] [expr1] [expr2] [expr3] ...`: returns a Dict mapping expressions=>values the variable/expression took, optionally
limited to a particular tracepoint location or expression(s).
"""
macro tracevalsdic(exprs...)
    query = getquery(exprs)
    :(RickTracy.tracevalsdic($query))
end

"""
`@tracesdf [loc=any_location] [expr1] [expr2] [expr3] ...`: returns a DataFrame with fields `:location`, `:exprstr`, `:val`, `:lcount`, `:ts`, with each row holding a snap of one expression, optionally limit to a particular tracepoint location or expression(s).
"""
macro tracesdf(exprs...)
    query = getquery(exprs)
    :(RickTracy.tracesdf($query))
end

"""
`@tracesdic [loc=any_location] [expr1] [expr2] [expr3] ...`: returns a Dict{Symbol, Vector{Any}} with keys `:location`, `:exprstr`, `:val`, `:lcount`, `:ts`, with values being a vector of the value for that field for all snaps, optionally limited to a particular tracepoint location or expression(s).
"""
macro tracesdic(exprs...)
    query = getquery(exprs)
    :(RickTracy.tracesdic($query))
end

"""
`@plotvals [loc=any_location] [expr1] [expr2] [expr3] ...`: Make a plot of all values that `@tracevals` would return for the same arguments
N.b. will break if any values are non-numeric and probably in lots of other
cases too. You'll probably want to use the optional filter by the
specified location, and the given expression(s).
"""
macro plotvals(exprs...)
    query = getquery(exprs)
    :(RickTracy.plotvals($query))
end

"""
`@savetraces [path="$(pwd())/traces.jld"] [loc=any_location] [expr1] [expr2] [expr3] ...`
Saves the raw `TraceItem` snaps to path, optionally
limited to a particular tracepoint location or expression(s).
"""
macro savetraces(exprs...)
    path, varname, query = getpath_varname_query(exprs)
    :(RickTracy.savetraces(; traces=RickTracy.traceitems($query),
        path=$path, varname=$varname))
end

macro loadtraces(exprs...)
    path, varname, query = getpath_varname_query(exprs)
    :(RickTracy.loadtraces(; path=$path, varname=$varname))
end
