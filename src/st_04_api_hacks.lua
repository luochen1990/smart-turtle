---------------------------------- api hacks -----------------------------------

-- manhattan distance between pos `a` and ori
manhat = function(a) return math.abs(a.x) + math.abs(a.y) + math.abs(a.z) end

improveVector = function()
	local mt = getmetatable(vector.new(0,0,0))
	mt.__len = function(a) return math.abs(a.x) + math.abs(a.y) + math.abs(a.z) end -- use `#a`
	mt.__eq = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end
	mt.__lt = function(a, b) return a.x < b.x and a.y < b.y and a.z < b.z end
	mt.__le = function(a, b) return a.x <= b.x and a.y <= b.y and a.z <= b.z end
	mt.__mod = function(a, b) return a:cross(b) end -- use `a % b` as `a:cross(b)`
	mt.__concat = function(a, b) return (b - a) end -- use `a .. b` as `b - a`, i.e. a vector from `a` point to `b`
	mt.__pow = function(a, b) return -a:cross(b):normalize() end -- use `a ^ b` to get rotate axis from `a` to `b` so that: forall a, b, a:cross(b) ~= 0 and a:dot(b) == 0  --->  (exists k, a * (a ^ b)) == b * k)
end

improveVector()
vec = vector.new

