using Curves
using Test

@testset "Curves.jl" begin
    @testset "Curves" begin
        x1 = [3, 9, 18, 30, 91]
        y1 = [1.01, 1.204, 1.54, 1.81, 2.12]
        c1 = Curve(x1, y1)

        x2 = [5, 12, 18, 30, 125, 291]
        y2 = [1.01, 1.204, 1.54, 1.81, 2.12, 7.436]
        clog = Curve(x2, y2, logx=true, logy=true)
        clogy = Curve(x1, y1, logy=true)

        c0 = Curve([3], [5.5]) # curve with single point

        # equality
        c2 = Curve(c1)
        c3 = Curve(c1, logx=true)
        @test c1 == c2
        @test c1 ≈ c2
        @test !(c1 == c3)
        @test !(c1 ≈ c3)
        @test !(c0 == c1)
        @test c0 == Curve(3, 5.5)
        @test Curve(Tenor("3D"), 7.8) == Curve([3], [7.8])

        # first / last
        @test firstpoint(c1, dims=1) == 3
        @test firstpoint(c1, dims=2) == 1.01
        @test lastpoint(c1, dims=1) == 91
        @test lastpoint(c1, dims=2) == 2.12
        @test_throws ErrorException firstpoint(c1, dims=3)
        @test_throws ErrorException lastpoint(c1, dims=0)
        @test firstpoint(c0) == lastpoint(c0) == 3

        @test first(c1, 3) == Curve([3, 9, 18], [1.01, 1.204, 1.54])
        @test last(c1, 4) == Curve([9, 18, 30, 91], [1.204, 1.54, 1.81, 2.12])
        @test first(c1, 10) == c1
        @test last(c1, 100) == c1
        @test_throws ErrorException first(c1, 0)
        @test_throws ErrorException last(c1, -1)
        @test first(c0, 10) == last(c0, 10) == c0

        @test filter((x) -> x > 10, c1) == Curve([18, 30, 91], [1.54, 1.81, 2.12])
        @test filter((x) -> x < 2, c1, axis=:y) == Curve([3, 9, 18, 30], [1.01, 1.204, 1.54, 1.81])
        @test filter((x) -> x > 2, c0) == c0
        @test_throws ErrorException filter((x) -> x > 10, c0)

        # Interpolation
        @test interpolate(5.5, c1) ≈ (1.204-1.01)/(9-3)*(5.5-3)+1.01
        c_int = interpolate([3, 9, 14, 31, 33], c1)
        @test c_int isa Curve && length(c_int) == 5

        @test interpolate(25, clog) ≈ exp((log(1.81)-log(1.54))/(log(30)-log(18))*(log(25)-log(18))+log(1.54))
        c_log_int = interpolate([3, 9, 14, 31, 33], clog)
        @test c_log_int isa Curve && length(c_log_int) == 5 && c_log_int.logx==true && c_log_int.logy==true
        @test interpolate(5.5, clogy) ≈ exp((log(1.204)-log(1.01))/(9-3)*(5.5-3)+log(1.01))
        @test interpolate(c1, clog) isa Curve

        @test interpolate(10, c0) == 5.5

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
        @test_throws ErrorException apply(x -> 2x, c1, axis=:z)

        # test non-standard interpolators
        c_const = Curve(x1, y1, method=ItpConstant())
        @test interpolate(28, c_const) == 1.81

        # test extrapolations
        @test interpolate(1, c1) == 1.01 # constant extrapolation
        c_42 = Curve(x1, y1, extrapolation=42)
        @test interpolate(1042, c_42) == 42
        c_line = Curve(x1, y1, extrapolation=EtpLine())
        @test interpolate(102, c_line) > 0 # just smoke test
    end

    @testset "tenors" begin
        # generation of Tenor objects
        t = Tenor.(("1D", "3W", "1M", "10y"))
        @test t == (Tenor(Curves.TDays, 1), Tenor(Curves.TWeeks, 3), Tenor(Curves.TMonths, 1), Tenor(Curves.TYears, 10))
        @test get_days.(t) == (1, 21, 30, 3650)

        # transformations to avoid ambiguities
        @test Tenor("7d") == Tenor("1W") == Tenor(Curves.TWeeks, 1)
        @test Tenor("12M") == Tenor("1y") == Tenor(Curves.TYears, 1)
        @test Tenor("48m") == Tenor("4Y") == Tenor(Curves.TYears, 4)

        t1 = Tenor("1M")
        t2 = Tenor("2M")
        @test t1 < t2
        @test t1 > "1W"
        @test "6W" < t2
        @test "2M" == t2
        @test t1 == "1M"

        # construct Curve objects from tenors
        ct = Curve(["1D", "3W", "1M", "10y"], [0.5, 0.7, 0.75, 0.83])
        ct2 = Curve(collect(t), [0.5, 0.7, 0.75, 0.83])
        @test ct == ct2 == Curve([1, 21, 30, 3650], [0.5, 0.7, 0.75, 0.83])

        @test interpolate("1W", ct) ≈ (0.7 - 0.5)/(21 - 1)*(7 - 1) + 0.5
        @test interpolate(Tenor("12m"), ct) == interpolate("1Y", ct)

    end

    @testset "use-case" begin
        # Test use case in Readme
        # construct zero interest rate curve
        c_zero_base = Curve(["2D", "1w", "1M", "3M", "6M", "12M"], [0.5, 0.7, 0.75, 0.83, 1.1, 1.5])
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



end
