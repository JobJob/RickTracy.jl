###############################################################################
# Trace View/Accessor Functions
###############################################################################
export @tracevals, @traceitems, @snapsdic

"""
Get all TraceItems from `snaps` that match the `query`
"""
traceitems(query, snaps=happysnaps) = filterquery(query, snaps)
tracevals(query, snaps=happysnaps) = begin
    pluck(traceitems(query, snaps), :val)
end

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

macro snapsdic(exprs...)
    query = getquery(exprs)
    :(RickTracy.dicout(RickTracy.traceitems($query)))
end

dicout(snaps) = begin
    res = DefaultDict(String, Vector{Any}, Vector{Any})
    for si in snaps
        push!(res[si.exprstr], si.val)
    end
    res
end
