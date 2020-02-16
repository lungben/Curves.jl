module Curves

export Curve, interpolate, apply, concat, drop_duplicates

using Interpolations

# Basic definition
abstract type AbstractCurve end

struct Curve{Tx <: AbstractArray, Ty <: AbstractArray{<: Number},
        Titp <: Interpolations.AbstractInterpolation} <: AbstractCurve
    x:: Tx
    y:: Ty
    etp:: Titp
    logx:: Bool
    logy:: Bool
end

Curve(x, y; method=Gridded(Linear()), extrapolation=Flat(), logx=false, logy=false) =
    Curve(x, y, extrapolate(interpolate(logx ? (log.(x),) : (x,), logy ?  log.(y) : y, method),
        extrapolation), logx, logy)

getitpm(c1:: Curve) = c1.etp.itp.it
getetpm(c1:: Curve) = c1.etp.et
Base.Broadcast.broadcastable(q:: Curve) = Ref(q) # treat it as a scalar in broadcasting

# Interpolation
import Interpolations: interpolate

function interpolate(xval:: Real, c1:: Curve)
    c = c1.etp(c1.logx ? log(xval) : xval)
    c1.logy ? exp(c) : c
end

interpolate(xval:: AbstractArray{T} where T, c1:: Curve) =
    Curve(xval, interpolate.(xval, c1), method=getitpm(c1), logx=c1.logx, logy=c1.logy,
        extrapolation=getetpm(c1))

interpolate(c0:: Curve, c1:: Curve) = interpolate(c0.x, c1)

# Define Operations with Scalars

import Base: +, -, *, /, ^, exp, log, length

length(c1:: Curve):: Int = length(c1.y)

operations = (:+, :-, :*, :/, :^)
for op in operations
    @eval $op(c1:: Curve, a:: Number) = Curve(c1.x, $op.(c1.y, a),
        method=getitpm(c1), logx=c1.logx, logy=c1.logy, extrapolation=getetpm(c1))
    @eval $op(a:: Number, c1:: Curve) = Curve(c1.x, $op.(a, c1.y),
        method=getitpm(c1), logx=c1.logx, logy=c1.logy, extrapolation=getetpm(c1))
end

operations = (:exp, :log)
for op in operations
    @eval $op(c1:: Curve) = Curve(c1.x, $op.(c1.y), method=getitpm(c1),
        logx=c1.logx, logy=c1.logy, extrapolation=getetpm(c1))
end

# Concatination

@inline function uniquexy(x:: AbstractArray, y:: AbstractArray)
    @inbounds begin
        idx = unique(z -> x[z], 1:length(x))
        x[idx], y[idx]
    end
end

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
Removes duplicate x values from the curve.
Note that it is not checked if the corresponding y values are identical,
just an arbitrary one is kept.
"""
function drop_duplicates(c1:: Curve)
    x, y = uniquexy(c1.x, c1.y)
    Curve(x, y, method=getitpm(c1), logx=c1.logx, logy=c1.logy, extrapolation=getetpm(c1))
end

"""
Merges 2 curves.
Element type is inferred by promotion, interpolation type is taken from 1st curve argument.
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
    @eval function $op(c1:: Curve, c2:: Curve)
        if c1.x == c2.x # fast mode if no interpolation is required
            x = c1.x
            y = $op.(c1.y, c2.y)
        else
            y_c1_grid = $op.(c1.y, interpolate.(c1.x, c2))
            y_c2_grid = $op.(interpolate.(c2.x, c1), c2.y)
            x, y = mergexy(c1.x, y_c1_grid, c2.x, y_c2_grid)
            x, y = uniquexy(x, y)
        end
        Curve(x, y, logx=c1.logx, logy=c1.logy, method=getitpm(c1), extrapolation=getetpm(c1))
    end
end

# Applying Functions

"""
Applies a 2-argument function ˋf(x,y)ˋ to each entry of the Curve.
"""
function apply(f:: Function, c1:: Curve;
        logx=c1.logx, logy=c1.logy, method=getitpm(c1), extrapolation=getetpm(c1))
    y = f.(c1.x, c1.y)
    Curve(c1.x, y, logx=logx, logy=logy, method=method, extrapolation=extrapolation)
end

end # module
