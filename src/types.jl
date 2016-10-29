###############################################################################
# Types
###############################################################################
export TraceItem

type TraceItem{T}
    location::String
    exprstr::String
    val::T
    ts::Float64 #time stamp
end
TraceItem{T}(location, exprstr, val::T) = TraceItem{T}(location, exprstr, val, time())
