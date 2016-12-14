export @replay
import Interact

get_lcount(symvals::Pair...; loc="") = get_lcount(Dict(symvals); loc=loc)

function get_lcount(symvals::Dict; loc="")
    basequery = Dict{Symbol, Any}()
    loc != "" && (basequery[:location] = loc)
    dfs = DataFrame[]
    for (sym,val) in symvals
        query = copy(basequery)
        query[:exprval] = Dict(string(sym)=>val)
        push!(dfs, RickTracy.tracesdf(query))
    end
    join(dfs...; on=:lcount)[:lcount][1]
end

function val4iters(sym, itervars...; loc="", tvd=RickTracy.tracevalsdic())
    lcount = get_lcount(itervars...; loc=loc)
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
    @eval using Interact, DataFrames
    itervars = expr.args[1].args[end-1:end]
    varstrs = collect(RickTracy.watched_exprstrs())
    filter!(varstrs) do vstr; !(vstr in string.(itervars)) end
    varsyms = Symbol.(varstrs)
    # dump(expr)
    block = expr.args[2].args[2]
    iterexpr = :()
    foreach(itervars) do sym
        push!(iterexpr.args, :($(QuoteNode(sym)) => $sym))
    end
    for (sym,symstr) in zip(varsyms,varstrs)
        unshift!(block.args, :($sym = RickTracy.val4iters($(QuoteNode(sym)), $(iterexpr)...)))
    end
    quote
        sliders = RickTracy.getsliders($itervars)
        display.(sliders)
        map($expr, Interact.signal.(sliders)...; typ=Any)
    end |> esc
end
