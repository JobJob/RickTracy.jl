###############################################################################
# Trace View/Accessor Functions
###############################################################################
using DataFrames

export @tracevals, @traceitems, @tracevalsdic, @tracesdf, @tracesdic,
@plotexprvals

"""
`tracevals(query, snaps=happysnaps)`
Get the values of the `snaps` that match `query`
"""
tracevals(query, snaps=happysnaps) = begin
    pluck(traceitems(query, snaps), :val)
end

"""
`traceitems(query, snaps=happysnaps)`
Get all TraceItems from `snaps` that match the `query`
"""
traceitems(query, snaps=happysnaps) = filterquery(query, snaps)

"""
`tracevalsdic(query, snaps=happysnaps)`
Get a Dict{String, Vector{Any}} mapping expressions => a vector of the values
they held at your tracepoints that match `query`
"""
tracevalsdic(query, snaps=happysnaps) = begin
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
tracesdic(query, snaps=happysnaps) = begin
    fulldic = Dict{Symbol, Vector{Any}}()
    foreach(fieldnames(TraceItem)) do attr
        fulldic[attr] = pluck(traceitems(query, snaps), attr)
    end
    fulldic
end

"""
`tracesdf(query, snaps=happysnaps)`
Get a DataFrame from your traces that match `query`
"""
tracesdf(query, snaps=happysnaps) = DataFrame(tracesdic(query, snaps))

"""
Plot the values your expr string took
"""
plotvals(query, snaps=happysnaps) = plot(tracevals(query, snaps))

traceitems() = happysnaps

function getquery(exprs)
    kwargs, exprs, arginfo = kwargparse(trace_kwargspec, exprs)
    #create a query based on the kw args set
    query = filter(kwargs) do key,val
        arginfo[key][:provided]
    end
    !isempty(exprs) && (query[:exprstr] = exprs[1] |> string)
    query
end

macro tracevals(exprs...)
    query = getquery(exprs)
    :(RickTracy.tracevals($query))
end

macro traceitems(exprs...)
    query = getquery(exprs)
    :(RickTracy.traceitems($query))
end

macro tracevalsdic(exprs...)
    query = getquery(exprs)
    :(RickTracy.tracevalsdic($query))
end

macro tracesdf(exprs...)
    query = getquery(exprs)
    :(RickTracy.tracesdf($query))
end

macro tracesdic(exprs...)
    query = getquery(exprs)
    :(RickTracy.tracesdic($query))
end

macro plotexprvals(exprs...)
    query = getquery(exprs)
    :(RickTracy.plotexprvals($query))
end
