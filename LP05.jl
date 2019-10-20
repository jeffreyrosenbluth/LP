#=
Counterfactual regret minimizaiont
- Chance sampling
- Pruning
- Imperfect recall
=#
using Random, Distributions, Printf
using Profile, BenchmarkTools
using Serialization

const quant = 0x2 # Number of cards in each hand.
const ranks = 0x3 # Number of ranks possible for each card.
const maxhist = 7 # Maximum length of history.
const maxofakind = 4

const Key = Tuple{Array{UInt8,1},Array{UInt8,1}}
key(hand::Vector{UInt8}, history::Vector{UInt8})::Key = (hand, history)

Base.show(io::IO, x::UInt8) = show(io, Int(x))
Base.show(io::IO, x::Vector{UInt8}) = show(io, map(n -> Int(n), x))

bidmatrix(q, r) = zeros(Float64, (q,r))
pos(x) = x > 0 ? x : zero(x)
issomething(s) = !isnothing(s)
parsebid(n) = divrem(n, 10)

mutable struct Node
    actions::Vector{UInt8}
    regretsum::Matrix{Float64}
    strategysum::Matrix{Float64}
end

function mkbids(quant, ranks)
    a = [0xa * i + j for j = 0x1:ranks, i = 0x2:UInt8(maxofakind)]
    vcat(a...)
end

const bids = mkbids(quant, ranks)

function actions(history)
    n = length(history)
    if n > 2 && history[end-2] == 12 && history[end] == 12
        return [11]
    elseif n > 1 && history[end] == 12
        b = findfirst(isequal(history[end-1]), bids) + 1
        return pushfirst!(bids[b:end], 11)
    elseif n > 0
        b = findfirst(isequal(history[end]), bids) + 1
        return pushfirst!(bids[b:end], 12)
    else
        return bids
    end
end

function getnode(policys, hand, history)
    k = key(hand, history)
    if !haskey(policys, k)
        acts = actions(history)
        node = Node(acts, bidmatrix(maxofakind, ranks), bidmatrix(maxofakind, ranks))
        policys[k] = node
    end
    policys[k]
end

function normalize(n, xs)
    total = sum(xs)
    total > 0 ? (x -> x / total).(xs) : (_ -> 1.0 / n).(xs)
end

function getstrategy(node, realizationweight)
    strategy = normalize(length(node.actions), pos.(node.regretsum))
    for i in eachindex(strategy)
        node.regretsum[i] += realizationweight * strategy[i]
    end
    strategy
end

function win(history, hands)
    (quant, rank) = history[end-2] |> parsebid
    count(c -> c == rank, hands) >= quant
end


function terminal(history, hands)
    plays = length(history)
    if plays > 2 && history[end] == 11
        return win(history, hands) ? 1 : -1
    end
    return nothing
end

function lastn!(hist, n)
    if length(hist) > n
        popfirst!(hist)
    end
    if hist[1] == 12 # cannot start with a challenge.
        popfirst!(hist)
    end
end

function cfr(policys, hands, history, p1, p2)::Float64
    terminalutility = terminal(history, hands)
    if issomething(terminalutility)
        return -terminalutility
    end
    player = length(history) % 2 + 1
    if p1 <= 0 && p2 <= 0
        return 0.0
    end
    nodeutil = 0.0
    prob = [p1, p2][player]
    node = getnode(policys, hands[player, :], history)
    strategy = getstrategy(node, prob)
    util = bidmatrix(maxofakind, ranks)
    for a in node.actions
        (i, j) = parsebid(a)
        nexthistory = push!(copy(history), a)
        lastn!(nexthistory, maxhist)
        util[i,j] = player == 1 ?
                  -cfr(policys, hands, nexthistory, p1 * strategy[i,j], p2) :
                  -cfr(policys, hands, nexthistory, p1, p2 * strategy[i,j])
        nodeutil += strategy[i,j] * util[i,j]
    end
    q = [p2, p1][player]
    for a in node.actions
        (i, j) = parsebid(a)
        node.regretsum[i,j] += q * (util[i,j] - nodeutil)
    end
    nodeutil
end

function randhands!(a::Matrix{UInt8})
    for i in eachindex(a)
        a[i] = rand(0x0:(ranks-0x1))
    end
    sort!(a, dims = 2)
    return a
end

function train(n)
    policys = Dict{Key,Node}()
    util = 0.0
    hs = Matrix{UInt8}(undef, (2, quant))
    for i = 1:n
        if i % 1000 == 0
            println(i)
        end
        randhands!(hs)
        util += cfr(policys, hs, UInt8[], 1.0, 1.0)
    end
    println(util / n)
    policys
end
