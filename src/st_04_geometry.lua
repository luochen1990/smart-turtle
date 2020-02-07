----------------------------------- geometry -----------------------------------

-- manhattan distance between pos `a` and ori
manhat = function(a) return math.abs(a.x) + math.abs(a.y) + math.abs(a.z) end

_hackVector = function()
	local mt = getmetatable(vector.new(0,0,0))
	mt.__tostring = function(a) return "<"..a.x..", "..a.y..", "..a.z..">" end
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

gpsLocate = function()
	local x, y, z = gps.locate()
	--if x then return vec(x, y, z) else return nil end
	return x and vec(x, y, z)
end

gpsPos = function()
	local x, y, z = gps.locate()
	--if x then return vec(math.floor(x), math.floor(y), math.floor(z)) else return nil end
	return x and vec(math.floor(x), math.floor(y), math.floor(z))
end

leftSide = memoize(function(d)
	assert(d and d.x, "[leftSide(d)] d should be a vector")
	return d % const.rotate.left
end) -- left side of a horizontal direction

rightSide = memoize(function(d)
	assert(d and d.x, "[rightSide(d)] d should be a vector")
	return d % const.rotate.right
end) -- right side of a horizontal direction

lowPoint = function(p, q)
	assert(p and p.x and q and q.x, "[lowPoint(p, q)] p and q should be vector")
	return vec(math.min(p.x, q.x), math.min(p.y, q.y), math.min(p.z, q.z))
end

highPoint = function(p, q)
	assert(p and p.x and q and q.x, "[highPoint(p, q)] p and q should be vector")
	return vec(math.max(p.x, q.x), math.max(p.y, q.y), math.max(p.z, q.z))
end

mkArea = (function()
	local _area_mt = {
		__add = function(a, b) return _mkArea(lowPoint(a.low, b.low), highPoint(a.high, b.high)) end,
		__tostring = function(a) return tostring(a.low).." .. "..tostring(a.high) end,
	}
	local _mkArea = function(low, high) -- including
		local a = {
			low = low, high = high, diag = high - low,
			volume = function(a) return (a.diag.x + 1) * (a.diag.y + 1) * (a.diag.z + 1) end,
			contains = function(a, p) return p >= a.low and p <= a.high end,
			vertexes = function(a) return {
				a.low, a.low + E * E:dot(a.diag), a.low + S * S:dot(a.diag), a.low + U * U:dot(a.diag),
				a.high + D * D:dot(a.diag), a.high + N * N:dot(a.diag), a.high + W * W:dot(a.diag), a.high,
			} end,
		}
		setmetatable(a, _area_mt)
		return a
	end
	return function(p, q)
		assert(p and p.x and q and q.x, "[mkArea(p, q)] p and q should be vector")
		return _mkArea(lowPoint(p, q), highPoint(p, q))
	end
end)()

