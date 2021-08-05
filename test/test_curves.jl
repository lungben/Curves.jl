x1 = [3, 9, 18, 30, 91]
y1 = [1.01, 1.204, 1.54, 1.81, 2.12]
c1 = Curve(x1, y1)

x2 = [5, 12, 18, 30, 125, 291]
y2 = [1.01, 1.204, 1.54, 1.81, 2.12, 7.436]
clog = Curve(x2, y2, logx=true, logy=true)
clogy = Curve(x1, y1, logy=true)

c0 = Curve([3], [5.5]) # curve with single point

# equality
c2 = Curve(c1)
c3 = Curve(c1, logx=true)
@test c1 == c2
@test c1 ≈ c2
@test !(c1 == c3)
@test !(c1 ≈ c3)
@test !(c0 == c1)
@test c0 == Curve(3, 5.5)
@test Curve(Tenor("3D"), 7.8) == Curve([3], [7.8])

@test Curve(reverse(x1), reverse(y1)) == c1

# first / last
@test firstpoint(c1, dims=1) == 3
@test firstpoint(c1, dims=2) == 1.01
@test lastpoint(c1, dims=1) == 91
@test lastpoint(c1, dims=2) == 2.12
@test_throws ErrorException firstpoint(c1, dims=3)
@test_throws ErrorException lastpoint(c1, dims=0)
@test firstpoint(c0) == lastpoint(c0) == 3

@test first(c1, 3) == Curve([3, 9, 18], [1.01, 1.204, 1.54])
@test last(c1, 4) == Curve([9, 18, 30, 91], [1.204, 1.54, 1.81, 2.12])
@test first(c1, 10) == c1
@test last(c1, 100) == c1
@test_throws ErrorException first(c1, 0)
@test_throws ErrorException last(c1, -1)
@test first(c0, 10) == last(c0, 10) == c0

@test filter((x) -> x > 10, c1) == Curve([18, 30, 91], [1.54, 1.81, 2.12])
@test filter((x) -> x < 2, c1, axis=:y) == Curve([3, 9, 18, 30], [1.01, 1.204, 1.54, 1.81])
@test filter((x) -> x > 2, c0) == c0
@test_throws ErrorException filter((x) -> x > 10, c0)

# Interpolation
@test interpolate(5.5, c1) ≈ (1.204-1.01)/(9-3)*(5.5-3)+1.01
c_int = interpolate([3, 9, 14, 31, 33], c1)
@test c_int isa Curve && length(c_int) == 5

@test interpolate(25, clog) ≈ exp((log(1.81)-log(1.54))/(log(30)-log(18))*(log(25)-log(18))+log(1.54))
c_log_int = interpolate([3, 9, 14, 31, 33], clog)
@test c_log_int isa Curve && length(c_log_int) == 5
@test interpolate(5.5, clogy) ≈ exp((log(1.204)-log(1.01))/(9-3)*(5.5-3)+log(1.01))
@test interpolate(c1, clog) isa Curve

@test interpolate(10, c0) == 5.5

# Operations with Scalars
@test (c1 + 2).y == y1 .+ 2 && (c1 + 2).x == x1
@test (1/c1).y == 1 ./ y1 && (1/c1).x == x1
c_add = +(c1, 2, logy=true)
@test c_add.y == y1 .+ 2 && c_add.logy == true
# test if interpolation object gets correctly updated
@test interpolate(5.5, 2c1) ≈ 2((1.204-1.01)/(9-3)*(5.5-3)+1.01)
@test exp(c1).y == exp.(c1.y)
@test sin(c1)/cos(c1) ≈ tan(c1)

# Merges
c1d = Curve([1, 3, 3, 7, 9], [2, 4, 4, 8, 10])
@test c1d.x == [1, 3, 7, 9]
@test c1d.y ==  [2, 4, 8, 10]
@test concat(c1, c1d).x == [1, 3, 7, 9, 18, 30, 91]
@test concat(Curve(5.5, 42.1), c1) == Curve([3, 5.5, 9, 18, 30, 91], [1.01, 42.1, 1.204, 1.54, 1.81, 2.12])

# Operations on Curves
c_sum = c1+c1d
@test c_sum.x == sort(unique(vcat(c1.x, c1d.x)))

sumc1 = c1+c1
@test sumc1.y == (2*c1).y # tests correctness of result
@test sumc1 == 2c1 # tests comparison operator in addition
@test log(clogy/c1d).logx == false

@test ismissing(missing*c1)
@test ismissing(c2/missing)

# apply
@test apply((t,r) -> exp(-r/100*t), c1, logy=true).logy == true
@test apply(x -> 2x, c1, axis=:y) ≈ 2c1
res = apply(x -> 3x, c1, axis=:x)
@test res.x == 3c1.x && res.y == c1.y
res = apply((x, y) -> 2x+y, c1, axis=:xy)
@test res.x == c1.x && res.y == c1.y .+ 2.0 .* c1.x
@test_throws ErrorException apply(x -> 2x, c1, axis=:z)

# test non-standard interpolators
c_const = Curve(x1, y1, method=ItpConstant())
@test interpolate(28, c_const) == 1.81

# test extrapolations
@test interpolate(1, c1) == 1.01 # constant extrapolation
c_42 = Curve(x1, y1, extrapolation=42)
@test interpolate(1042, c_42) == 42
c_line = Curve(x1, y1, extrapolation=EtpLine())
@test interpolate(102, c_line) > 0 # just smoke test

# test pretty printing
io = IOBuffer(append=true)
print(io, Curve([t"2D", t"1W", t"3M", t"6M", t"12M"], [0.8, 0.9, 1.1, 1.15, 1.2], logy=true))
@test read(io, String) == "x = [2, 7, 90, 180, 365], y = [0.8, 0.9, 1.1, 1.15, 1.2], logx = false, logy = true"
