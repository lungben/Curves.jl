[![Build Status](https://travis-ci.com/lungben/Curves.jl.svg?branch=master)](https://travis-ci.com/lungben/Curves.jl)
[![codecov](https://codecov.io/gh/lungben/Curves.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/lungben/Curves.jl)

# Curves

## Introduction

A `Curve` in this package is essentially a collection of points `(x, y)`, together with an interpolation and extrapolation method.

`Curve` objects have a number of standard calculation function defined (like addition, multiplication, logarithm), thus they can be used in algebraic expressions analogue to scalars.

### How it Works

Operations on Curves alone (e.g. `exp(c)`, `log(c)`) or with scalars (e.g. `c+1` or `2c`) are defined point-wise on the y-values of the Curve.

Operations between 2 Curve objects (noted as `c1` and `c2`) are defined as follows:
1. Interpolate `c1` to the x-values of `c2`.
2. Do the operation (e.g. adding) on the y-values of `c2` and the interpolated y-values of c1.
3. Repeat steps 1. and 2., but interpolate `c2` to the x-values of `c1`.
4. Combine the results of both interpolations and create a new Curve object for the result.

Technically, this package is based on [Interpolations.jl](https://github.com/JuliaMath/Interpolations.jl).
Support of log-interpolation on both axis is added by this package.

`Curve` objects are defined to be immutable, thus every operation creates a new `Curve` object as output.

## Tenors

In financial use cases, the x-axis of curves is often given in maturity tenors, e.g. 1W or 3M.
The `Tenor` type is introduced to support such a notation for the x-axis of curves.

Example:

```julia
t = Tenor.(("1D", "3W", "1M", "10y", "12m"))
@assert t == (Tenor(Curves.TDays, 1), Tenor(Curves.TWeeks, 3), Tenor(Curves.TMonths, 1),
    Tenor(Curves.TYears, 10), Tenor(Curves.TYears, 1))
```
Note that the tenor `12M` is automatically converted to `1Y` to avoid ambiguities.

Tenors can be directly used in Curves:

```julia
curve_from_tenors = Curve(["1D", "3W", "1M", "10y"], [0.5, 0.7, 0.75, 0.83])
val = interpolate("1W", curve_from_tenors)
```

As a shortcut for creating tenor objects, a string macro is provided:

```julia
@assert t"1W" == Tenor("1W")
```

### Use Case

The use case I had in mind was interest rate / FX curves for mathematical finance applications.
The `Curve` objects make it easier to shift market data, e.g. for sensitivity or scenario P&L calculation, or to calculate such shift sizes based on market data time series.

Example:

```julia
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
@assert curve_scenario ≈ c_shifted_df
```

## Ideas for Further Improvements

* Support of more operations
* Interactions with [QuantLib.jl](https://github.com/pazzo83/QuantLib.jl) curve objects
* Multi-dimensional structures (especially 2d, e.g. for Volatility surfaces)
