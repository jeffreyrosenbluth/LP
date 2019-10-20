using Random, Distributions, Printf
using Profile, BenchmarkTools

const quant = 0x2 # Number of cards in each hand.
const ranks = 0x3 # Number of ranks possible for each card.

function mkbids(quant, ranks)
    a = [0xa * i + j for j = 0x0:(ranks-0x1), i = 0x1:0x2*quant]
    vcat(a...)
end

const bids = mkbids(quant, ranks)

mutable struct Node
    regretsum::Dict{UInt8,Float64}
    strategysum::Dict{UInt8,Float64}
end

const Key = Tuple{Array{UInt8,1},Array{UInt8,1}}
key(hand::Array{UInt8,1}, history::Array{UInt8,1})::Key = (hand, history)

pos(x) = x > 0 ? x : zero(x)

issomething(s) = !isnothing(s)

Base.map(f, dict::AbstractDict) = Dict(k => f(v) for (k, v) in dict)

function normalize(xs)
    total = values(xs) |> sum
    n = length(xs)
    total > 0 ? map(x -> x / total, xs) : map(_ -> 1.0 / n, xs)
end

parsebid(n) = divrem(n, 10)

function getstrategy(node, realizationweight)
    strategy = map(pos, node.regretsum) |> normalize
    for (k, v) in strategy
        node.strategysum[k] += realizationweight * v
    end
    strategy
end

function getnode(policys, hand, history)
    k = key(hand, history)
    if !haskey(policys, k)
        dict()::Dict{UInt8,Float64} = Dict(k => 0.0 for k in actions(history))
        node = Node(dict(), dict())
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
    if n > 2 && history[end-2] == 0 && history[end] == 0
        return [1]
    elseif n > 1 && history[end] == 0
        return pushfirst!(filter(x -> x > history[end-1], bids), 1)
    elseif n > 0
        return pushfirst!(filter(x -> x > history[end], bids), 0)
    else
        return bids
    end
end

function cfr(policys, hands, history, p1, p2)::Float64
    terminalutility = terminal(history, hands)
    if issomething(terminalutility)
        return -terminalutility
    end
    nodeutil = 0.0
    player = length(history) % 2 + 1
    prob = [p1, p2][player]
    node = getnode(policys, hands[player, :], history)
    strategy = getstrategy(node, prob)
    util = Dict{UInt8,Float64}()
    acts = keys(strategy)
    for a in acts
        nexthistory = push!(copy(history), a)
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
        a[i] = rand(0x0:(ranks-0x1))
    end
    # sort!(a[1,:])
    # sort!(a[2,:])
    sort!(a, dims = 2)
    return a
end

function train(n)
    policys = Dict{Key,Node}()
    util = 0.0
    hs = Matrix{UInt8}(undef, (2, quant))
    for _ = 1:n
        randhands!(hs)
        util += cfr(policys, hs, Array{UInt8,1}(), 1.0, 1.0)
    end
    println(util / n)
    policys
end

function displayresult(d)
    for (k, v) in d
        print(k, " => ")
        map(x -> @printf("%0.2f, ", x), v)
        println()
    end
end

function showpolicy(policys, hand, hist)
    k = key(hand, hist)
    return policys[k].strategysum |> normalize
end


function samp(probdict)
    s = rand()
    cumm = 0.0
    for (k, v) in probdict
        cumm += v
        if s <= cumm
            return k
        end
    end
end

function move(dict, hand, hist)
    k = key(hand, hist)
    d = dict[k].strategysum |> normalize
    samp(d)
end

function autoplay(dict, hands)
    hist = Vector{UInt8}()
    player = 1
    while true
        mv = move(dict, hands[player, :], hist)
        push!(hist, mv)
        if mv == 1
            w = win(hist, hands)
            x = (player == 1 && w) || (player == 2 && !w) ? 1 : -1
            return player, x, hist
        end
        player = player == 1 ? 2 : 1
    end
end

function randplay(dict, n)
    total = 0
    hs = Matrix{UInt8}(undef, (2, quant))
    for _ = 1:n
        (_, x, _) = autoplay(dict, randhands!(hs))
        total += x
    end
    println(total / n, " ", total, " ", n)
end

function play(policys)
    hist = Vector{UInt8}()
    hands = Matrix{UInt8}(undef, (2, quant))
    randhands!(hands)
    you = rand(1:2)
    her = you == 1 ? 2 : 1
    player = 1
    @printf("Your hand: %.0f %.0f\n", hands[you, :]...)
    while true
        if player == you
            println("Your move, bid or 0 to challenge, 1 to count")
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
            if mv == 0
                println("Opponent Challenges")
            elseif mv == 1
                println("Opponent Counts")
            else
                @printf("Opponent bids %.0f\n", mv)
            end
        end
        push!(hist, mv)
        if mv == 1
            w = win(hist, hands)
            x = (player == you && w) || (player == her && !w) ? -1 : 1
            println("--------------------------------")
            @printf("Opponents hand: %.0f %.0f\n", hands[her, :]...)
            result = x == 1 ? "WIN" : "LOSE"
            @printf("Score: %s\n", result)
            return x
        end
    end
end

function games(policys)
    n = 0
    score = 0
    while true
        n += 1
        score += play(policys)
        println("================================")
        @printf(
            "Total: %.0f, Games: %.0f, Average: %.2f\n\n",
            score,
            n,
            score / n,
        )
    end
end
