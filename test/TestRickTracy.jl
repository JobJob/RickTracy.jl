module TestRickTracy

using FactCheck
using RickTracy

facts("first things first") do
    fred = "flintstone"
    barney = 10

    @snap fred barney

    @fact (@tracevals fred) --> ["flintstone"]
    @fact (@tracevals barney) --> [10]
end

facts("snap the Nth") do
    for person in ["wilma", "fred", "betty", "barney"]
        @snapNth 2 person
    end
    @fact (@tracevals person) --> ["wilma", "betty"]
end

facts("snapat all on the floow") do
    @clearallsnaps
    fred = "Savage"
    winnie = 8.5
    @snapat "McKinley" fred winnie
    traceitems = @tracesat "McKinley"
    @fact length(traceitems) --> 2
    @fact traceitems[1].exprstr --> "fred"
    @fact traceitems[1].val --> "Savage"
    @fact traceitems[2].exprstr --> "winnie"
    @fact traceitems[2].val --> 8.5
end

facts("snapif") do
    @clearallsnaps
    for i in 1:10
        @snapif i%3 == 0 i
    end
    @fact (@tracevals i) --> [3,6,9]
end

facts("snapifat") do
    @clearallsnaps
    for i in 1:10
        @snapifat i%3 == 0 "looptown" i
    end
    traceitems = @tracesat "looptown"
    @fact (@tracevalsat "looptown" i) --> [3,6,9]
end

facts("snapall") do
    @clearallsnaps
    @watch fred barney bambam

    fred = "1"
    barney = "2"
    bambam = "3"
    @snapallatNth "first" 1

    for i in 1:10
        fred = 2*i
        barney = 10*i
        bambam = 100*i
        @snapallatNth "second" 1
    end

    @fact (@tracevals bambam) --> Any["3",100,200,300,400,500,600,700,800,900,1000]
end

facts("undefined is defined (as :undefined)") do
    @clearallsnaps
    @snap barney
    @fact (@tracevals barney) --> [:undefined]
    @fact_throws DomainError (@snap throw(DomainError()))
end

facts("Dicout") do
    @clearallsnaps
    @watch fred barney bambam

    fred = "1"
    barney = "2"
    bambam = "3"
    @snapallatNth "first" 1

    for i in 1:10
        fred = 2*i
        barney = 10*i
        bambam = 100*i
        @snapallatNth "second" 1
    end
    resdic = @tracevalsdict
    @fact (resdic["bambam"]) --> Any["3",100,200,300,400,500,600,700,800,900,1000]
end

FactCheck.exitstatus()
end
