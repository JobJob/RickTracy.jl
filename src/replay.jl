export @replay
import Interact, Reactive, DataFrames

const DEBUG = true

"""
`traces4symvals(symvals::Dict; loc="")`

`symvals` is a Dict of symbols => their value at the desired
trace line hit count (lcount).

Returns:
a vector of TraceItems corresponding to the `@snapall` where all syms had their
respective vals
"""
function traces4symvals(symvals::Dict{String}; loc="", traces=happysnaps)
    query = Dict{Symbol, Any}()
    loc != "" && (query[:location] = loc)
    tis = traceitems(query)
    lcount = 0
    startidx = 0
    endidx = 0
    matched = fill(false, length(symvals))
    poss_match = true
    got_match = false
    for (i, ti) in enumerate(tis)
        if ti.lcount != lcount
            if poss_match && all(matched)
                got_match = true
                endidx = i - 1
            elseif got_match
                #previous lcount were matching, now no longer matching, we're done
                break
            else
                startidx = i
                poss_match = true
            end
            fill!(matched, false)
            lcount = ti.lcount
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
    # since the check currently only happens when the lcount changes (not every outer loop iteration)
    poss_match && all(matched) && (endidx = length(tis))
    tis[startidx:endidx]
end

traces4symvals(symvals::Pair...; loc="") = traces4symvals(Dict(symvals); loc=loc)

"""
`vals4traces(syms::Vector{String}, traces; loc="")`

Given a vector of variables `syms` and a list of traces, returns a vector of the
first value found in `traces` for each sym.
"""
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

"""
Values of `itervars[i]` assumed to be `Int`s and for fixed values of itervars[1:i-1]
they should be increasing (as index into `traces` increases). Also assumed is that
the nth trace of itervars[j] will always appear before the nth trace of itervars[j+1]
for all j. I.e. the iter vars are watched from slowest moving (outer-most loop iterator)
to fastest (inner-most loop iterator).
"""
function get_iter_extrema(itervars; traces=RickTracy.happysnaps)
    N = length(itervars)
    ivarstrs = string.(itervars)
    iter2idx = Dict(zip(ivarstrs, 1:N))
    extreme_default = (typemax(Int), typemin(Int)) #min, max worst case scenarios
    iter_extrema = [Dict{NTuple{i-1, Int}, Tuple{Int,Int}}() for i in 1:N]
    tpl_keys = zeros(Int, N)
    minpos, maxpos = (1,2)
    for (tidx, ti) in enumerate(traces)
        !(ti.exprstr in ivarstrs) && continue
        ivar = ti.exprstr
        val = ti.val
        i = iter2idx[ivar]
        tpl_keys[i] = ti.val
        tplkey = (tpl_keys[1:i-1]...)
        imin, imax = get!(iter_extrema[i], tplkey, extreme_default)
        new_min_or_max = false
        if val < imin
            imin = val
            new_min_or_max = true
        end
        if val > imax
            imax = val
            new_min_or_max = true
        end
        new_min_or_max && (iter_extrema[i][tplkey] = (imin, imax))
    end
    iter_extrema
end

