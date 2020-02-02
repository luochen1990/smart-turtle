------------------  Created by: lc (luochen1990@gmail.com)  --------------------

------------------------------- assertion tools --------------------------------

DEBUG = true
__assert = assert
assert = function(...) if DEBUG then __assert(...) end end

----------------------------- vector improvement -------------------------------

improveVector = function()
	local mt = getmetatable(vector.new(0,0,0))
	mt.__len = function(a) return a:length() end -- use `#a` as `a:length()`
	mt.__eq = function(a, b) return a.x == b.x and a.y == b.y and a.z == b.z end
	mt.__lt = function(a, b) return a.x < b.x and a.y < b.y and a.z < b.z end
	mt.__le = function(a, b) return a.x <= b.x and a.y <= b.y and a.z <= b.z end
	mt.__mod = function(a, b) return a:cross(b) end -- use `a % b` as `a:cross(b)`
	mt.__concat = function(a, b) return (b - a) end -- use `a .. b` as `b - a`, i.e. a vector from `a` point to `b`
	mt.__pow = function(a, b) return -a:cross(b):normalize() end -- use `a ^ b` to get rotate axis from `a` to `b` so that: forall a, b, a:cross(b) ~= 0 and a:dot(b) == 0  --->  (exists k, a * (a ^ b)) == b * k)
end

improveVector()
vec = vector.new

----------------------- basic knowledge about the game -------------------------

const = {
	turtle = {
		needfuel = true,
		backpackSlotsNum = 16,
		baseAPIs = {
			"forward", "back", "up", "down", "turnLeft", "turnRight",
			"refuel", "getFuelLevel", "getFuelLimit",
			"select", "getSelectedSlot", "getItemCount", "getItemSpace", "getItemDetail", "transferTo",
			"compare", "compareUp", "compareDown", "compareTo",
			"suck", "suckUp", "suckDown", "drop", "dropUp", "dropDown",
			"dig", "digUp", "digDown", "place", "placeUp", "placeDown",
			"detect", "detectUp", "detectDown", "inspect", "inspectUp", "inspectDown",
			"attack", "attackUp", "attackDown", "equipLeft", "equipRight",
		},
	},
	cheapItems = {
		["minecraft:cobblestone"] = true,
		["minecraft:dirt"] = true,
		["minecraft:sand"] = true,
	},
	afterDig = {
		["minecraft:stone"] = "minecraft:cobblestone",
	},
	valuableItems = {
		"minecraft:diamond_ore",
		"minecraft:gold_ore",
		"minecraft:iron_ore",
		"minecraft:coal_ore",
		"minecraft:redstone_ore",
		"minecraft:lapis_ore",
	},
	turtleBlocks = {
		["minecraft:turtle_normal"] = true,
		["minecraft:turtle_advanced"] = true,
	},
	chestBlocks = {
		["minecraft:chest"] = true,
		["minecraft:shulker_box"] = true,
	},
	fuelHeatContent = {
		["minecraft:lava_bucket"] = 1000,
		["minecraft:coal"] = 80,
		["minecraft:oak_log"] = 15,
		["minecraft:light_gray_carpet"] = 3,
	},
}

const.ori = vec(0,0,0)
const.dir = {
	['E'] = vec(1,0,0), ['W'] = vec(-1,0,0),
	['U'] = vec(0,1,0), ['D'] = vec(0,-1,0),
	['S'] = vec(0,0,1), ['N'] = vec(0,0,-1),
}
const.rotate = {
	left = const.dir.N ^ const.dir.W,
	right = const.dir.N ^ const.dir.E,
}

----------------------------- general utils ------------------------------------

-- | identity : a -> a
identity = function(x) return x end

-- | pipe : (a -> b) -> (b -> c) -> a -> c
-- , pipe == flip compose
pipe = function(f, ...)
	local fs = {...}
	if #fs == 0 then return f end
	return function(...) return pipe(unpack(fs))(f(...)) end
end

-- | default : a -> Maybe a -> a
default = function(dft)
	return function(x) if x ~= nil then return x else return dft end end
end

-- | maybe : (b, a -> b) -> Maybe a -> b
maybe = function(dft, wrap)
	return function(x) if x == nil then return dft else return wrap(x) end end
end

-- | apply : a -> (a... -> b) -> b
apply = function(args)
	return function (f) return f(unpack(args)) end
end

-- | delay : (a -> b, a) -> IO b
delay = function(f, args)
	return function() return f(unpack(args)) end
end

