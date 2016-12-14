###############################################################################
# Types
###############################################################################
export TraceItem

type TraceItem{T}
    location::String
    exprstr::String
    val::T
    lcount::Int
    ts::Float64 #time stamp
end
TraceItem{T}(location, exprstr, val::T, lcount) = TraceItem{T}(location, exprstr, val, lcount, time())
