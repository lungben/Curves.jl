
@enum TenorUnits TDays TWeeks TMonths TYears

"""
Structure for tenors, consisting of a multiplier and a unit (e.g. days, month, year)
"""
struct Tenor
    unit:: TenorUnits
    multiplier:: Int
end

const TenorUnitMapping = Dict("D" => TDays, "W" => TWeeks, "M" => TMonths, "Y"=> TYears)

"""
    Tenor(x:: AbstractString)

Constructor for creating a Tenor object from a string.
The input string must start with the multiplier as Integer followed by the
unit (as last character).

Example:

    julia> Tenor.(("1D", "3W", "1M", "10y"))
    (Tenor(TDays, 1), Tenor(TWeeks, 3), Tenor(TMonths, 1), Tenor(TYears, 10))

"""
function Tenor(x:: AbstractString)
    unit = TenorUnitMapping[uppercase(x[end:end])]
    multiplier = parse(Int, x[1:end-1])
    # remove ambiguities
    if unit == TDays && multiplier % 7 == 0
        unit = TWeeks
        multiplier = multiplier ÷ 7
    elseif unit == TMonths && multiplier % 12 == 0
        unit = TYears
        multiplier = multiplier ÷ 12
    end
    Tenor(unit, multiplier)
end

const TenorInDays = Dict(TDays => 1, TWeeks => 7, TMonths => 30, TYears => 365)

"""
    get_days(x:: Tenor):: Int

Gets the number of days corresponding to the Tenor object.
The days are calculated in a simplified way, assuming 30 days/ month and
365 days/ year.
"""
get_days(x:: Tenor):: Int = TenorInDays[x.unit]*x.multiplier

Base.Broadcast.broadcastable(q:: Tenor) = Ref(q) # treat it as a scalar in broadcasting
