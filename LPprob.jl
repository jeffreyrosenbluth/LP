using StatsBase

function randhands!(a::Matrix{UInt8})
    for i in eachindex(a)
        a[i] = rand(0x0:(ranks-0x1))
    end
    sort!(a, dims = 2)
    return a
end

function atleast(cards, ranks, k, n)
    s = 0
    a = Vector{Int}(undef, cards)
    for j in 1:n
        for i in eachindex(a)
            a[i] = rand(1:ranks)
        end
        cs = counts(a)
        if maximum(cs) >= k
            s += 1
        end
    end
    s / n
end

function exactly(cards, ranks, k, n)
    s = 0
    a = Vector{Int}(undef, cards)
    for j in 1:n
        for i in eachindex(a)
            a[i] = rand(1:ranks)
        end
        cs = counts(a)
        if maximum(cs) == k
            s += 1
        end
    end
    s / n
end
