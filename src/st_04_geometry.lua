----------------------------------- geometry -----------------------------------

-- manhattan distance between pos `a` and ori
manhat = function(a) return math.abs(a.x) + math.abs(a.y) + math.abs(a.z) end

_hackVector = function()
	local mt = getmetatable(vector.new(0,0,0))
	mt.__tostring = function(a) return "<"..a.x..","..a.y..","..a.z..">" end
	mt.__len = manhat -- use `#v` as `manhat(v)`, only available on lua5.2+
	mt.__eq = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end
	mt.__lt = function(a, b) return a.x < b.x and a.y < b.y and a.z < b.z end
	mt.__le = function(a, b) return a.x <= b.x and a.y <= b.y and a.z <= b.z end
	mt.__mod = function(a, b) return a:cross(b) end -- use `a % b` as `a:cross(b)`
	mt.__concat = function(a, b) return mkArea(a, b) end
	mt.__pow = function(a, b) error("`v1 ^ v2` not implemented yet!") end
end

_hackVector()
vec = vector.new

gpsLocate = function(timeoutSeconds)
	local x, y, z = gps.locate(timeoutSeconds)
	if x then return vec(x, y, z) else return timeoutSeconds == nil and gpsLocate() end
end

gpsPos = function(timeoutSeconds)
	local x, y, z = gps.locate(timeoutSeconds)
	if x then return vec(math.floor(x), math.floor(y), math.floor(z))
	else return timeoutSeconds == nil and gpsPos() end
end

-- left side of a horizontal direction
leftSide = function(d)
	assert(d and d.y == 0, "[leftSide(d)] d should be a horizontal direction")
	return d % const.rotate.left
end

-- right side of a horizontal direction
rightSide = function(d)
	assert(d and d.y == 0, "[rightSide(d)] d should be a horizontal direction")
	return d % const.rotate.right
end

lateralSide = function(d) -- a direction which is perpendicular to dir `d`
	if d.y == 0 then return const.dir.U
	else return const.dir.E or const.dir.F end
end

dirRotationBetween = function(va, vb)
	if va == vb then return identity
	elseif va == -vb then return negate end
	local rotAxis = -va:cross(vb):normalize()
	return function(v) return v % rotAxis end
end

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

