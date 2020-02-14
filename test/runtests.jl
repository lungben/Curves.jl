using Curves
using Test

@testset "Curves.jl" begin
    x1 = [3, 9, 18, 30, 91]
    y1 = [1.01, 1.204, 1.54, 1.81, 2.12]
    c1 = Curve(x1, y1)
    x2 = [5, 12, 18, 30, 125, 291]
    y2 = [1.01, 1.204, 1.54, 1.81, 2.12, 7.436]
    clog = Curve(x2, y2, logx=true, logy=true)

    # Interpolation - ToDo
    interpolate(5.5, c1)
    interpolate([3, 9, 14, 31, 33], c1)
    interpolate([3, 9, 14, 31, 33], clog)

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
    @test sumc1.y == (2*c1).y

    # apply - ToDo
    apply((t,r) -> exp(-r/100*t), c1)


end
