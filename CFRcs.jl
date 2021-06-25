#=
Counterfactual regret minimizaion
- Chance sampling
- Pruning
- Imperfect recall
=#
using Random, Distributions, Printf
using Profile, BenchmarkTools
using Serialization

export randhands!,
       key,
       Key,
       actions,
       bids,
       normalize,
       win,
       train,
       Botprofile,
       Node

mutable struct Node
    regretsum::Dict{UInt8,Float64}
    strategysum::Dict{UInt8,Float64}
end

const Key = Tuple{Array{UInt8,1},Array{UInt8,1}}

key(hand::Vector{UInt8}, history::Vector{UInt8})::Key = (hand, history)

mutable struct Botprofile
    num_samples::Int
    cards_per_hand::Int
    num_ranks::Int
    max_history::Int
    min_bid_quant::Int
    max_bid_quant::Int
    all_bids::Vector{UInt8}
    policys::Dict{Key,Node}

    function Botprofile(ns, cph, r, mh, minq, maxq)
        if minq < 0
            @printf(
                "WARNING minimum bid quantity (%.0f) must be positive, defaulting to 0.\n",
                minq,
            )
            minq = 0
        end
        if maxq > 2 * cph
            @printf(
                "WARNING maximum bid quantity (%.0f) exceeds total number of cards, defaulting to %.0f\n",
                maxq,
                2 * cph,
            )
            maxq = 2 * cph
        end
        ab = mkbids(minq, maxq, r)
        new(ns, cph, r, mh, minq, maxq, ab, Dict{Key,Node}())
    end
end

function Base.show(io::IO, profile::Botprofile)
    @printf(io, "Samples:                   %.0f\n", profile.num_samples)
    @printf(io, "Cards per hand:            %.0f\n", profile.cards_per_hand)
    @printf(io, "Number of ranks:           %.0f\n", profile.num_ranks)
    @printf(io, "Max history:               %.0f\n", profile.max_history)
    @printf(io, "Minimum bid qunatitiy:     %.0f\n", profile.min_bid_quant)
    @printf(io, "Maximum bid qunatitiy:     %.0f\n", profile.max_bid_quant)
end

function mkbids(min_quant, max_quant, ranks)
    m = UInt8(min_quant)
    n = UInt8(max_quant)
    r = UInt8(ranks)
    vcat([0xa * i + j for j = 0x0:(r-0x1), i = m:n]...)
end

pos(x) = x > 0 ? x : zero(x)

issomething(s) = !isnothing(s)

Base.map(f, dict::AbstractDict) = Dict(k => f(v) for (k, v) in dict)
Base.show(io::IO, x::UInt8) = show(io, Int(x))
Base.show(io::IO, x::Vector{UInt8}) = show(io, map(n -> Int(n), x))

function normalize(xs)
    total = values(xs) |> sum
    n = length(xs)
    total > 0 ? map(x -> x / total, xs) : map(_ -> 1.0 / n, xs)
end

parsebid(n) = divrem(n, 10)

function lastn!(hist, n)
    if length(hist) > n
        popfirst!(hist)
    end
    if hist[1] == 0 # cannot start with a challenge.
        popfirst!(hist)
    end
end

function getstrategy(node, realizationweight)
    strategy = map(pos, node.regretsum) |> normalize
    for (k, v) in strategy
        node.strategysum[k] += realizationweight * v
    end
    strategy
end

function actions(bids, history)
    n = length(history)
    if n > 2 && history[end-2] == 0 && history[end] == 0
        return [1]
    elseif n > 1 && history[end] == 0
        b = findfirst(isequal(history[end-1]), bids) + 1
        return pushfirst!(bids[b:end], 1)
    elseif n > 0
        b = findfirst(isequal(history[end]), bids) + 1
        return pushfirst!(bids[b:end], 0)
    else
        return bids
    end
end

function getnode(profile, hand, history)
    k = key(hand, history)
    if !haskey(profile.policys, k)
        dict()::Dict{UInt8,Float64} =
            Dict(k => 0.0 for k in actions(profile.all_bids, history))
        node = Node(dict(), dict())
        profile.policys[k] = node
    end
    profile.policys[k]
end

function win(history, hands)
    (quant, rank) = history[end-2] |> parsebid
    count(c -> c == rank, hands) >= quant
end


function terminal(history, hands)
    plays = length(history)
    if plays > 2 && history[end] == 1
        return win(history, hands) ? 1 : -1
    end
    return nothing
end

function cfr(profile, hands, history, p1, p2)::Float64
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
    node = getnode(profile, hands[player, :], history)
    strategy = getstrategy(node, prob)
    util = Dict{UInt8,Float64}()
    acts = keys(strategy)
    for a in acts
        nexthistory = push!(copy(history), a)
        lastn!(nexthistory, profile.max_history)
        util[a] = player == 1 ?
                  -cfr(profile, hands, nexthistory, p1 * strategy[a], p2) :
                  -cfr(profile, hands, nexthistory, p1, p2 * strategy[a])
        nodeutil += strategy[a] * util[a]
    end
    q = [p2, p1][player]
    for a in acts
        node.regretsum[a] += q * (util[a] - nodeutil)
    end
    nodeutil
end

function randhands!(profile, a::Matrix{UInt8})
    for i in eachindex(a)
        a[i] = rand(0x0:(profile.num_ranks-0x1))
    end
    sort!(a, dims = 2)
    return a
end

function train(profile, filename=nothing)
    n = profile.num_samples
    util = 0.0
    hs = Matrix{UInt8}(undef, (2, profile.cards_per_hand))
    for i = 1:n
        if i % 1000 == 0
            println(i)
        end
        randhands!(profile, hs)
        util += cfr(profile, hs, UInt8[], 1.0, 1.0)
    end
    println(util / n)
    if issomething(filename)
        serialize(filename, profile)
    end
    profile
end
