using FactCheck
using RickTracy

num_item_fields = length(fieldnames(TraceItem))

facts("first things first") do
    fred = "flintstone"
    barney = 10

    @snap fred barney

    @fact (@tracevals fred) --> ["flintstone"]
    @fact (@tracevals barney) --> [10]
end

facts("snap the Nth") do
    for person in ["wilma", "fred", "betty", "barney"]
        @snap (N=2) person
    end
    @fact (@tracevals person) --> ["wilma", "betty"]
end

facts("snapat all on the floow") do
    @resetallsnaps
    fred = "Savage"
    winnie = 8.5
    @snap loc="McKinley" fred winnie
    traceitems = @traceitems loc="McKinley"
    @fact length(traceitems) --> 2
    @fact traceitems[1].exprstr --> "fred"
    @fact traceitems[1].val --> "Savage"
    @fact traceitems[2].exprstr --> "winnie"
    @fact traceitems[2].val --> 8.5
end

facts("snapifat") do
    @resetallsnaps
    for i in 1:10
        @snap loc="looptown" iff= i%3 == 0 && i != 6 i
        i%3 == 0 || @snap loc="loopcity" i
    end
    traceitems = @traceitems loc="looptown"
    @fact (@tracevals loc="looptown" i) --> [3,9]
    @fact (@tracevals loc="loopcity" i) --> [1,2,4,5,7,8,10]
end

facts("snapif") do
    @resetallsnaps
    for i in 1:10
        i%3 == 0 && @snap i
    end
    @fact (@tracevals i) --> [3,6,9]
end

facts("snapall") do
    @resetallsnaps
    @watch fred barney bambam

    fred = "1"
    barney = "2"
    bambam = "3"
    @snapall loc="first" N=1

    for i in 1:10
        fred = 2*i
        barney = 10*i
        bambam = 100*i
        @snapall loc="second" N=2
    end

    @fact (@tracevals bambam) --> Any["3",100,300,500,700,900]
end

facts("undefined is defined (as :undefined)") do
    @resetallsnaps
    @snap barney
    @fact (@tracevals barney) --> [:undefined]
    @fact_throws DomainError (@snap throw(DomainError()))
end

facts("tracevalsdic") do
    @resetallsnaps
    @watch fred barney bambam

    fred = "1"
    barney = "2"
    bambam = "3"
    @snapall loc="first" N=1

    for i in 1:10
        fred = 2*i
        barney = 10*i
        bambam = 100*i
        @snapall loc="second" N=5
    end
    @fact (@tracevalsdic) --> Dict("fred"=>Any["1",2,12],"barney"=>Any["2",10,60],"bambam"=>Any["3",100,600])
    @fact (@tracevalsdic loc=second) --> Dict("fred"=>[2,12], "barney"=>[10,60],
                                            "bambam"=>[100,600])
    @fact (@tracevalsdic loc=second bambam) --> Dict("bambam"=>[100,600])
    @fact (@tracevalsdic barney) --> Dict("barney"=>["2",10,60])
end

facts("tracesdf & tracesdic") do
    @resetallsnaps
    for i in 1:10
        @snap loc=ok1 i
        @snap loc=ok2 "dingo$i"
    end
    df1 = @tracesdf loc=ok1
    @fact sort!(names(df1)) --> sort!(fieldnames(TraceItem))
    @fact size(df1) --> (10, num_item_fields)

    df2 = @tracesdf
    @fact sort!(names(df1)) --> sort!(fieldnames(TraceItem))
    @fact size(df2) --> (20, num_item_fields)

    dicky = @tracesdic i
    @fact dicky[:val] --> collect(1:10)
end

facts("filter multiple expressions") do
    @resetallsnaps
    for i in 1:10
        @snap loc=ok1 i i^2
        @snap loc="I love you bad momo" "$i personal space"
    end
    dfi = @tracesdf i i^2
    df1 = @tracesdf loc=ok1
    df1i = @tracesdf loc=ok1 i i^2
    @fact sort!(names(dfi)) --> sort!(fieldnames(TraceItem))
    @fact size(dfi) --> (20, num_item_fields)
    @fact dfi --> df1
    @fact dfi --> df1i

    df2 = @tracesdf
    @fact sort!(names(df1)) --> sort!(fieldnames(TraceItem))
    @fact size(df2) --> (30, num_item_fields)

    dickfor = @tracevalsdic i i^2
    @fact dickfor["i"] --> collect(1:10)
    @fact dickfor[string(:(i^2))] --> collect(1:10) .^2

    oohyeah = @tracevals loc="I love you bad momo"
    @fact oohyeah[1] --> "1 personal space"
end

FactCheck.exitstatus()
include("iter_extrema.jl")
include("traces4symvals.jl")
