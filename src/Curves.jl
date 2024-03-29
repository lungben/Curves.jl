module Curves

export Curve, interpolate, apply, concat, drop_duplicates, firstpoint, lastpoint
export ItpLinear, ItpConstant, EtpFlat, EtpLine # type constants referring to Interpolations.jl

export Tenor, get_days, get_tenor, @t_str

using Interpolations
using RecipesBase

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

include("tenors.jl")

# Type constants referring to Interpolations.jl

const ItpLinear = Gridded ∘ Linear
const ItpConstant = Gridded ∘ Constant

const EtpFlat = Flat
const EtpLine = Line

# Basic definition
abstract type AbstractCurve end

struct Curve{Tx <: AbstractVector, Ty <: AbstractVector,
        Titp <: Union{Interpolations.AbstractInterpolation, Nothing}} <: AbstractCurve
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
    Curve(x:: AbstractVector, y:: AbstractVector; method=ItpLinear(), extrapolation=EtpFlat(), logx=false, logy=false, sort=true)

Standard curve constructor.
Creates the interpolation/extrapolation object of the curve instance.
The points `x` and `y` do not need to be sorted, this is done in the Curve constructor.

Interpolation/extrapolation details can be changed using the keyword arguments, defaults are:

* linear interpolation
* constant extrapolation
* no logarithmic axes

Note that for method ˋGridded(x)ˋ must be used so that the x-grid can be non-uniform.

Valid choices for ˋmethodˋ are:

* ˋItpLinear()ˋ, corresponds to Interpolation.jl ˋGridded(Linear())ˋ - default
* ˋItpConstant()ˋ, corresponds to Interpolation.jl ˋGridded(Constant())ˋ

Valid choices for ˋextrapolationˋ are:

* ˋEtpFlat()ˋ, corresponds to Interpolation.jl ˋFlat()ˋ - default
* ˋEtpLine()ˋ, corresponds to Interpolation.jl ˋLine()ˋ

If the curve consists only of a single point, always constant extrapolation is used.

* `sort=true`: per default, the input points are sorted and duplicate x-values are removed. `sort=true` is unsafe and intended to be used for Curves.jl internal operations only, where it can be guaranteed that the points are sorted and not duplicate.

"""
function Curve(x:: AbstractVector, y:: AbstractVector;
        method=ItpLinear(), extrapolation=EtpFlat(), logx=false, logy=false, sort=true)
    length(x) == length(y) || error("length of x and y arrays must match")
    if length(x) == 1
        return Curve(x, y, nothing, logx, logy)
    else
        if sort
            x, y = uniquexy(x, y)
            perm = sortperm(x)
            x = x[perm]
            y = y[perm]
        end
        return Curve(x, y, extrapolate(interpolate(logx ? (log.(x),) : (x,), logy ?  log.(y) : y, method), extrapolation), logx, logy)
    end
end

Base.show(io:: IO, c:: Curve) = print(io, "x = $(c.x), y = $(c.y), logx = $(c.logx), logy = $(c.logy)")

"helper function to get Interpolations.jl interpolation method"
getitpm(c1:: Curve) = isnothing(c1.etp) ? nothing : c1.etp.itp.it

"helper function to get Interpolations.jl extrapolation method"
getetpm(c1:: Curve) = isnothing(c1.etp) ? nothing : c1.etp.et

"""
    Curve(c1:: Curve; method=getitpm(c1), extrapolation=getetpm(c1), logx=c1.logx, logy=c1.logy, sort=true)

Copy constructor to generate a new curve from an existing one.
The interpolation / extrapolation parameters can be changed.
"""
Curve(c1:: Curve; method=getitpm(c1), extrapolation=getetpm(c1), logx=c1.logx, logy=c1.logy, sort=true) =
    Curve(c1.x, c1.y, method=method, extrapolation=extrapolation, logx=logx, logy=logy, sort=sort)

"""
    Curve(x:: AbstractVector{<: AbstractString}, y; kwargs...)

Construct Curve objects from an array of tenor strings as x-axis.
"""
Curve(x:: AbstractVector{<: AbstractString}, y:: AbstractVector; kwargs...) = Curve(Tenor.(x), y; kwargs...)

"""
    Curve(x:: AbstractVector{Tenor}, y:: AbstractVector; offset:: Real = 0, kwargs...)

Construct Curve objects from an array of Tenor objects strings as x-axis.

With the `offset` keyword argument the points on the x-axis, defined by the given tenors, can be shifted.
This could be e.g. used to take a spot lag of financial instruments into account.
Note that the shift is always in calendar days, a spot lag given in business days must be converted to calendar days beforehand.
"""
Curve(x:: AbstractVector{Tenor}, y:: AbstractVector; offset:: Real = 0, kwargs...) = Curve(get_days.(x) .+ offset, y; kwargs...)

Curve(x:: Real, y:: Real; kwargs...) = Curve([x], [y]; kwargs...)
Curve(x:: Tenor, y:: Real; kwargs...) = Curve([get_days(x)], [y]; kwargs...)

Base.Broadcast.broadcastable(q:: Curve) = Ref(q) # treat it as a scalar in broadcasting

@recipe plot(c::Curve) = c.x, c.y

include("curve_functions.jl")

end # module
