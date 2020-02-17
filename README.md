[![Build Status](https://travis-ci.com/lungben/Curves.jl.svg?branch=master)](https://travis-ci.com/lungben/Curves.jl)

# Curves

Note that this is work in progress and not suited for any serious usage yet!

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

Linear, Quadratic and Cubic Spline interpolation is supported by [Interpolations.jl](https://github.com/JuliaMath/Interpolations.jl). Support of log-interpolation on both axis is added by this package.

`Curve` objects are defined to be immutable, thus every operation creates a new `Curve` object as output.

### Use Case

The use case I had in mind was interest rate / FX curves for mathematical finance applications.
The `Curve` objects make it easier to shift market data, e.g. for sensitivity or scenario P&L calculation, or to calculate such shift sizes based on market data time series.

## Usage

tbd

## Plans for Further Improvements

* Proper tests and documentation
* Support of more operations
* Interactions with [QuantLib.jl](https://github.com/pazzo83/QuantLib.jl) curve objects
* Multi-dimensional structures (especially 2d, e.g. for Volatility surfaces)
