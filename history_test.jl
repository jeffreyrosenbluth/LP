include("history.jl")
using Test

b1 = UInt128(90000000000000000000000000000000000005)
b0 = UInt128(200000000000000000000000000000000000007)
b2 = UInt128(90000000000000000000000000000000000000)
x0 = UInt256(b0, b1)
x1 = UInt256(b0, b2)

@testset "UInt256" begin
    @test UInt256(7) == UInt256(0, 7)
    @test UInt256(10^10) < UInt256(1, 0)
    @test UInt256(7) > UInt256(0)
    @test (x0 >> 3) << 3 == x1
    @test (x0 >>> 3) << 3 == x1
    @test x0 | x1 == x0
    @test x0 | UInt256(0) == x0
    @test x0 ⊻ x0 == UInt256(0)
    @test x0 & x1 == x1
    @test peek(x0, UInt8(255))
    @test !peek(x0, UInt8(254))
    @test peek(x0, UInt8(0))
    @test !peek(x0, UInt8(1))
    @test togglebit(togglebit(x0, UInt8(8)), UInt8(8)) == x0
    @test zero(x0) == UInt256(0)
    @test zero(UInt256) == UInt256(0)
    @test one(x0) == UInt256(1)
    @test one(UInt256) == UInt256(1)
end;

@testset "Bidding" begin
    @test bid2index(2,1) == 0x16
    @test index2bid(0x16) == (2,1)
    @test index2bid(0x17) == 0
    @test parsebid(42) == (4,2)
    @test addbid(x0, 3, 7) == addbid(x0, 37)
    @test addbid(UInt256(0), 1, 0) == UInt256(0, 1)
end;
