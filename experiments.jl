include("CFRcs.jl")

function rotn!(hist, n)
    if length(hist) > n
        popfirst!(hist)
    end
end

function makebids(m, n, r)
    vcat([100i + 10j for j = 0:(r-1), i = m:n]...)
end

function moves(bids, history)
    n = length(history)
    if n > 2 && history[end-2] % 10 == 5 && history[end] % 10 == 5
        return [1]
    elseif n > 1 && history[end] % 10 == 5
        b = findfirst(isequal(history[end-1]), bids) + 1
        return pushfirst!(bids[b:end], 1)
    elseif n > 0
        b = findfirst(isequal(history[end]), bids) + 1
        return pushfirst!(bids[b:end], history[end] + 5)
    else
        return bids
    end
end

function mkGraph(q, r, m)
    bids = makebids(1, 2q, r)
    initBids = map(x -> [x], bids)
    graph = Dict([] => initBids)
    parent = []
    children = Set(initBids)
    while !isempty(children)
        vertex = pop!(children)
        if vertex[end] == 1
            graph[vertex] = []
            continue
        end
        acts = moves(bids, vertex)
        for a in acts
            v = push!(copy(vertex), a)
           rotn!(v, m)
            if !haskey(graph, v)
                push!(children, v)
            end
            if haskey(graph, vertex)
                graph[vertex] = push!(copy(graph[vertex]), v)
            else
                graph[vertex] = [v]
            end
        end
    end
    graph
end

function hasincoming(graph, v)
    vals = values(graph)
    for xs in vals
        if v ∈ xs
            return true
        end
    end
    false
end

function kahn(graph)
    graph = deepcopy(graph)
    result = []
    s = Set([[]])
    while !isempty(s)
        # v = pop!(s)
        v = minimum(s)
        delete!(s, v)
        push!(result, v)
        while !isempty(graph[v])
            u = pop!(graph[v])
            if !hasincoming(graph, u)
                push!(s, u)
            end
        end
    end
    result
end
