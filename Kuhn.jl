using Random, Distributions, Printf
using LinearAlgebra: dot, ⋅

numactions = 2

mutable struct Node
    regretsum::Vector{AbstractFloat}
    strategy::Vector{AbstractFloat}
    strategysum::Vector{AbstractFloat}
end

function Base.show(io::IO, n::Node)
    sprintarr(a) = map(x -> @sprintf("%0.2f, ", x), a) |> join
    @printf("r: %s s: %s ss: %s\n", sprintarr(n.regretsum),
        sprintarr(n.strategy), sprintarr(n.strategysum))
end

struct Infoset
    hand::Vector{UInt8}
    history::Vector{Char}
end

Base.show(io::IO, i::Infoset) = print(i.hand[1], String(i.history))
Base.hash(a::Infoset, h::UInt) = hash(a.history, hash(a.hand, hash(:Infoset, h)))
Base.isequal(i1::Infoset, i2::Infoset) = i1.hand == i2.hand && i1.history == i2.history
Base.isless(i1::Infoset, i2::Infoset) = i1.hand < i2.hand

function Base.show(io::IO, d::Dict{Infoset, Node})
    for (k, v) in d
        print(k, " => ", v)
    end
end

pos(x) = x > 0.0 ? x : 0.0

issomething(s) = !isnothing(s)

function normalize(xs)
    total = sum(xs)
    n = length(xs)
    total > 0 ? xs / total : fill(1.0 / n, n)
end

function getstrategy(node, realizationweight)
    node.strategy = map(pos, node.regretsum) |> normalize
    node.strategysum += realizationweight * node.strategy
    node.strategy
end

function getnode(policys, infoset)
    if !haskey(policys, infoset)
        node = Node(zeros(numactions), zeros(numactions), zeros(numactions))
        policys[infoset] = node
    end
    policys[infoset]
end

function terminal(history, cards)
    plays = length(history)
    if plays > 1
        player = plays % 2 + 1
        opponent = player % 2 + 1
        playercardhigher = cards[player] > cards[opponent]
        if history[end] == 'p' # terminal pass
            if history == ['p', 'p']
                return playercardhigher ? 1 : -1
            else
                return 1
            end
        elseif history[end-1:end] == ['b', 'b'] # double bet
            return playercardhigher ? 2 : -2
        end
    end
    return nothing
end

function cfr(policys::Dict{Infoset, Node}, cards, history, p1, p2)
    terminalutility = terminal(history, cards)
    if issomething(terminalutility)
        return terminalutility
    end

    player = length(history) % 2 + 1
    prob = [p1, p2][player]
    infoset = Infoset([cards[player]], history)
    node = getnode(policys, infoset)
    strategy = getstrategy(node, prob)
    util = zeros(numactions)
    for a in 1:numactions
        nexthistory = copy(history)
        push!(nexthistory, ['p', 'b'][a])
        util[a] = player == 1 ?
            -cfr(policys, cards, nexthistory, p1 * strategy[a], p2) :
            -cfr(policys, cards, nexthistory, p1, p2 * strategy[a])
    end
    nodeutil = strategy ⋅ util
    regret = util .- nodeutil
    node.regretsum += [p2, p1][player] * regret
    nodeutil
end

function train(policys::Dict{Infoset, Node}, n)
    cards = [1, 2, 3]
    util = 0.0
    for _ in 1:n
        shuffle!(cards)
        util += cfr(policys, cards, [], 1.0, 1.0)
    end
    println(util / n)
    ps = Dict()
    for (k, v) in policys
        s = v.strategysum
        ps[k] = normalize(s)
    end
    ps
end

function displayresult(d)
    for (k, v) in d
        print(k, " => ")
        map(x -> @printf("%0.2f, ", x), v)
        println()
    end
end
