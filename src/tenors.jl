
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
# sorting of a Dict is not deterministic
const TenorSorting = sortperm(collect(keys(Curves.TenorInDays)), rev=true)
const Tenors = collect(keys(TenorInDays))[TenorSorting]
const TenorDays = collect(values(TenorInDays))[TenorSorting]

"""
    get_days(x:: Tenor):: Int

Gets the number of days corresponding to the Tenor object.
The days are calculated in a simplified way, assuming 30 days/ month and
365 days/ year.
"""
get_days(x:: Tenor):: Int = TenorInDays[x.unit]*x.multiplier

"""
    get_tenor(x:: Integer):: Tenor

Converts the given number of days to a Tenor.

The following mapping is used (exactly the reverse of `get_days`):
TDays => 1, TWeeks => 7, TMonths => 30, TYears => 365
"""
function get_tenor(x:: Integer):: Tenor
    x > 0 || error("number of days must be positive, obtained $x")
    for (i, unit_days) in enumerate(TenorDays)
        if x % unit_days == 0
            return Tenor(Tenors[i], x ÷ unit_days)
        end
    end
    error("could not convert days $x to tenor")
end

Base.Broadcast.broadcastable(q:: Tenor) = Ref(q) # treat it as a scalar in broadcasting

Base.isless(x:: Tenor, y:: Tenor) = isless(get_days(x), get_days(y))

Base.isless(x:: Tenor, y:: AbstractString) = isless(x, Tenor(y))
Base.isless(x:: Tenor, y:: Integer) = isless(get_days(x), y)
Base.isless(x:: AbstractString, y:: Tenor) = isless(Tenor(x), y)
Base.isless(x:: Integer, y:: Tenor) = isless(x, get_days(y))

import Base: ==
==(x:: Tenor, y:: Tenor) = x.unit == y.unit && x.multiplier == y.multiplier
==(x:: Tenor, y:: AbstractString) = ==(x, Tenor(y))
==(x:: Tenor, y:: Integer) = ==(get_days(x), y)
==(x, y:: Tenor) = ==(y, x)
