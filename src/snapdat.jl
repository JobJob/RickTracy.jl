###############################################################################
# Make regular snaps
###############################################################################
export @snap

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
