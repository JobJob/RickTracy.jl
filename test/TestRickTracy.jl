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
    @clearsnaps
    fred = "Savage"
    winnie = 8.5
    @snapat "McKinley" fred winnie
    snapitems = @snapsat "McKinley"
    @fact length(snapitems) --> 2
    @fact snapitems[1].exprstr --> "fred"
    @fact snapitems[1].val --> "Savage"
    @fact snapitems[2].exprstr --> "winnie"
    @fact snapitems[2].val --> 8.5
end

facts("snapif") do
    @clearsnaps
    for i in 1:10
        @snapif i%3 == 0 i
    end
    @fact (@snapvals i) --> [3,6,9]
end

facts("snapifat") do
    @clearsnaps
    for i in 1:10
        @snapifat i%3 == 0 "looptown" i
    end
    snapitems = @snapsat "looptown"
    @fact RickTracy.pluck(snapitems, :val) --> [3,6,9]
end

facts("snapall") do
    @clearsnaps
    @initsnaps fred barney bambam

    fred = "1"
    barney = "2"
    bambam = "3"
    # println(:(@snapallatNth "first" 1) |> macroexpand)
    @snapallatNth "first" 1

    for i in 1:10
        fred = 2*i
        barney = 10*i
        bambam = 100*i
        @snapallatNth "second" 1
    end

    @fact (@snapvals bambam) --> Any["3",100,200,300,400,500,600,700,800,900,1000]
end

FactCheck.exitstatus()
end
