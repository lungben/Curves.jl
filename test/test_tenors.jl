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
