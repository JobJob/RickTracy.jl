export @replay
import Interact, DataFrames

"""
`lcount4symvals(symvals::Dict; loc="")`

`symvals` is a Dict of symbols => their value at the desired
trace line hit count (lcount).

Returns:
a vector of TraceItems corresponding to the `@snapall` where all syms had their
respective vals
"""
function traces4symvals(symvals::Dict; loc="")
    query = Dict{Symbol, Any}()
    loc != "" && (query[:location] = loc)
    tis = traceitems(query)
    lcount = 0
    startidx = 0
    endidx = 0
    matched = fill(false, length(symvals))
    poss_match = true
    for (i, ti) in enumerate(tis)
        if ti.lcount != lcount
            if poss_match && all(matched)
                endidx = i - 1
                break
            end
            poss_match = true
            fill!(matched, false)
            lcount = ti.lcount
            startidx = i
        end
        !poss_match && continue
        for (i, (sym, val)) in enumerate(symvals)
            if ti.exprstr == sym
                #item is for the current `sym`
                if ti.val == val
                    matched[i] = true
                else
                    matched[i] = false
                    poss_match = false
                end
                break
            end
        end
    end
    # handle all matched on the last iteration, slightly more efficient than
    # to move the check to the bottom of the loop and change the i-1 to i
    # since the check currently only happens when the lcount changes.
    poss_match && all(matched) && endidx == 0 && (endidx = length(tis))

    tis[startidx:endidx]
end

traces4symvals(symvals::Pair...; loc="") = traces4symvals(Dict(symvals); loc=loc)

function vals4traces(syms::Vector{String}, traces; loc="")
    vals = Array(Any, length(syms))
    for ti in traces
        i = findfirst(syms, ti.exprstr)
        if i != 0
            vals[i] = ti.val
        end
    end
    vals
end

function getsliders(itervars)
    sliders = Interact.Slider[]
    tvd = RickTracy.tracevalsdic()
    for ivar in itervars
        ivarstr = string(ivar)
        rnge = UnitRange(extrema(tvd[ivarstr])...)
        push!(sliders, Interact.slider(rnge; label=ivarstr))
    end
    sliders
end

macro replay(expr)
    @eval quote using Interact, DataFrames end
    itervars = expr.args[1].args
    varstrs = String.(unique(RickTracy.tracesdf(), :exprstr)[:exprstr])
    filter!(varstrs) do vstr; !(vstr in string.(itervars)) end
    varsyms = Symbol.(varstrs)
    # dump(expr)
    block = expr.args[2].args[2]
    itervalpairs = :()
    foreach(itervars) do sym
        push!(itervalpairs.args, :($(string(sym)) => $sym))
    end
    # get the traces where the iterators had their particular values
    unshift!(block.args,
        quote
            _traces = RickTracy.traces4symvals($(itervalpairs)...)
            _symvals = RickTracy.vals4traces($varstrs, _traces)
        end)
    #get the values of the other syms at those traces and assign them
    #to local vars of the same name ^_^
    for (i,sym) in enumerate(varsyms)
        insert!(block.args, 2,
            :($sym = _symvals[$i])
        )
    end
    quote
        @eval begin using DataFrames end
        sliders = RickTracy.getsliders($itervars)
        display.(sliders)
        map($expr, Interact.signal.(sliders)...; typ=Any)
    end |> esc
end
