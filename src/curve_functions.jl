# Interpolation
import Interpolations: interpolate

"""
    interpolate(xval:: Real, c1:: Curve)

Returns the interpolated or extrapolated y-value of the curve for a given x-value.
"""
function interpolate(xval:: Real, c1:: Curve)
    if isnothing(c1.etp)
        return c1.y[begin]
    else
        c = c1.etp(c1.logx ? log(xval) : xval)
        return c1.logy ? exp(c) : c
    end
end

interpolate(xval:: Tenor, c1:: Curve) = interpolate(get_days(xval), c1)

interpolate(xval:: AbstractString, c1:: Curve) = interpolate(Tenor(xval), c1)

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

import Base: +, -, *, /, ^, exp, log, sin, cos, tan, length, ==, ≈

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

# first and last point functions

"""
    firstpoint(c1:: Curve; dims=1):: Real

Returns the first point of the X-axis (if `dims=1`) or the Y-axis (if `dims=2`).
"""
function firstpoint(c1:: Curve; dims=1):: Real
    if dims == 1
        return c1.x[begin]
    elseif dims == 2
        return c1.y[begin]
    else
        error("invalid dimension for Curve objects, only 1 and 2 supported")
    end
end

"""
    lastpoint(c1:: Curve; dims=1):: Real

Returns the last point of the X-axis (if `dims=1`) or the Y-axis (if `dims=2`).
"""
function lastpoint(c1:: Curve; dims=1):: Real
    if dims == 1
        return c1.x[end]
    elseif dims == 2
        return c1.y[end]
    else
        error("invalid dimension for Curve objects, only 1 and 2 supported")
    end
end

import Base: first, last, filter

"""
    first(c1:: Curve, n:: Integer)

Returns a new curve containing the first n points of the previous curve.
`n` must be at least 1.
"""
function first(c1:: Curve, n:: Integer)
    n < 1 && error("`n` must be at least 1 for definition of a curve")
    n = min(n, length(c1))
    Curve(c1.x[begin:n], c1.y[begin:n], method=getitpm(c1), logx=c1.logx, logy=c1.logy, extrapolation=getetpm(c1))
end

"""
    last(c1:: Curve, n:: Integer)

Returns a new curve containing the last n points of the previous curve.
`n` must be at least 1.
"""
function last(c1:: Curve, n:: Integer)
    n < 1 && error("`n` must be at least 2 for definition of a curve")
    n = min(n, length(c1))
    Curve(c1.x[end-n+1:end], c1.y[end-n+1:end], method=getitpm(c1), logx=c1.logx, logy=c1.logy, extrapolation=getetpm(c1))
end

"""
    filter(f:: Function, c1::Curve; axis:: Symbol = :x)


"""
function filter(f:: Function, c1::Curve; axis:: Symbol = :x)
    if axis==:x
        mask = f.(c1.x)
    elseif axis==:y
        mask = f.(c1.y)
    else
        error("axis must be :x or :y, the value $axis is not allowed")
    end
    count(mask) < 1 && error("less than 1 point remaining")
    Curve(c1.x[mask], c1.y[mask], method=getitpm(c1), logx=c1.logx, logy=c1.logy, extrapolation=getetpm(c1))
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
