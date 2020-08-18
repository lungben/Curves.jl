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
@test t1 > 28
@test 32 > t1
@test t1 == 30
@test !(31 == t1)
@test "6W" < t2
@test "2M" == t2
@test t1 == "1M"

# construct Curve objects from tenors
ct = Curve(["1D", "3W", "1M", "10y"], [0.5, 0.7, 0.75, 0.83])
ct2 = Curve(collect(t), [0.5, 0.7, 0.75, 0.83])
@test ct == ct2 == Curve([1, 21, 30, 3650], [0.5, 0.7, 0.75, 0.83])

@test interpolate("1W", ct) ≈ (0.7 - 0.5)/(21 - 1)*(7 - 1) + 0.5
@test interpolate(Tenor("12m"), ct) == interpolate("1Y", ct)

@test get_tenor(12) == Tenor("12D")
@test get_tenor(21) == Tenor("3W")
@test get_tenor(60) == Tenor("2M")
@test get_tenor(365) == Tenor("1y")
@test_throws ErrorException get_tenor(-1)

@test t"1W" == Tenor(Curves.TWeeks, 1)
@test_logs (:error,"X is not a valid tenor multiplier (occurred in tenor 1X)") @test_throws KeyError t"1X"

ct3 = Curve(["1D", "3W", "1M", "10y"], [0.5, 0.7, 0.75, 0.83], offset=2)
ct4 = Curve(collect(t), [0.5, 0.7, 0.75, 0.83], offset=2)
@test ct3 == ct4 == Curve([1+2, 21+2, 30+2, 3650+2], [0.5, 0.7, 0.75, 0.83])

# test pretty printing
io = IOBuffer(append=true)
print(io, t"1W")
@test read(io, String) == "1W"
