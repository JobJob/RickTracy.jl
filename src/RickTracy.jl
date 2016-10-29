module RickTracy

export
#Types
TraceItem,
#standard snaps
@snap,
#watchall related
@watch, @unwatch, @unwatchall, @snapall,
#reset fns
@clearsnaps, @clearallsnaps, @resetallsnaps,
#view/process traces
@tracevals, @traceitems, @snapsdic

using DataStructures

__init__() = begin
    global _num_trace_locations = 0
    global location_counts = DefaultDict(String, Int, 0) #number of times tracepoint at each location has been hit (but not necessarily logged)
    global watched_exprs = Dict{String, Bool}()
    global happysnaps = Vector{TraceItem}()
    global autowatch = true
end


###############################################################################
# Types
###############################################################################
type TraceItem{T}
    location::String
    exprstr::String
    val::T
    ts::Float64 #time stamp
end
TraceItem{T}(location, exprstr, val::T) = TraceItem{T}(location, exprstr, val, time())

###############################################################################
# Make regular snaps
###############################################################################
"""
adds a trace entry in happysnaps for each expr in exprstrs with
corresponding val from vals
"""
storesnaps(location, everyN, exprstrs, vals) = begin
    if location_counts[location]%everyN == 0
        for (exprstr, val) in zip(exprstrs, vals)
            storesnap(location, exprstr, val)
        end
    end
    location_counts[location] += 1
end

storesnap(location, exprstr, val) = push!(happysnaps, TraceItem(location, exprstr, val))

macro snapexprs(location, N, exprs)
    res = :(_rtexprstrs = []; _rtvals=[])
    for expr in exprs
        exprstr = string(expr)
        res = quote
            $res
            push!(_rtexprstrs, $exprstr)
            push!(_rtvals,
                try
                    $expr
                catch e
                    typeof(e) != UndefVarError && throw(e)
                    :undefined
                end)
        end
        autowatch && watch_exprstr(exprstr) #called at macro expansion time, not run time
    end
    res = :($res; RickTracy.storesnaps($location, $N, _rtexprstrs, _rtvals))
    res = :($res; RickTracy.happysnaps)
    res |> esc
end

"""
Take a snap/trace of a variable/expression.
#example

    fred = "flintstone"
    barney = 10

    @snap fred barney
    @tracevals fred

outputs:

    1-element Array{String,1}:
    "flintstone"

By default the variable/expression will be added to the watch list,
and logged/snapped on calls to `@snapall` that are parsed/loaded later than
this call.. To disable this behaviour call RickTracy.set_autowatch(false).

A numbered location string will be added to the trace entry to identify
the code location. To specify your own location use:

    @snap loc="decriptive location name" var1 var2
    #or
    @snapat location=@__LINE__ var1 var2

# n.b. `location`, `loc`, or just plain `l` are valid

    for person in ["wilma", "fred", "betty", "barney"]
        @snap N=2 person
    end
    @tracevals person

    returns:

    2-element Array{String,1}:
     "wilma"
     "betty"

"""
macro snap(exprs...)
    kwargs, exprs, arginfo = kwargparse(trace_kwargspec, exprs)
    condition = kwargs[:iff]
    quote
        if $condition
            @RickTracy.snapexprs $(kwargs[:location]) $(kwargs[:everyN]) $exprs
        end
    end |> esc
end

###############################################################################
# Watched Expressions / Snapall
###############################################################################
set_autowatch(on::Bool) = global autowatch = on
get_autowatch() = autowatch

watched_exprstrs() = keys(watched_exprs)

watch_exprstr(exprstr) = begin
    watched_exprs[exprstr] = true
end

unwatch_exprstr(exprstr) = begin
    delete!(watched_exprs, exprstr)
end

macro watch(exprs...)
    for expr in exprs
        watch_exprstr(string(expr)) #called at macro expansion time, not run time
    end
    :()
end

macro unwatch(exprs...)
    for expr in exprs
        unwatch_exprstr(string(expr))
    end
    :()
end

macro unwatchall()
    empty!(watched_exprs)
    :()
end

