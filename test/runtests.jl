using Curves
using Test

@testset "Curves.jl" begin
    @testset "Curves" begin
        include("test_curves.jl")
    end

    @testset "tenors" begin
        include("test_tenors.jl")
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
