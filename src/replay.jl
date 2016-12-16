export @replay
import Interact, DataFrames

"""
`get_lcount(symvals::Dict; loc="")`

`symvals` is a Dict of indice symbols => their value at the desired
trace line hit count (lcount). Returns the `lcount` for the trace point `@snapall`
where all syms have their respective vals.
"""
function get_lcount(symvals::Dict; loc="")
    query = Dict{Symbol, Any}()
    loc != "" && (query[:location] = loc)
    tis = traceitems(query)
    lcount = 0
    match = false
    for ti in tis
        if ti.lcount != lcount
            match == true && break
            match = false
            lcount = ti.lcount
        end
        for (sym, val) in symvals
            if ti.exprstr == sym
                #item is for the current `sym`
                if ti.val == val
                    match = true
                else
                    match = false
                end
                break
            end
        end
    end
    @show symvals lcount
    lcount
end

get_lcount(symvals::Pair...; loc="") = get_lcount(Dict(symvals); loc=loc)

function val4iters(sym, itervars...; loc="", tvd=RickTracy.tracevalsdic())
    lcount = get_lcount(itervars...; loc=loc) #TODO get_lcount only once
    tvd[string(sym)][lcount]
end

function getsliders(itervars)
    sliders = Interact.Slider[]
    tvd = RickTracy.tracevalsdic()
    for ivar in itervars
        ivarstr = string(ivar)
        rnge = range(extrema(tvd[ivarstr])...)
        push!(sliders, Interact.slider(rnge; label=ivarstr))
    end
    sliders
end

macro replay(expr)
    @eval quote using Interact, DataFrames end
    itervars = expr.args[1].args
    varstrs = collect(unique(RickTracy.tracesdf(), :exprstr)[:exprstr])
    filter!(varstrs) do vstr; !(vstr in string.(itervars)) end
    varsyms = Symbol.(varstrs)
    # dump(expr)
    block = expr.args[2].args[2]
    iterexpr = :()
    foreach(itervars) do sym
        push!(iterexpr.args, :(string($(QuoteNode(sym))) => $sym))
    end
    for (sym,symstr) in zip(varsyms,varstrs)
        unshift!(block.args,
            :($sym = RickTracy.val4iters($(QuoteNode(sym)), $(iterexpr)...)))
    end
    quote
        @eval begin using DataFrames end
        sliders = RickTracy.getsliders($itervars)
        display.(sliders)
        map($expr, Interact.signal.(sliders)...; typ=Any)
    end |> esc
end