deepcopy = function(obj)
	local lookup_table = {}
	local function _copy(obj)
		if type(obj) ~= "table" then
			return obj
		elseif lookup_table[obj] then
			return lookup_table[obj]
		end
		local new_table = {}
		lookup_table[obj] = new_table
		for index, value in pairs(obj) do
			new_table[_copy(index)] = _copy(value)
		end
		return setmetatable(new_table, getmetatable(obj))
	end
	return _copy(obj)
end

memoize = function(f)
	local mem = {}
	setmetatable(mem, {__mode = "kv"})
	return function(...)
		local r = mem[{...}]
		if r == nil then
			r = f(...)
			mem[{...}] = r
		end
		return r
	end
end

math.randomseed(os.time()) -- set randomseed for math.random()

----------------------------------- IO Monad -----------------------------------

-- | mkIO : (a... -> b, a...) -> IO b
mkIO, mkIOfn = (function()
	local _ioMetatable = {}
	local _mkIO = function(f, ...)
		local args = {...}
		local io = {
			run = function() return f(unpack(args)) end,
			['then'] = function(io1, f2) return _mkIO(function() return f2(io1.run()).run() end) end, --  `>>=` in haskell
		}
		setmetatable(io, _ioMetatable)
		return io
	end
	local _mkIOfn = function(f)
		return function(...) return _mkIO(f, ...) end
	end
	_ioMetatable.__len = function(io) return _mkIO(function() local r; repeat r = io.run() until(r); return r end) end -- `#io` means repeat until succ,  (use `#-io` as repeat until fail)
	_ioMetatable.__call = function(io, ...) return io.run(...) end
	_ioMetatable.__concat = function(io1, io2) return _mkIO(function() io1.run(); return io2.run() end) end -- `>>` in haskell
	_ioMetatable.__mod = function(io, s) return retry(s)(io) end -- retry for a few seconds
	_ioMetatable.__pow = function(io, n) return replicate(n)(io) end -- replicate a few times
	_ioMetatable.__add = function(io1, io2) return _mkIO(function() return io1.run() or io2.run() end) end -- if io1 fail then io2
	_ioMetatable.__mul = function(io1, io2) return _mkIO(function() return io1.run() and io2.run() end) end -- if io1 succ then io2
	_ioMetatable.__unm = function(io) return _mkIO(function() return not io.run() end) end -- `fmap not` in haskell
	return _mkIO, _mkIOfn
end)()

-- | pure : a -> IO a
pure = function(x) return mkIO(function() return x end) end

-- | retry : Int -> IO Bool -> IO Bool
-- , retry an io which might fail for several seconds before finally fail
retry = function(retrySeconds)
	return function(io)
		return mkIO(function()
			if io() then return true end
			local maxInterval = 0.5
			local waitedSeconds = 0.0
			while waitedSeconds < retrySeconds do -- state: {waitedSeconds, maxInterval}
				local interval = math.min(retrySeconds - waitedSeconds, math.random() * maxInterval)
				sleep (interval)
				if io() then return true end
				waitedSeconds = waitedSeconds + interval
				maxInterval = maxInterval * 2
			end
			return false
		end)
	end
end

-- | replicate : Int -> IO a -> IO Int
replicate = function(n)
	return function(io)
		return mkIO(function()
			local c = 0
			for i = 1, n do
				local r = io()
				if r then c = c + 1 end
			end
			return c
		end)
	end
end

-- | repeatUntil : (a -> Bool) -> IO a -> IO a
repeatUntil = function(stopCond)
	return function(io)
		return mkIO(function()
			local r
			repeat r = io() until(stopCond(r))
			return r
		end)
	end
end

-- | repeat until succ,  (use `rep(-io)` as repeat until fail)
rep = function(io)
	return mkIO(function() local r; repeat r = io.run() until(r); return r end)
end

--------- the Turtle Monad ( ReaderT workMode (StateT workState IO) ) ----------

workMode = {
	destroy = false, -- whether auto dig when move blocked
	violence = false, -- whether auto attack when move blocked
	retrySeconds = 10, -- seconds to retry before fail back when move blocked
	backpackWhiteList = {},
	backpackBlackList = {},
	backpackPinnedSlots = {},
}

workState = {
	pos = nil,
	facing = nil, -- const.dir.N/S/W/E
	aiming = 0, --  0:front, 1:up, -1:down
	backPath = {},
	localFuelStation = {pos = nil, dir = nil},
	localUnloadStation = {pos = nil, dir = nil},
	isDetouring = false,
	interruptStack = {}, -- { {reason: "OutOfFuel"/"NeedUnload", pos: vec(100,0,0)} }
}

