using Curves
using Test

@testset "Curves.jl" begin
    x1 = [3, 9, 18, 30, 91]
    y1 = [1.01, 1.204, 1.54, 1.81, 2.12]
    c1 = Curve(x1, y1)
    x2 = [5, 12, 18, 30, 125, 291]
    y2 = [1.01, 1.204, 1.54, 1.81, 2.12, 7.436]
    clog = Curve(x2, y2, logx=true, logy=true)
    clogy = Curve(x1, y1, logy=true)

    # Interpolation
    @test interpolate(5.5, c1) ≈ (1.204-1.01)/(9-3)*(5.5-3)+1.01
    c_int = interpolate([3, 9, 14, 31, 33], c1)
    @test c_int isa Curve && length(c_int) == 5

    @test interpolate(25, clog) ≈ exp((log(1.81)-log(1.54))/(log(30)-log(18))*(log(25)-log(18))+log(1.54))
    c_log_int = interpolate([3, 9, 14, 31, 33], clog)
    @test c_log_int isa Curve && length(c_log_int) == 5 && c_log_int.logx==true && c_log_int.logy==true

    @test interpolate(5.5, clogy) ≈ exp((log(1.204)-log(1.01))/(9-3)*(5.5-3)+log(1.01))

    # Operations with Scalars
    @test (c1 + 2).y == y1 .+ 2 && (c1 + 2).x == x1
    @test (1/c1).y == 1 ./ y1 && (1/c1).x == x1

    # Merges
    c1d = Curve([1, 3, 3, 7, 9], [2, 4, 4, 8, 10])
    @test drop_duplicates(c1d).x == [1, 3, 7, 9]
    @test concat(c1, c1d).x == [1, 3, 7, 9, 18, 30, 91]

    # Operations on Curves - ToDo
    c1+c1d
    c1^c1d

    sumc1 = c1+c1
    @test sumc1.y == (2*c1).y # tests correctness of result
    @test sumc1 == 2c1 # tests comparison operator in addition

    # apply - ToDo
    apply((t,r) -> exp(-r/100*t), c1)
    @test apply(x -> 2x, c1, axis=:y) ≈ 2c1
    res = apply(x -> 3x, c1, axis=:x)
    @test res.x == 3c1.x && res.y == c1.y
    res = apply((x, y) -> 2x+y, c1, axis=:xy)
    @test res.x == c1.x && res.y == c1.y .+ 2.0 .* c1.x




end
