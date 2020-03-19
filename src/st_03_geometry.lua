----------------------------------- geometry -----------------------------------

_hackVector = function()
	local mt = getmetatable(vector.new(0,0,0))
	mt.__tostring = function(a) return "<"..a.x..","..a.y..","..a.z..">" end
	mt.__literal = function(a) return "vec("..a.x..","..a.y..","..a.z..")" end
	mt.__eq = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end
	mt.__lt = function(a, b) return a.x < b.x and a.y < b.y and a.z < b.z end
	mt.__le = function(a, b) return a.x <= b.x and a.y <= b.y and a.z <= b.z end
	mt.__mod = function(a, b) return a:cross(b) end -- use `a % b` as `a:cross(b)`
	mt.__concat = function(a, b) return mkArea(a, b) end -- use `a .. b` as `mkArea(a, b)`
	mt.__pow = function(a, b) return b - a end -- use `a ^ b` as `b - a`
end
_hackVector()

vec = {
	zero = vector.new(0,0,0),
	one = vector.new(1,1,1),
	axis = {
		X = vector.new(1,0,0),
		Y = vector.new(0,1,0),
		Z = vector.new(0,0,1),
	},
	isVec = (function()
		local mt = getmetatable(vector.new(0,0,0))
		return function(x) return getmetatable(x) == mt end
	end)(),
	floor = function(v)
		return v and v.x and vec(math.floor(v.x), math.floor(v.y), math.floor(v.z))
	end,
	-- | manhattan distance between pos `v` and vec.zero
	manhat = function(v) return math.abs(v.x) + math.abs(v.y) + math.abs(v.z) end,
	rank = function(v)
		local r = 0
		if v.x ~= 0 then r = r + 1 end
		if v.y ~= 0 then r = r + 1 end
		if v.z ~= 0 then r = r + 1 end
		return r
	end,
	components = function(v)
		local r = {}
		if v.x ~= 0 then table.insert(r, vec.axis.X * v.x) end
		if v.y ~= 0 then table.insert(r, vec.axis.Y * v.y) end
		if v.z ~= 0 then table.insert(r, vec.axis.Z * v.z) end
		return r
	end,
	unitComponents = function(v)
		local r = {}
		if v.x ~= 0 then table.insert(r, vec.axis.X * sign(v.x)) end
		if v.y ~= 0 then table.insert(r, vec.axis.Y * sign(v.y)) end
		if v.z ~= 0 then table.insert(r, vec.axis.Z * sign(v.z)) end
		return r
	end,
}
setmetatable(vec, {
	__call = function(_, ...) return vector.new(...) end,
})

-- | naive gps locate, without retry
_gpsLocate = function(timeout)
	local x, y, z = gps.locate(timeout)
	if (x and x == x) then --NOTE: it is possible that gps.locate() returns nan,nan,nan
		return vec(x, y, z)
	else
		log.warn("gps.locate(" .. (timeout or "") .. ") failed: "..show(x, y, z))
		return nil
	end
end

-- | return a vector, which coord value might not be integer (pocket)
gpsLocate = function(totalTimeout)
	if not totalTimeout then
		return retryWithTimeout(function(t) return mkIO(_gpsLocate, t) end)()
	else
		return retryWithTimeout(totalTimeout)(function(t) return mkIO(_gpsLocate, t) end)()
	end
end

-- | a simple wrapper of gpsLocate
gpsPos = function(...)
	local v = gpsLocate(...)
	return v and vec.floor(v)
end

-- | distance : Pos -> (Pos -> Int)
distance = function(pos) return function(p) return vec.manhat(pos - p) end end

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

mkArea, isArea = (function()
	local _area_mt = {
		__eq = function(a, b) return a.low == b.low and a.high == b.high end,
		__le = function(a, b) return a.low >= b.low and a.high <= b.high end,
		__tostring = function(a) return tostring(a.low)..".."..tostring(a.high) end,
		__literal = function(a) return "mkArea("..literal(a.low)..","..literal(a.high)..")" end,
	}
	local isArea = function(a)
		return type(a) == "table" and getmetatable(a) == _area_mt
	end
	local _mkArea
	_mkArea = function(low, high) -- including
		local a = {
			low = low, high = high, diag = high - low,
			volume = function(a) return (a.diag.x + 1) * (a.diag.y + 1) * (a.diag.z + 1) end,
			contains = function(a, p) return p >= a.low and p <= a.high end,
			vertexes = function(a) return {
				a.low, a.low + E * E:dot(a.diag), a.low + S * S:dot(a.diag), a.low + U * U:dot(a.diag),
				a.high + D * D:dot(a.diag), a.high + N * N:dot(a.diag), a.high + W * W:dot(a.diag), a.high,
			} end,
			-- find a vertex nearest to a specific pos
			-- NOTE: far = a.low + a.high - near
			vertexNear = function(a, pos)
				local near = a.low
				for _, p in ipairs(a:vertexes()) do
					if (p - pos):length() < (near - pos):length() then near = p end
				end
				return near
			end,
			face = function(a, dir)
				local projLen = a.diag:dot(dir)
				if projLen > 0 then
					return _mkArea((a.low + dir * projLen), a.high)
				else
					return _mkArea(a.low, (a.high - dir * projLen))
				end
			end,
			expandToInclude = function(a, target)
				if vec.isVec(target) then
					return _mkArea(lowPoint(a.low, target), highPoint(a.high, target))
				elseif isArea(target) then
					return _mkArea(lowPoint(a.low, target.low), highPoint(a.high, target.high))
				else
					error("[area:expandToInclude] target should be pos or area")
				end
			end,
			expand = function(a, v)
				if type(v) == "number" then
					return _mkArea(a.low - vec.one * v, a.high + vec.one * v)
				elseif vec.isVec(v) then
					return a:expandToInclude(a:shift(v))
				else
					error("[area:expand] v should be vector or number")
				end
			end,
			shift = function(a, v)
				return _mkArea(a.low + v, a.high + v)
			end,
		}
		setmetatable(a, _area_mt)
		return a
	end
	local mkArea = function(p, q)
		assert(p and p.x and q and q.x, "[mkArea(p, q)] p and q should be vector")
		return _mkArea(lowPoint(p, q), highPoint(p, q))
	end
	return mkArea, isArea
end)()

