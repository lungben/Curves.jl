using Curves
using Test
using Interpolations

@testset "Curves.jl" begin
    x1 = [3, 9, 18, 30, 91]
    y1 = [1.01, 1.204, 1.54, 1.81, 2.12]
    c1 = Curve(x1, y1)
    x2 = [5, 12, 18, 30, 125, 291]
    y2 = [1.01, 1.204, 1.54, 1.81, 2.12, 7.436]
    clog = Curve(x2, y2, logx=true, logy=true)
    clogy = Curve(x1, y1, logy=true)

    # equality
    c2 = Curve(c1)
    c3 = Curve(c1, logx=true)
    @test c1 == c2
    @test c1 ≈ c2
    @test !(c1 == c3)
    @test !(c1 ≈ c3)


    # Interpolation
    @test interpolate(5.5, c1) ≈ (1.204-1.01)/(9-3)*(5.5-3)+1.01
    c_int = interpolate([3, 9, 14, 31, 33], c1)
    @test c_int isa Curve && length(c_int) == 5

    @test interpolate(25, clog) ≈ exp((log(1.81)-log(1.54))/(log(30)-log(18))*(log(25)-log(18))+log(1.54))
    c_log_int = interpolate([3, 9, 14, 31, 33], clog)
    @test c_log_int isa Curve && length(c_log_int) == 5 && c_log_int.logx==true && c_log_int.logy==true
    @test interpolate(5.5, clogy) ≈ exp((log(1.204)-log(1.01))/(9-3)*(5.5-3)+log(1.01))
    @test interpolate(c1, clog) isa Curve

    # Operations with Scalars
    @test (c1 + 2).y == y1 .+ 2 && (c1 + 2).x == x1
    @test (1/c1).y == 1 ./ y1 && (1/c1).x == x1
    c_add = +(c1, 2, logy=true)
    @test c_add.y == y1 .+ 2 && c_add.logy == true
    # test if interpolation object gets correctly updated
    @test interpolate(5.5, 2c1) ≈ 2((1.204-1.01)/(9-3)*(5.5-3)+1.01)
    @test exp(c1).y == exp.(c1.y)
    @test sin(c1)/cos(c1) ≈ tan(c1)

    # Merges
    c1d = Curve([1, 3, 3, 7, 9], [2, 4, 4, 8, 10])
    @test drop_duplicates(c1d).x == [1, 3, 7, 9]
    @test concat(c1, c1d).x == [1, 3, 7, 9, 18, 30, 91]

    # Operations on Curves
    c_sum = c1+c1d
    @test c_sum.x == sort(unique(hcat(c1.x, c1d.x)))

    sumc1 = c1+c1
    @test sumc1.y == (2*c1).y # tests correctness of result
    @test sumc1 == 2c1 # tests comparison operator in addition
    @test log(clogy/c1d).logx == false

    # apply
    @test apply((t,r) -> exp(-r/100*t), c1, logy=true).logy == true
    @test apply(x -> 2x, c1, axis=:y) ≈ 2c1
    res = apply(x -> 3x, c1, axis=:x)
    @test res.x == 3c1.x && res.y == c1.y
    res = apply((x, y) -> 2x+y, c1, axis=:xy)
    @test res.x == c1.x && res.y == c1.y .+ 2.0 .* c1.x
    
    # test non-standard interpolators
    c_const = Curve(x1, y1, method=Gridded(Constant()))
    @test interpolate(28, c_const) == 1.81
    c_noint = Curve(x1, y1, method=NoInterp())
    @test interpolate(18, c_noint) == 1.54 # does not throw error because 18 is a grid point
    
    # test extrapolations
    @test interpolate(1, c1) == 1.01 # constant extrapolation
    c_42 = Curve(x1, y1, extrapolation=42)
    @test interpolate(1042, c_42) == 42

    # Test use case in Readme
    # construct zero interest rate curve
    c_zero_base = Curve([2, 7, 30, 90, 180, 365], [0.5, 0.7, 0.75, 0.83, 1.1, 1.5])
    # define zero rate shifts (e.g. for stress testing or sensitivities)
    c_shifts = Curve([2, 185, 360], [0.1, -0.1, 0.2])
    # shift curve
    c_shifted = c_zero_base + c_shifts
    # calculate discount factors for the unshifted and shifted curves
    c_base_df=apply((x,y) -> exp(-x*y/100/365), c_zero_base, logy=true)
    c_shifted_df = apply((x,y) -> exp(-x*y/100/365), c_shifted, logy=true)
    # calculate log-returns of discount factors
    log_ret = log(c_shifted_df/c_base_df)
    # apply log returns to the base curve - this should give the shifted curve back
    curve_scenario = *(c_base_df, exp(log_ret), logy=true)
    @test curve_scenario ≈ c_shifted_df

end
