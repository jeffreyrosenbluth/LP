include("CFRcs.jl")

botprofile = Botprofile(1000, 2, 3, 7, 2, 4)

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

function showpolicy(policys, hand, hist)
    hand = map(n -> UInt8(n), hand)
    hist = map(n -> UInt8(n), hist)
    k = key(hand, hist)
    policy = policys[k].strategysum |> normalize
    for (k, v) in policy
        if v >= 0.01
            @printf("%2.0f => %0.2f\n", k, v)
        end
    end
end

function move(dict, hand, rawhist)
    hist = copy(rawhist)
    k = key(hand, hist)
    if !haskey(dict, k)
        while length(hist) > 0 && hist[1] >= 0 && hist[1] < 20
            popfirst!(hist)
        end
    end
    k = key(hand, hist)
    if !haskey(dict, k) && length(hist) > maxhist
        k = hist[end-maxhist+1] != 0 ? key(hand, hist[end-maxhist+1:end]) :
            key(hand, hist[end-maxhist+2:end])
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
        mv = player == 1 ? move(dict1, hands[1, :], hist) : move(dict2, hands[2, :], hist)
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
            if mv ∉ actions(bids, hist)
                println("XXX - Illegal action, please try again - XXX")
                continue
            end
            player = her
        else
            mv = move(policys, hands[player, :], hist)
            player = you
            if mv == 0
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
        @printf("Total: %.0f, Games: %.0f, Average: %.2f\n", score, n, score / n)
        println("======================================")
        println()
        @printf("Hand %.0f\n", n + 1)
    end
end
