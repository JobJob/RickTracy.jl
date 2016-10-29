###############################################################################
# Watched Expressions / Snapall
###############################################################################
export @watch, @unwatch, @unwatchall, @snapall

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