function workState:aimingDir()
	if self.aiming == 0 then return self.facing
	else return vec(0, self.aiming, 0) end
end

leftSide = memoize(function(d) return d % const.rotate.left end)
rightSide = memoize(function(d) return d % const.rotate.right end)

-- | run io with specified workMode fields
with = function(wm_patch)
	return function(io)
		return mkIO(function()
			local __wm = workMode
			workMode = deepcopy(__wm)
			for k, v in pairs(wm_patch) do workMode[k] = v end
			r = {io()}
			workMode = __wm
			return unpack(r)
		end)
	end
end

--------------------------------- Monadic API ----------------------------------

turn = {
	left = mkIO(function() turtle.turnLeft(); workState.facing = leftSide(workState.facing); return true end),
	right = mkIO(function() turtle.turnRight(); workState.facing = rightSide(workState.facing); return true end),
	back = mkIO(function() turtle.turnLeft(); turtle.turnLeft(); workState.facing = -workState.facing; return true end),
}
turn.to = mkIOfn(function(d)
	workState.aiming = d.y
	if d == -workState.facing then
		turn.back()
	elseif d == leftSide(workState.facing) then
		turn.left()
	elseif d == rightSide(workState.facing) then
		turn.right()
	end
	return true
end)
for k, v in pairs(const.dir) do turn[k] = turn.to(v) end

wrapAimingSensitiveApi = function(apiName, wrap, rawApis)
	if rawApis == nil then rawApis = {turtle[apiName..'Up'], turtle[apiName], turtle[apiName..'Down']} end
	assert(#rawApis >= 3, "three rawApis must be provided")
	return wrap(function(...)
		rawApi = rawApis[2 - workState.aiming]
		assert(rawApi ~= nil, "workState.aiming must be 0/1/-1")
		return rawApi(...)
	end)
end

-- | these are lightweight wrapped apis
-- , which read workState.facing and workState.aiming to decide which raw api to use
-- , but doesn't change workState
_aiming = {
	move = wrapAimingSensitiveApi("move", mkIO, {turtle.up, turtle.forward, turtle.down}),
	dig = wrapAimingSensitiveApi("dig", mkIO),
	place = wrapAimingSensitiveApi("place", mkIO),
	detect = wrapAimingSensitiveApi("detect", mkIO),
	inspect = wrapAimingSensitiveApi("inspect", mkIO),
	compare = wrapAimingSensitiveApi("compare", mkIO),
	attack = wrapAimingSensitiveApi("attack", mkIO),
	suck = wrapAimingSensitiveApi("suck", mkIOfn),
	drop = wrapAimingSensitiveApi("drop", mkIOfn),
}

place = _aiming.place
detect = _aiming.detect
inspect = _aiming.inspect
compare = _aiming.compare
attack = _aiming.attack
suck = _aiming.suck
drop = _aiming.drop

isTurtle = mkIO(function()
	ok, res = inspect()
	return ok and const.turtleBlocks[res.name] == true
end)

isChest = mkIO(function()
	ok, res = inspect()
	return ok and const.chestBlocks[res.name] == true
end)

dig = mkIO(function()
	-- tidy backpack to reserve slot
	return _aiming.dig()
end)

move = mkIO(function()
	-- trigger refuel interrupt
	local mov = _aiming.move
	if workMode.destroy then
		mov = mov + (rep(-dig) .. mov)
	end
	if workMode.violence then
		mov = mov + (rep(-attack) .. mov)
	end
	if workMode.retrySeconds > 0 then
		mov = mov % workMode.retrySeconds
	end
	r = mov()
	if r then workState.pos = workState.pos + workState:aimingDir() end
	-- record backPath
	return r
end)

------------------------------- main coroutine ---------------------------------

st_main = function()
	turtle.dig()
	turtle.select(1)
	turtle.place()
	local ok, r = turtle.inspect()
	assert(ok, "failed to get facing direction (inspect failed)")
	workState.facing = -const.dir[r.state.facing:sub(1,1):upper()]
	assert(workState.facing.y == 0, "failed to get facing direction (not a horizontal direction)")
	turtle.dig()
	workState.pos = vec(gps.locate())
end

begin = function (...)
	parallel.waitForAll(st_main, ...)
end

------------------------------------- repl -------------------------------------

repl = function()
	os.run(_ENV, "/rom/programs/lua.lua")
end

v1 = vec(1,0,0)
v2 = vec(0,1,0)
v3 = vec(0,0,1)

st_main()
repl()
