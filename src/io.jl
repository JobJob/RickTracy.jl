using JLD

export savetraces, loadtraces

function savetraces(; traces=traceitems(), path="traces.jld", varname="traces")
    JLD.save(path, varname, traces)
end

function loadtraces(; path="traces.jld", varname="traces", asdefault=true)
    traces = JLD.load(path, varname)
    asdefault && (global happysnaps = traces)
    traces
end
