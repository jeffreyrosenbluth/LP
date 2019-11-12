#=
Low level utilityies for dealing with bid sequences.
=#

import Base: isequal

const bitlen = 8

bid2index(n, r) = UInt8(20n + 2r - 20)
index2bid(i) = i % 2 == 0 ? divrem((i + 20) ÷ 2, 10) : (0,0)
parsebid(b) = divrem(b, 10)

struct UInt256 <: Integer
    h::UInt128
    l::UInt128
    UInt256(x) = new(0, x)
    UInt256(x, y) = new(UInt128(x), UInt128(y))
end

Base.hash(x::UInt256, h::UInt) = hash(x.h, hash(x.l, h))
Base.:(==)(x::UInt256, y::UInt256) = (x.h == y.h) & (x.l == y.l)
isequal(x::UInt256, y::UInt256) = isequal(x.h, y.h) & isequal(x.l, y.l)
Base.isless(x::UInt256, y::UInt256) = isequal(x.h, y.h) ? isless(x.l, y.l) : isless(x.h, y.h)
Base.:<(x::UInt256, y::UInt256) = isless(x, y)
Base.:>(x::UInt256, y::UInt256) = y < x
Base.:<<(x::UInt256, y::Integer) = UInt256(x.h << y | (x.l >> (128 - y)), x.l << y)
Base.:<<(x::UInt256, y::Int) = UInt256(x.h << y | (x.l >> (128 - y)), x.l << y)
Base.:<<(x::UInt256, y::Unsigned) = UInt256(x.h << y | (x.l >> (128 - y)), x.l << y)
Base.:>>(x::UInt256, y::Integer) = UInt256(x.h >> y, x.l >> y | (x.h << (128 - y)))
Base.:>>(x::UInt256, y::Int) = UInt256(x.h >> y, x.l >> y | (x.h << (128 - y)))
Base.:>>(x::UInt256, y::Unsigned) = UInt256(x.h >> y, x.l >> y | (x.h << (128 - y)))
Base.:>>>(x::UInt256, y::Integer) = UInt256(x.h >>> y, x.l >>> y | (x.h << (128 - y)))
Base.:>>>(x::UInt256, y::Int) = UInt256(x.h >>> y, x.l >>> y | (x.h << (128 - y)))
Base.:>>>(x::UInt256, y::Unsigned) = UInt256(x.h >>> y, x.l >>> y | (x.h << (128 - y)))
Base.:|(x::UInt256, y::UInt256) = UInt256(x.h | y.h, x.l | y.l)
Base.:|(x::UInt256, y::Unsigned) = UInt256(x.h, x.l | y)
Base.:⊻(x::UInt256, y::UInt256) = UInt256(x.h ⊻ y.h, x.l ⊻ y.l)
Base.:⊻(x::UInt256, y::Unsigned) = UInt256(x.h, x.l ⊻ y.l)
Base.:&(x::UInt256, y::UInt256) = UInt256(x.h & y.h, x.l & y.l)
Base.bitstring(x::UInt256) = bitstring(x.h) * bitstring(x.l)
Base.zero(x::UInt256) = UInt256(0)
Base.zero(UInt256) = UInt256(0)
Base.one(x::UInt256) = UInt256(1)
Base.one(UInt256) = UInt256(1)

peek(x, b) = isless(zero(x), one(x) << UInt8(b) & x)

togglebit(x::UInt256, b::UInt8) = x ⊻ (UInt256(0,1) << b)

function lastbid(hist::UInt256)
    if hist == zero(UInt256)
        return (0, 0)
    end
    if hist.h > zero(UInt128)
        i = UInt8(255)
        x = hist.h
    else
        i = UInt8(127)
        x = hist.l
    end
    while !peek(x, 127)
        x  = x << 0x1
        i -= 0x1
    end
    index2bid(i)
end

function addbid(hist::UInt256, n, r)
    (q, p) = lastbid(hist)
    if n == 0 && q != 0
        return togglebit(hist, bid2index(q, p) + 0x1)
    elseif n != 0
        return togglebit(hist, bid2index(n, r))
    else
        error("Cannot challenge a challenge")
    end
end

addbid(hist::UInt256, b::Integer) = addbid(hist, parsebid(b)...)

function bidindices(hist::UInt256)
    indices = []
    for idx = 0:255
        if isless(UInt256(0), UInt256(1) & hist)
            push!(indices, idx)
        end
        hist = hist >> 0x1
    end
    indices
end

bidhistory(hist::UInt256) = map(index2bid, bidindices(hist))
