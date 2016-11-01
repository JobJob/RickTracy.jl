###############################################################################
# Reset and Clear
###############################################################################
export @clearsnaps, @clearallsnaps, @resetallsnaps

brandnewsnaps!() = begin
    global _num_trace_locations = 0
    empty!(happysnaps)
    empty!(location_counts)
    empty!(watched_exprs)
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
