module Curves

export Curve, interpolate, apply, concat, drop_duplicates

using Interpolations

#=
The Curve object is intended to be immutable, i.e. each operation on it creates a new Curve instance.
In principle it would be possible to change points of the arrays curve.x or curve.y without creating a new Curve instance,
but this should be avoided because it may introduce inconsistencies (especially when using log-interpolation).
In order to have both extrapolation and interpolation, a nested extrapolation(interpolation) object (using Interpolations.jl)
is created.
The x and y arrays are passed to the Interpolations.jl interpolator directly if log-interpolation is switched off. In this
case, the interpolation object contains a pointer to the same array, thus there are no duplicates of the x and y arrays
in memory. The arrays x and y are mainly kept directly in the Curve struct (and not only inside the interpolation object)
to avoid problems with type inference.
However, if log interpolation is activated for one axis, a second array is created for the axis containing
the log values of the original array and stored in the interpolation object. This results in double memory usage, but 
allows quick access to both the axis values (via curve.x and curve.y) and interpolated values.
Note that Interpolation.jl does not support log-interpolation (yet?), therefore it needs to be implemented here explicitly.
=#

# Basic definition
abstract type AbstractCurve end

struct Curve{Tx <: AbstractArray, Ty <: AbstractArray,
        Titp <: Interpolations.AbstractInterpolation} <: AbstractCurve
    "data points x-axis"
    x:: Tx
    "data points y-axis"
    y:: Ty
    "Interpolations.jl extrapolation(interpolation) object"
    etp:: Titp
    "is x-axis logarithmic?"
    logx:: Bool
    "is y-axis logarithmic?"
    logy:: Bool
end

"""
    Curve(x, y; method=Gridded(Linear()), extrapolation=Flat(), logx=false, logy=false)

Standard curve constructor.
Creates the interpolation/extrapolation object of the curve instance. 
Interpolation/extrapolation details can be changed using the keyword arguments, defaults are:

* linear interpolation
* constant extrapolation
* no logarithmic axes

Note that for method ˋGridded(x)ˋ must be used so that the x-grid can be non-uniform.

Valid choices for ˋmethodˋ are:

* ˋGridded(Linear())ˋ - default
* ˋGridded(Constant())ˋ
* ˋNoInterp()ˋ

Valid choices for ˋextrapolationˋ are:

* ˋThrow()ˋ
* ˋFlat()ˋ - default
* ˋLine()ˋ
* a constant value, which is used for filling-

"""
Curve(x, y; method=Gridded(Linear()), extrapolation=Flat(), logx=false, logy=false) =
    Curve(x, y, extrapolate(interpolate(logx ? (log.(x),) : (x,), logy ?  log.(y) : y, method), extrapolation), logx, logy)

"helper function to get Interpolations.jl interpolation method"
getitpm(c1:: Curve) = c1.etp.itp.it

"helper function to get Interpolations.jl extrapolation method"
getetpm(c1:: Curve) = c1.etp.et

"""
    Curve(c1:: Curve; method=getitpm(c1), extrapolation=getetpm(c1), logx=c1.logx, logy=c1.logy)

Copy constructor to generate a new curve from an existing one.
The interpolation / extrapolation parameters can be changed.
"""
Curve(c1:: Curve; method=getitpm(c1), extrapolation=getetpm(c1), logx=c1.logx, logy=c1.logy) =
    Curve(c1.x, c1.y, method=method, extrapolation=extrapolation, logx=logx, logy=logy)

Base.Broadcast.broadcastable(q:: Curve) = Ref(q) # treat it as a scalar in broadcasting

# Interpolation
import Interpolations: interpolate

"""
    interpolate(xval:: Real, c1:: Curve)

Returns the interpolated or extrapolated y-value of the curve for a given x-value.
"""
function interpolate(xval:: Real, c1:: Curve)
    c = c1.etp(c1.logx ? log(xval) : xval)
    c1.logy ? exp(c) : c
end

"""
    interpolate(xval:: AbstractArray{T} where T, c1:: Curve):: Curve

Interpolates the curve onto the given array and returns a new Curve instance on the interpolated points.

The resulting curve instance uses the same interpolation and extrapolation settings as the original one.
"""
interpolate(xval:: AbstractArray{T} where T, c1:: Curve):: Curve =
    Curve(xval, interpolate.(xval, c1), method=getitpm(c1), logx=c1.logx, logy=c1.logy,
        extrapolation=getetpm(c1))

"""
    interpolate(c0:: Curve, c1:: Curve):: Curve

Interpolates the Curve ˋc1ˋ on the x-axis points of the Curve ˋc0ˋ and returns a new Curve instance on the interpolated 
points.

The resulting curve instance uses the same interpolation and extrapolation settings as ˋc1ˋ.
"""
interpolate(c0:: Curve, c1:: Curve):: Curve = interpolate(c0.x, c1)

# Basic operations

import Base: +, -, *, /, ^, exp, log, length, ==, ≈

