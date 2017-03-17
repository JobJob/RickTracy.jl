using RickTracy

@resetallsnaps
@watch i j k dsum dprod
dsum = 0
for i in 0:2
    for j in 0:9
        for k in 0:9
            dprod = i*j*k
    #         @show i j dsum dprod
            @snapall loc=inner
            dsum += 1
        end
    end
end
#---

tis = RickTracy.traces4symvals(Dict("i"=>2, "j"=>9, "k"=>9))
println("unique lcounts: ", unique(map(ti->ti.lcount, tis)))
println("length(tis): ", length(tis), "\n---------")
foreach(tis[end-4:end]) do ti
    println(ti.exprstr, ": ", ti.val, " (lcount: $(ti.lcount))")
end

#---

#---
push!(Interact.signal(slidees[1]), 10)

#---
#=
Let's say you had a few functions that:

1) do a little setup - initialise vars etc
2) iterate through a large array
3) do some cleanup and return some values

Now, you want to make your program as fast as possible so (I assume) you only want iterate through that array once, since (I assume) it'll be more cache/register friendly that way.

a) do you think my assumptions are correct
b) is there a good way to structure your code to do this?

What do you think about this:
=#

function dosometask1(bigarray, params...)
    #setup stuff1
    #setup stuff2
    function loop_part(i, array_el)
        #set some vars
        #check some stuff
        return all_done #return true if you want to break
    end
    function resultypoo()
        #finish up
        #return good stuff:
        (good, stuff, etc...)
    end

    loop_part, resultypoo
end

#---
using RickTracy
@resetallsnaps
@watch x y z dsum
dsum = 0
# Nxs = rand(1:2)
# Nys = [rand(1:4) for nx in 1:Nxs]
# Nzs = [rand(1:4) for nx in 1:Nxs for ny in 1:Nys[nx]]
Nxs = 3
Nys = [4,3,4]
Nzs = [5,4,5,3,7,4,4,10,8,9,3]
@show Nxs Nys Nzs

i = 0
for x in 1:Nxs
    # @show "----------------"
    for y in 1:Nys[x]
        i += 1
        # @show "*** $i ***"
        for z in 1:Nzs[i]
            # @show "^^^" x y z
            @snapall loc=inner
            dsum += 1
        end
    end
end
# RickTracy.happysnaps

sub2ind_nonsquare(row_lens, k) = begin
    sum = 0
    if length(k) > 1
        for i in 1:(k[1]-1)
            sum += row_lens[i]
        end
    end
    sum += k[end]
end

ies = RickTracy.get_iter_extrema([:x, :y, :z])
@show "------ end ------"
# @show Nxs Nys Nzs
maxNs = [[Nxs], Nys, Nzs]
for i in 1:3
    for (ien,(k,v)) in enumerate(ies[i])
        j = i==1 ? 1 : sub2ind_nonsquare(maxNs[i-1], k)
        maxv = maxNs[i][j]
        if v != (1,maxv)
            @show "----" i k v (1,maxv) ien
        end
    end
end

#---

#---
[(k,ies[3][k]) for k in sort([keys(ies[3])...;])]
#---


NTuple{2, String}(("1","2")) |> typeof
Tuple{Vararg{String}}(("1","2", "#")) |> typeof
NTuple{1, String}() |> typeof
#---
(1:0...)
#---
N = 3
iter_extrema = [Dict{NTuple{i-1, Int}, Tuple{Int,Int}}() for i in 1:N]
i = 1
tplkey = ()
extreme_default = (typemax(Int), typemin(Int)) #min, max worst case scenarios
iex = get!(iter_extrema[i], tplkey, extreme_default)
#---
isimmutable(iex)

#---
