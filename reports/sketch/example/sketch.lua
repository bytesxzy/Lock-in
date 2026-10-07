-- sketch.lua | rev 32 | sha256 078358d1652173e896d9f21677bd0db806a365f2dbd74e109f06275e8c8b6bd5 | chain 1e8e84037e05eb17 | calls 220 | cost 67644
-- double: synthesized from 4 examples (size 3, 19 candidates tried)
function double(x)
  return (x + x)
end
-- square: synthesized from 4 examples (size 3, 119 candidates tried)
function square(x)
  return (x * x)
end
-- triangular: synthesized from 4 examples (size 7, 83667 candidates tried)
function triangular(n)
  return ((n + (n * n)) // 2)
end
-- factorial: synthesized from 5 examples (size 3, 120907 candidates tried)
local function prod(xs) local s = 1 for i = 1, #xs do s = s * xs[i] end return s end
local function range(n) local r = {} for i = 1, n do r[i] = i end return r end
function factorial(n)
  return prod(range(n))
end
-- is_even: synthesized from 5 examples (size 5, 8739 candidates tried)
function is_even(x)
  return ((x % 2) < 1)
end
-- abs_diff: synthesized from 4 examples (size 4, 1841 candidates tried)
function abs_diff(a, b)
  return math.abs((a - b))
end
-- clamp: synthesized from 5 examples (size 5, 20803 candidates tried)
function clamp(x, lo, hi)
  return math.min(hi, math.max(x, lo))
end
-- list_sum: synthesized from 4 examples (size 2, 18 candidates tried)
local function sum(xs) local s = 0 for i = 1, #xs do s = s + xs[i] end return s end
function list_sum(xs)
  return sum(xs)
end
-- list_max: synthesized from 4 examples (size 2, 20 candidates tried)
local function maxl(xs) local m = xs[1] for i = 2, #xs do if xs[i] > m then m = xs[i] end end return m end
function list_max(xs)
  return maxl(xs)
end
-- sum_squares: synthesized from 4 examples (size 4, 125972 candidates tried)
local function map(f, xs) local r = {} for i = 1, #xs do r[i] = f(xs[i]) end return r end
function sum_squares(xs)
  return sum(map(function(v) return (v * v) end, xs))
end
-- count_even: synthesized from 10 examples (size 3, 122840 candidates tried)
local function countby(f, xs) local c = 0 for i = 1, #xs do if f(xs[i]) then c = c + 1 end end return c end
function count_even(xs)
  return countby(function(v) return ((v % 2) < 1) end, xs)
end
-- sum_even: synthesized from 5 examples (size 4, 126948 candidates tried)
local function filter(f, xs) local r = {} for i = 1, #xs do if f(xs[i]) then r[#r + 1] = xs[i] end end return r end
function sum_even(xs)
  return sum(filter(function(v) return ((v % 2) < 1) end, xs))
end
-- evens: synthesized from 5 examples (size 3, 122645 candidates tried)
function evens(xs)
  return filter(function(v) return ((v % 2) < 1) end, xs)
end
-- squares: synthesized from 4 examples (size 3, 120694 candidates tried)
function squares(xs)
  return map(function(v) return (v * v) end, xs)
end
-- any_neg: synthesized from 8 examples (size 6, 35186 candidates tried)
local function minl(xs) local m = xs[1] for i = 2, #xs do if xs[i] < m then m = xs[i] end end return m end
local function append(xs, v) local r = {} for i = 1, #xs do r[i] = xs[i] end r[#r + 1] = v return r end
function any_neg(xs)
  return (minl(append(xs, 0)) < 0)
end
-- span: synthesized from 4 examples (size 5, 3221 candidates tried)
function span(xs)
  return (maxl(xs) - minl(xs))
end
-- mean_floor: synthesized from 5 examples (size 5, 4559 candidates tried)
function mean_floor(xs)
  return (sum(xs) // (#xs))
end
-- contains: synthesized from 5 examples (size 3, 666 candidates tried)
local function has(xs, v) for i = 1, #xs do if xs[i] == v then return true end end return false end
function contains(xs, x)
  return has(xs, x)
end
-- count_of: synthesized from 5 examples (size 3, 658 candidates tried)
local function countv(xs, v) local c = 0 for i = 1, #xs do if xs[i] == v then c = c + 1 end end return c end
function count_of(xs, x)
  return countv(xs, x)
end
-- str_upper: synthesized from 4 examples (size 2, 23 candidates tried)
function str_upper(s)
  return (s):upper()
end
-- palindrome: synthesized from 5 examples (size 4, 2236 candidates tried)
function palindrome(s)
  return (s == (s):reverse())
end
-- join_comma: synthesized from 4 examples (size 5, 6266 candidates tried)
function join_comma(a, b)
  return (a .. ("," .. b))
end
-- shout: synthesized from 4 examples (size 4, 1653 candidates tried)
function shout(s)
  return ((s .. "!")):upper()
end
-- count_a: synthesized from 5 examples (size 3, 609 candidates tried)
local function scount(s, c) local n = 0 for i = 1, #s do if s:sub(i, i) == c then n = n + 1 end end return n end
function count_a(s)
  return scount(s, "a")
end
function clamp_s(x, lo, hi)
  local y = (math.max(x, lo))
  return (math.min(y, hi))
end
function diff_sq(a, b)
  return ((a + b)) * ((a - b))
end
function max3_s(a, b, c)
  local m = (math.max(a, b))
  return (math.max(m, c))
end