macro snapall(kwexprs...)
    kwargs, extra_exprs, arginfo = kwargparse(trace_kwargspec, kwexprs)
    watched_exprs = map(parse, watched_exprstrs())
    exprs = vcat(watched_exprs, extra_exprs)
    condition = kwargs[:iff]
    quote
        if $condition
            @RickTracy.snapexprs $(kwargs[:location]) $(kwargs[:everyN]) $exprs
        end
    end |> esc
end

###############################################################################
# Trace View/Accessor Functions
###############################################################################
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


###############################################################################
# Clearance Clarence
###############################################################################

brandnewsnaps!() = begin
    empty!(happysnaps)
    empty!(location_counts)
    empty!(watched_exprs)
    global _num_trace_locations = 0
end

macro resetallsnaps()
    :(RickTracy.brandnewsnaps!()) |> esc
end

macro clearallsnaps()
    :(empty!(RickTracy.happysnaps)) |> esc
end

clearsnaps(exprstr) = begin
    #find snaps that match key, and remove them from the happysnaps vector
    filter!((st)->st.exprstr == exprstr, happysnaps) #slow
end

macro clearsnaps(exprs...)
    res = :()
    for expr in exprs
        exprstr = "$expr" #expr as a string
        res = :($res; RickTracy.clearsnaps(exprstr))
    end
    res |> esc
end

macro clearunwatch(exprs...)
    :(@unwatch exprs; @clearsnaps(exprs)) |> esc
end

###############################################################################
# Helpers
###############################################################################
pluck(objarr, sym) = map((obj)->getfield(obj, sym), objarr)

Base.ismatch{T<:Any}(query::Dict{Symbol, T}, obj) = all(getfield(obj, fld) == val for (fld,val) in query)

filterquery{T<:Any}(query::Dict{Symbol, T}, collection::AbstractArray) = filter(collection) do obj ismatch(query, obj) end

"""
Create default auto-incremented numbered location for the tracepoint

n.b. File and line number of call site in macro-expansion isn't possible yet
Waiting on https://github.com/JuliaLang/julia/issues/9577
"""
next_global_location() = begin
    global _num_trace_locations
    _num_trace_locations += 1
end

location_spec = Dict(:aliases=>[:location, :loc, :l],
                    :convert=>string, :default=>next_global_location)

throttle_spec = Dict(:aliases=>[:everyN, :every, :N],
                    :convert=>Int, :default=>1)

if_spec = Dict(:aliases=>[:iff, :when, :onlyif], :default=>true)


trace_kwargspec = Dict(:location=>location_spec,
                        :everyN=>throttle_spec,
                        :iff=>if_spec)

"""
spec[:default] can be a value or a nullary function that when called returns the default
"""
get_default(spec) = begin
    !haskey(spec, :default) && return nothing
    !isempty(methods(spec[:default])) ?
                        spec[:default]() : spec[:default]
end

"""
Parse keyword args passed to your macro
For each keyword argument you want to handle, provide a argument specification:
    :aliases ::Vector{Symbol} #possible names used for this variable
    :default ::Union{Function, Literal} #(optional) default value for the var if keyword not provided
    :convert ::Function #(optional) - called after arg is parsed to e.g. convert it to a correct type
kwargspec (key word argument specification) is then a Dict from your symbol names => their argument specification as defined aboive
Returns: a Dict{Symbol, Any} with values for all keys in your kwargspec
"""
kwargparse(kwargspec, exprs) = begin
    kwargs = Dict{Symbol, Any}(key => get_default(spec) for (key, spec) in kwargspec)
    arginfo = Dict{Symbol, Any}(key => arginfo_default() for (key, spec) in kwargspec)
    args = []
    for expr in exprs
        if typeof(expr) == Expr && expr.head == Symbol("=")
            for (key, spec) in kwargspec
                if expr.args[1] in spec[:aliases]
                    arginfo[key][:provided] = true
                    if haskey(spec, :accumulate) && spec[:accumulate]
                        push!(kwargs[key], expr.args[2])
                    else
                        kwargs[key] = expr.args[2]
                    end
                end
            end
        else
            push!(args, expr)
        end
    end
    for (key, spec) in kwargspec
        haskey(spec, :convert) && (kwargs[key] = spec[:convert](kwargs[key]))
    end
    kwargs, args, arginfo
end

arginfo_default() = Dict(:provided=>false)

end
