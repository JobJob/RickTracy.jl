using RickTracy
using Base.Test

sub2ind_nonsquare(row_lens, k) = begin
    sum = 0
    if length(k) > 1
        for i in 1:(k[1]-1)
            sum += row_lens[i]
        end
    end
    sum += k[end]
end

dsum = 0
Nxs = rand(1:7)
Nys = [rand(1:10) for nx in 1:Nxs]
Nzs = [rand(1:10) for nx in 1:Nxs for ny in 1:Nys[nx]]
# Nxs = 3
# Nys = [4,3,4]
# Nzs = [5,4,5,3,7,4,4,10,8,9,3]
@show Nxs Nys Nzs

@testset "iter extrema" begin

    @resetallsnaps
    @watch x y z dsum
    i = 0
    for x in 1:Nxs
        for y in 1:Nys[x]
            i += 1
            for z in 1:Nzs[i]
                @snapall loc=inner
                dsum += 1
            end
        end
    end

    ies = RickTracy.get_iter_extrema([:x, :y, :z])
    maxNs = [[Nxs], Nys, Nzs]
    for i in 1:3
        for (k,v) in ies[i]
            j = i==1 ? 1 : sub2ind_nonsquare(maxNs[i-1], k)
            maxv = maxNs[i][j]
            @test (k,v) == (k,(1,maxv))
        end
    end
end
