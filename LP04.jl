#=
Counterfactual regret minimizaiont
- Chance sampling
- Pruning
- Imperfect recall
=#
using Random, Distributions, Printf
using Profile, BenchmarkTools
using Serialization

const quant = 2 # Number of cards in each hand.
const ranks = 3 # Number of ranks possible for each card.
const maxhist = 7 # Maximum length of history.
const lowquant = 2
const highquant = 4

Base.show(io::IO, x::UInt8) = show(io, Int(x))
Base.show(io::IO, x::Vector{UInt8}) = show(io, map(n -> Int(n), x))

function allbids(low, high, rs)
    a = [10 * i + j for j = 0:(rs - 1), i = low:high]
    pushfirst!(a, 0, 1)
end

function mkbids(quant, ranks)
    a = [10 * i + j for j = 0:(ranks - 1), i = 2:4]
    vcat(a...)
end

const bids = mkbids(quant, ranks)

mutable struct Node
    regretsum::Vector{Float64}
    strategysum::Vector{Float64}
end

const Key = Tuple{Array{UInt8,1},Array{UInt8,1}}
key(hand::Vector{UInt8}, history::Vector{UInt8})::Key = (hand, history)

pos(x) = x > 0 ? x : zero(x)

issomething(s) = !isnothing(s)

function normalize(xs)
    total = sum(xs)
    n = length(xs)
    total > 0 ? map(x -> x / total, xs) : map(_ -> 1.0 / n, xs)
end

parsebid(n) = divrem(n, 10)

function lastn!(hist, n)
    if length(hist) > n
        popfirst!(hist)
    end
    if hist[1] == 2 # cannot start with a challenge.
        popfirst!(hist)
    end
end

function getstrategy(node, realizationweight)
    strategy = map(pos, node.regretsum) |> normalize
    for k in 1:highbid
        node.strategysum[k] += realizationweight * strategy[k]
    end
    strategy
end

function getnode(policys, hand, history)
    k = key(hand, history)
    if !haskey(policys, k)
        node = Node(zeros(Float64, highbid), zeros(Float64, highbid))
        policys[k] = node
    end
    policys[k]
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

function actions(history)
    n = length(history)
    if n > 2 && history[end-2] == 2 && history[end] == 2
        return [1]
    elseif n > 1 && history[end] == 2
        return pushfirst!(filter(x -> x > history[end-1], bids), 1)
    elseif n > 0
        return pushfirst!(filter(x -> x > history[end], bids), 2)
    else
        return bids
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
    util = zeros(Float64, highbid)
    acts = actions(history)
    for a in acts
        nexthistory = push!(copy(history), a)
        lastn!(nexthistory, maxhist)
        util[a] = player == 1 ?
                  -cfr(policys, hands, nexthistory, p1 * strategy[a], p2) :
                  -cfr(policys, hands, nexthistory, p1, p2 * strategy[a])
        nodeutil += strategy[a] * util[a]
    end
    q = [p2, p1][player]
    for a in acts
        node.regretsum[a] += q * (util[a] - nodeutil)
    end
    nodeutil
end

function randhands!(a::Matrix{UInt8})
    for i in eachindex(a)
        a[i] = rand(0:(ranks-1))
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

function samp(probarray)
    s = rand()
    cumm = 0.0
    for k in 1:length(probarray)
        cumm += probarray[k]
        if s <= cumm
            return k
        end
    end
end

function showpolicy(policys, hand, hist)
    hand = map(n -> UInt8(n), hand)
    hist = map(n -> UInt8(n), hist)
    k = key(hand, hist)
    policy = policys[k].strategysum |> normalize
    for k in 1:length(policy)
        if policy[k] >= 0.01
            @printf("%2.0f => %0.2f\n", k, policy[k])
        end
    end
end

function move(dict, hand, rawhist)
    hist = copy(rawhist)
    k = key(hand, hist)
    if !haskey(dict, k)
        while length(hist) > 0 && hist[1] >= 10 && hist[1] < 20
            popfirst!(hist)
        end
    end
    k = key(hand, hist)
    if !haskey(dict, k) && length(hist) > maxhist
        k = hist[end-maxhist+1] != 2 ?
            key(hand, hist[end-maxhist+1: end]) :
            key(hand, hist[end-maxhist+2: end])
    end
    d = dict[k].strategysum |> normalize
    samp(d)
end

function selfplay(dict, hands)
    hist = UInt8[]
    player = 1
    while true
        mv = move(dict, hands[player, :], hist)
        push!(hist, mv)
        if mv == 1
            w = win(hist, hands)
            x = (player == 1 && w) || (player == 2 && !w) ? 1 : -1
            return player, x, hist
        end
        player = 3 - player # change the player
    end
end

function headsup(dict1, dict2, hands)
    hist = UInt8[]
    player = rand(1:2)
    while true
        mv = player == 1 ?
            move(dict1, hands[1, :], hist) :
            move(dict2, hands[2, :], hist)
        push!(hist, mv)
        if mv == 1
            w = win(hist, hands)
            x = (player == 1 && w) || (player == 2 && !w) ? 1 : -1
            return player, x, hist
        end
        player = 3 - player
    end
end

function randplay(dict1, dict2, n)
    total = 0
    hs = Matrix{UInt8}(undef, (2, quant))
    for _ = 1:n
        (_, x, _) = headsup(dict1, dict2, randhands!(hs))
        total += x
    end
    println(total / n, " ", total, " ", n)
end

function play(policys)
    hist = UInt8[]
    hands = Matrix{UInt8}(undef, (2, quant))
    randhands!(hands)
    you = rand(1:2)
    her = 3 - you
    player = 1
    println("Your hand: ", hands[you, :])
    while true
        if player == you
            print("Your move: ")
            t = readline()
            mv = tryparse(UInt8, t)
            if mv ∉ actions(hist)
                println("XXX - Illegal action, please try again - XXX")
                continue
            end
            player = her
        else
            mv = move(policys, hands[player, :], hist)
            player = you
            if mv == 2
                println("Opponent : Challenge")
            elseif mv == 1
                println("Opponent : Counts")
            else
                @printf("Opponent : %.0f\n", mv)
            end
        end
        push!(hist, mv)
        if mv == 1
            w = win(hist, hands)
            x = (player == you && w) || (player == her && !w) ? -1 : 1
            println()
            println(x == 1 ? "++++++++++++++++ WIN +++++++++++++++++" :
                             "---------------- LOSE ----------------")
            println()
            println("Opponents hand: ", hands[her, :])
            return x
        end
    end
end

function games(policys)
    n = 0
    score = 0
    println("----------------------------")
    @printf("Liars Poker: %.0f Card, %.0f Ranks\n", quant, ranks)
    println("0 - Challenge, 1 - Count")
    println("----------------------------")
    println()
    while true
        n += 1
        score += play(policys)
        @printf(
            "Total: %.0f, Games: %.0f, Average: %.2f\n",
            score,
            n,
            score / n,
        )
        println("======================================")
        println()
        @printf("Hand %.0f\n", n + 1)
    end
end
