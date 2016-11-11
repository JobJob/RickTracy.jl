###############################################################################
# Trace View/Accessor Functions
###############################################################################
using DataFrames, Plots

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
plotexprvals(query, snaps=happysnaps) = begin
    dicsnaps = tracevalsdic(query, snaps)
    #for some reason transposing a vector of strings throws a depwarn
    #so we use hcat with '...' instead of collect(keys(dicsnaps))'
    plot(collect(values(dicsnaps)),
        label=reshape(keys(dicsnaps), 1, length(dicsnaps)))
end

traceitems() = happysnaps

function getquery(exprs)
    kwargs, exprs, arginfo = kwargparse(trace_kwargspec, exprs)
    #create a query based on the kw args set
    query = filter(kwargs) do key,val
        arginfo[key][:provided]
    end
    !isempty(exprs) && (query[:exprstr] = map(string, exprs))
    query
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
`@tracesdf [loc=any_location] [expr1] [expr2] [expr3] ...`: returns a DataFrame with fields `:location`, `:exprstr`, `:val`, `:ts`, with each row holding a snap of one expression, optionally limit to a particular tracepoint location or expression(s).
"""
macro tracesdf(exprs...)
    query = getquery(exprs)
    :(RickTracy.tracesdf($query))
end

"""
`@tracesdic [loc=any_location] [expr1] [expr2] [expr3] ...`: returns a Dict{Symbol, Vector{Any}} with keys `:location`, `:exprstr`, `:val`, `:ts`, with values being a vector of the value for that field for all snaps, optionally limited to a particular tracepoint location or expression(s).
"""
macro tracesdic(exprs...)
    query = getquery(exprs)
    :(RickTracy.tracesdic($query))
end

"""
`@plotexprvals [loc=any_location] [expr1] [expr2] [expr3] ...`: Make a plot of all values that @tracevals would return for the same arguments
N.b. will break if any values are non-numeric and probably in lots of other
cases too. You'll probably want to use the optional filter by the
specified location, and the given expression(s).
"""
macro plotexprvals(exprs...)
    query = getquery(exprs)
    :(RickTracy.plotexprvals($query))
end
