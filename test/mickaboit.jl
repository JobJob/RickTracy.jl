using RickTracy

@resetallsnaps
@watch i j dsum dprod
dsum = 0
for i in 1:10
    for j in 1:30
        dsum += 1
        dprod = i*j
#         @show i j dsum dprod
        @snapall loc=inner
    end
end

#---
@savetraces
@savetraces path="~/.julia/v0.5/RickTracy/test/tracu.jld"
@savetraces path="~/.julia/v0.5/RickTracy/test/tracup.jld" varname="potato"
#---
@loadtraces
#---
@loadtraces path="~/.julia/v0.5/RickTracy/test/tracu.jld"
#---
@loadtraces path="~/.julia/v0.5/RickTracy/test/tracup.jld" varname="potato"