length(c1:: Curve):: Int = length(c1.y)

# comparisons
==(c1:: Curve, c2:: Curve) = c1.x == c2.x && c1.y == c2.y && c1.etp == c2.etp &&
    c1.logx == c2.logx && c1.logy == c2.logy

≈(c1:: Curve, c2:: Curve) = c1.x ≈ c2.x && c1.y ≈ c2.y && c1.etp ≈ c2.etp &&
    c1.logx == c2.logx && c1.logy == c2.logy

#=
For all calculations on curves, the curve settings (interpolator, extrapolator, log axis settings) are taken as default
unless specified otherwise (they are not copied from input curves). This is to avoid issues e.g. with log-scales
on potentially negative values.
=#

# Define operations with scalars
operations = (:+, :-, :*, :/, :^)
for op in operations
    @eval $op(c1:: Curve, a:: Number; kwargs...) = Curve(c1.x, $op.(c1.y, a); kwargs...)
    @eval $op(a:: Number, c1:: Curve; kwargs...) = Curve(c1.x, $op.(a, c1.y); kwargs...)
end

# Define operations where Curve is the only argument
operations = (:exp, :log, :sin, :cos, :tan)
for op in operations
    @eval $op(c1:: Curve; kwargs...) = Curve(c1.x, $op.(c1.y); kwargs...)
end

# Helper functions for concatination

"""
Removes duplicates in the array x and the entries in the array y which have the same index as the x-duplicates.

Note that it does not check if the y-values for x-value duplicates are the same!
"""
@inline function uniquexy(x:: AbstractArray, y:: AbstractArray)
    @inbounds begin
        idx = unique(z -> x[z], 1:length(x))
        x[idx], y[idx]
    end
end

"""
Merges two pairs of arrays x, y into a combined and sorted (along x-values) array pair.
"""
@inline function mergexy(x1:: AbstractArray, y1:: AbstractArray,
        x2:: AbstractArray, y2:: AbstractArray)
    @inbounds begin
        x_all = vcat(x1, x2)
        y_all = vcat(y1, y2)
        perm = sortperm(x_all)
        x_all[perm], y_all[perm]
    end
end

"""
    drop_duplicates(c1:: Curve)

Removes duplicate x values from the curve.

Note that it is not checked if the corresponding y values are identical, just an arbitrary one is kept.
"""
function drop_duplicates(c1:: Curve)
    x, y = uniquexy(c1.x, c1.y)
    Curve(x, y, method=getitpm(c1), logx=c1.logx, logy=c1.logy, extrapolation=getetpm(c1))
end

"""
    concat(c1:: Curve, c2:: Curve; drop_dup=true)

Merges two curves.

Element type is inferred by promotion, interpolation type is taken from 1st curve argument.
Dulicate points are dropped by default, unless ˋdrop_dup=falseˋ is set.
"""
function concat(c1:: Curve, c2:: Curve; drop_dup=true)
    x_all, y_all = mergexy(c1.x, c1.y, c2.x, c2.y)
    if drop_dup
        x_all, y_all = uniquexy(x_all, y_all)
    end
    Curve(x_all, y_all, method=getitpm(c1), logx=c1.logx, logy=c1.logy,
        extrapolation=getetpm(c1))
end

# Operations with Multiple Curves

operations = (:+, :-, :*, :/, :^)
for op in operations
    @eval function $op(c1:: Curve, c2:: Curve; kwargs...)
        if c1.x == c2.x # fast mode if no interpolation is required
            x = c1.x
            y = $op.(c1.y, c2.y)
        else
            y_c1_grid = $op.(c1.y, interpolate.(c1.x, c2))
            y_c2_grid = $op.(interpolate.(c2.x, c1), c2.y)
            x, y = mergexy(c1.x, y_c1_grid, c2.x, y_c2_grid)
            x, y = uniquexy(x, y)
        end
        Curve(x, y; kwargs...)
    end
end

# Applying Functions

"""
    apply(f:: Function, c1:: Curve; axis:: Symbol = :xy, kwargs...)

If ˋaxisˋ is ˋ:xyˋ (default): applies a 2-argument function ˋf(x,y)=zˋ to each entry of the Curve.

If ˋaxisˋ is ˋ:xˋ or ˋ:yˋ: applies a 1-argument function ˋf(x)=zˋ to a single axis of the Curve.

Thw output Curve is constructed using default settings, alternative settings can be passed to the Curve constructor
using the ˋkwargs...ˋ
"""
function apply(f:: Function, c1:: Curve; axis:: Symbol = :xy, kwargs...)
    if axis==:xy
        x = c1.x
        y = f.(c1.x, c1.y)
    elseif axis==:x
        x = f.(c1.x)
        y = c1.y
    elseif axis==:y
        x = c1.x
        y = f.(c1.y)
    else
        error("axis must be :xy, :x or :y, the value $axis is not allowed")
    end
    Curve(x, y; kwargs...)
end

end # module