function getsliders(itervars)
    iterator_extrema = get_iter_extrema(itervars)
    sliders = Array(Interact.Slider, length(itervars))
    slsigs  = Array(Reactive.Signal, length(itervars))
    minidx, maxidx = 1,2
    # @show itervars
    for (i, ivar) in enumerate(itervars)
        minmax = iterator_extrema[i]
        prev_itervals = (map(s->s.value, sliders[1:i-1])...)
        initial_range = UnitRange(minmax[prev_itervals]...)
        init_val = minmax[prev_itervals][minidx]
        sliders[i] = slider(initial_range;
                            value=init_val, label=string(ivar))
        slsigs[i] = signal(sliders[i])
        if i > 1
            #keep the ranges accurate on sliders, dependent on prev iterator values
            prevsigs = slsigs[1:i-1]
            # @show i prevsigs
            range_sig = Reactive.map(prevsigs...) do ivarvals...
                #unfortunately we can't use ivarvals, because changing the previous
                #slider's range will only push a value to slider's sig asynchronously
                #so ivarvals are old signal vals (whose signals are about to update)
                prev_itervals = (map(s->s.value, sliders[1:i-1])...)
                # @show i ivarvals prev_itervals minmax[prev_itervals]
                # haskey(minmax, (ivarvals...)) && (@show minmax[(ivarvals...)])
                (sliders[i].value < minmax[prev_itervals][minidx]) &&
                    set!(sliders[i], :value, minmax[prev_itervals][minidx])
                (sliders[i].value > minmax[prev_itervals][maxidx]) &&
                    set!(sliders[i], :value, minmax[prev_itervals][maxidx])
                UnitRange(minmax[prev_itervals]...)
            end |> Reactive.preserve
            set!(sliders[i], :range, range_sig)
        end
    end
    sliders, slsigs
end

function kwargs2assignment_block!(kw_ex)
    kw_ex.head = :block #:parameters to block
    kw_symvals = map(kw_ex.args) do ex
        ex.head = Symbol("=")
        ex.args[1], ex.args[2]
    end
    kw_syms, kw_vals = zip(kw_symvals...) |> collect #unzip
    kw_ex, [kw_syms...], [kw_vals...]
end

macro replay(expr)
    @eval begin using Interact, DataFrames end
    fnargs = expr.args[1].args
    numwsyms = 0
    if isa(fnargs[1], Expr)
        #kwargs
        widget_bindings, wsyms, widgets = kwargs2assignment_block!(fnargs[1])
        deleteat!(fnargs, 1)
        foreach(wsym->push!(fnargs, wsym), wsyms) #add widgsym vals as arguments
        wsigs_ex = :()
        foreach(wsym->push!(wsigs_ex.args, :(signal($wsym))), wsyms)
        widgs_ex = :()
        foreach(wsym->push!(widgs_ex.args, :($wsym)), wsyms)
        numwsyms = length(wsyms)
    end
    itervars = expr.args[1].args[1:(end-numwsyms)]
    varstrs = String.(unique(RickTracy.tracesdf(), :exprstr)[:exprstr])
    filter!(varstrs) do vstr; !(vstr in string.(itervars)) end
    varsyms = Symbol.(varstrs)
    block = expr.args[2].args[2] #function body
    itervalpairs = :()
    foreach(itervars) do sym
        push!(itervalpairs.args, :($(string(sym)) => $sym))
    end
    unshift!(fnargs, :prev) #for the foldp to return the prev valid value if we run into trouble
    unshift!(block.args,
        # get the traces where the iterators had their particular (current) values
        # and the values of the other syms at those traces
        quote
            _traces = RickTracy.traces4symvals($(itervalpairs)...)
            if isempty(_traces)
                if RickTracy.DEBUG
                    println(STDERR, "traces are empty for ", $itervalpairs)
                end
                return prev
            end
            _symvals = RickTracy.vals4traces($varstrs, _traces)
        end)

    # assign them to local vars with the same name ^_^
    for (i,sym) in enumerate(varsyms)
        symstr = string(sym)
        insert!(block.args, 2,
            quote
                local $sym
                try
                    $sym = _symvals[$i]
                catch e
                    if RickTracy.DEBUG
                        println(STDERR, "Failed to set ", $symstr, ", _symvals: ", _symvals, ", i: ", $i, "_traces: ", _traces)
                    end
                end
            end
        )
    end
    res = quote
        @eval begin using Interact, Reactive, DataFrames end
        sliders, slsigs = RickTracy.getsliders($itervars)
        $widget_bindings
        widglayout = hbox(vbox(sliders...), vbox($widgs_ex...))
        display(widglayout)
        Reactive.foldp($expr,
            slsigs...,
            $(wsigs_ex)...; typ=Any) |> Reactive.preserve
    end |> esc
    # dump(res, maxdepth = 30)
    res
end
