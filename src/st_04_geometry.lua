----------------------------------- geometry -----------------------------------

-- manhattan distance between pos `a` and ori
manhat = function(a) return math.abs(a.x) + math.abs(a.y) + math.abs(a.z) end

_hackVector = function()
	local mt = getmetatable(vector.new(0,0,0))
	mt.__len = manhat -- use `#v` as `manhat(v)`, only available on lua5.2+
	mt.__eq = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end
	mt.__lt = function(a, b) return a.x < b.x and a.y < b.y and a.z < b.z end
	mt.__le = function(a, b) return a.x <= b.x and a.y <= b.y and a.z <= b.z end
	mt.__mod = function(a, b) return a:cross(b) end -- use `a % b` as `a:cross(b)`
	mt.__concat = function(a, b) return mkArea(a, b) end
	mt.__pow = function(a, b) return -a:cross(b):normalize() end -- use `a ^ b` to get rotate axis from `a` to `b` so that: forall a, b, a:cross(b) ~= 0 and a:dot(b) == 0  --->  (exists k, a * (a ^ b)) == b * k)
end

_hackVector()
vec = vector.new

leftSide = memoize(function(d) return d % const.rotate.left end) -- left side of a horizontal direction
rightSide = memoize(function(d) return d % const.rotate.right end) -- right side of a horizontal direction

lowPoint = function(p, q) return vec(math.min(p.x, q.x), math.min(p.y, q.y), math.min(p.z, q.z)) end
highPoint = function(p, q) return vec(math.max(p.x, q.x), math.max(p.y, q.y), math.max(p.z, q.z)) end

mkArea = (function()
	local _area_mt = {
		__add = function(a, b) return _mkArea(lowPoint(a.low, b.low), highPoint(a.high, b.high)) end,
	}
	local _mkArea = function(low, high) -- p is inside this area <==> low <= p and p < high
		local a = {
			low = low, high = high,
			volume = function(a) local v = a.high - a.low; return v.x * v.y * v.z end,
		}
		setmetatable(a, _area_mt)
		return a
	end
	return function(p, q) return _mkArea(lowPoint(p, q), highPoint(p, q) + const.positiveDir) end
end)()

