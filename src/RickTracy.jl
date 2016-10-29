module RickTracy

using DataStructures

__init__() = begin
    global _num_trace_locations = 0
    global location_counts = DefaultDict(String, Int, 0) #number of times tracepoint at each location has been hit (but not necessarily logged)
    global watched_exprs = Dict{String, Bool}()
    global happysnaps = Vector{TraceItem}()
    global autowatch = true
end

include("types.jl")
include("snapdat.jl")
include("snapall.jl")
include("traceviews.jl")
include("clarence.jl")
include("utils.jl")

end
