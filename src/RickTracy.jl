module RickTracy

using DataStructures, JLD

__init__() = begin
    global _num_trace_locations = 0
    global location_counts = DefaultDict(String, Int, 1) #number of times tracepoint at each location has been hit (but not necessarily logged)
    global watched_exprs = Dict{String, Bool}()
    global happysnaps = Vector{TraceItem}()
    global autowatch = true
end

include("types.jl")
include("snapdat.jl")
include("snapall.jl")
include("traceviews.jl")
include("replay.jl")
include("clarence.jl")
include("utils.jl")

#=
1) http://julialang.org/blog/2016/10/StructuredQueries https://davidagold.github.io/StructuredQueries.jl/latest/man/guide.html
2) http://www.david-anthoff.com/Query.jl/stable/
3) https://github.com/FugroRoames/TypedTables.jl
4) https://github.com/JuliaComputing/IndexedTables.jl
=#

end
