###############################################################################
# Helpers
###############################################################################
pluck(objarr, sym) = map((obj)->getfield(obj, sym), objarr)

"""
`ismatch{T<:Any}(query::Dict{Symbol, T}, obj)`
Given a query Dict specifying equality queries of the form `fieldname=value`
returns whether the `obj` is a match for all queries.
If `query` is empty returns `true`.
"""
Base.ismatch{T<:Any}(query::Dict{Symbol, T}, obj) = begin
    res = all((fld != :exprval && getfield(obj, fld) == val) ||
        (fld == :exprstr && getfield(obj, fld) in val) ||
        (fld == :exprval &&
            any(getfield(obj, :exprstr) == xvar && getfield(obj, :val) == xval for (xvar,xval) in val))
            for (fld,val) in query)
    res
end

"""
`filterquery{T<:Any}(query::Dict{Symbol, T}, collection::AbstractArray)`
Given an iterable of objects, `collection`, returns a new iterable of all
objects in collection who match `query` as tested by `ismatch(query, obj)`
"""
filterquery{T<:Any}(query::Dict{Symbol, T}, collection::AbstractArray) = begin
    filter(collection) do obj ismatch(query, obj) end
end

"""
Create default auto-incremented numbered location for the tracepoint

n.b. File and line number of call site in macro-expansion isn't possible yet.
Waiting on https://github.com/JuliaLang/julia/issues/9577
"""
next_global_location() = begin
    global _num_trace_locations
    _num_trace_locations += 1
end

function add_exprvals(kwargs, args, arginfo, lv, rv)
    valarr = get!(kwargs, :exprval, Vector())
    push!(valarr, string(lv)=>rv)
    (:exprval,)
end

location_spec = Dict(:aliases=>[:location, :loc, :l],
                    :convert=>string, :default=>next_global_location)

lcount_spec = Dict(:aliases=>[:lcount, :lc],
                    :convert=>Int, :default=>0)

throttle_spec = Dict(:aliases=>[:everyN, :every, :N],
                    :convert=>Int, :default=>1)

if_spec = Dict(:aliases=>[:iff, :when, :onlyif], :default=>true)


trace_kwargspec = Dict(
    :location=>location_spec,
    :lcount=>lcount_spec,
    :everyN=>throttle_spec,
    :iff=>if_spec,
    :_and_the_rest=>Dict(:fn=>add_exprvals)
)

"""
spec[:default] can be a value or a nullary function that when called returns the default
"""
get_default(spec) = begin
    !haskey(spec, :default) && return nothing
    !isempty(methods(spec[:default])) ?
                        spec[:default]() : spec[:default]
end

"""
`kwargparse(kwargspec, exprs; onlyprovided=false)`
Parse keyword args passed to your macro
For each keyword argument you want to handle, provide a argument specification:
    :aliases ::Vector{Symbol} #possible names used for this variable
    :default ::Union{Function, Literal} #(optional) default value for the var if keyword not provided
    :convert ::Function #(optional) - called after arg is parsed to e.g. convert it to a correct type
kwargspec (key word argument specification) is then a Dict from your symbol names => their argument specification as defined above
Returns: a tuple `(kwargs::Dict{Symbol, Any}, args::Vector{Expr}, arginfo::Dict{Symbol, Dict{Symbol, Any}})`
kwargs has values for all symbols in your kwargspec, args holds remaining non-kw expressions.
`arginfo[:sym][:provided]` which tells you if the variable was provided or not. If `onlyprovided`
is true then the returned Dict will only contain symbols actually specified in exprs.
"""
kwargparse(kwargspec, exprs; onlyprovided=false) = begin
    kwargs = Dict{Symbol, Any}(key => get_default(spec) for (key, spec) in kwargspec)
    arginfo = Dict{Symbol, Any}(key => arginfo_default() for (key, spec) in kwargspec)
    args = []
    for expr in exprs
        if typeof(expr) == Expr && expr.head == Symbol("=")
            added = false
            for (key, spec) in kwargspec
                key == :_and_the_rest && continue
                if expr.args[1] in spec[:aliases]
                    added = true
                    arginfo[key][:provided] = true
                    if haskey(spec, :accumulate) && spec[:accumulate]
                        push!(kwargs[key], expr.args[2])
                    else
                        kwargs[key] = expr.args[2]
                    end
                end
            end
            if !added && haskey(kwargspec, :_and_the_rest)
                kwargs_added = kwargspec[:_and_the_rest][:fn](kwargs, args, arginfo, expr.args[1], expr.args[2])
                foreach(kwargs_added) do kwarg; arginfo[kwarg] = Dict(:provided => true) end
            end
        else
            push!(args, expr)
        end
    end
    for (key, spec) in kwargspec
        haskey(spec, :convert) && (kwargs[key] = spec[:convert](kwargs[key]))
    end
    if onlyprovided
        for dic in (kwargs, arginfo)
            filter!(dic) do key,val
                arginfo[key][:provided]
            end
        end
    end
    kwargs, args, arginfo
end

arginfo_default() = Dict(:provided=>false)
