module TestRickTracy

using FactCheck
using RickTracy

facts("first things first") do
    fred = "flintstone"
    barney = 10

    @snap fred barney

    @fact (@snapvals fred) --> ["flintstone"]
    @fact (@snapvals barney) --> [10]
end

facts("snap the Nth") do
    for person in ["wilma", "fred", "betty", "barney"]
        @snapNth 2 person
    end
    @fact (@snapvals person) --> ["wilma", "betty"]
end

facts("snapat all on the floow") do
    fred = "flintstone"
    barney = 10
    @snapat "bedrock" fred barney
    snapitems = @snapsat "bedrock"
    @fact length(snapitems) --> 2
    @fact snapitems[1].exprstr --> "fred"
    @fact snapitems[1].val --> "flintstone"
    @fact snapitems[2].exprstr --> "barney"
    @fact snapitems[2].val --> 10
end

facts("snapall") do
    @initsnaps fred barney bambam

    fred = "1"
    barney = "2"
    bambam = "3"
    @snapall

    for i in 1:10
        fred = 2*i
        barney = 10*i
        bambam = 100*i
        @snapall
    end

    @fact (@snapvals bambam) --> Any["3",100,200,300,400,500,600,700,800,900,1000]
end

FactCheck.exitstatus()
end
