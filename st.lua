------------------  Created by: lc (luochen1990@gmail.com)  --------------------

------------------------------- assertion tools --------------------------------

DEBUG = true
__assert = assert
assert = function(...) if DEBUG then __assert(...) end end

----------------------------- vector improvement -------------------------------

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
const.directions = {"U", "E", "S", "W", "N", "D"}
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
	_ioMetatable.__div = function(io1, io2) return _mkIO(function() r = io1.run(); io2.run(); return r end) end -- `<*` in haskell

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
			local r = io()
			if r then return r end
			local maxInterval = 0.5
			local waitedSeconds = 0.0
			while waitedSeconds < retrySeconds do -- state: {waitedSeconds, maxInterval}
				local interval = math.min(retrySeconds - waitedSeconds, math.random() * maxInterval)
				sleep (interval)
				r = io()
				if r then return r end
				waitedSeconds = waitedSeconds + interval
				maxInterval = maxInterval * 2
			end
			return r
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
		return mkIO(function() local r; repeat r = io() until(stopCond(r)); return r end)
	end
end

-- | repeat until succ,  (use `rep(-io)` as repeat until fail)
rep = function(io)
	return mkIO(function() local r; repeat r = io() until(r); return r end)
end

--------- the Turtle Monad ( ReaderT workMode (StateT workState IO) ) ----------

workMode = {
	destroy = 1, -- whether auto dig when move blocked: 0:no dig, 1:dig cheap items only, 2:dig all except protected
	violence = false, -- whether auto attack when move blocked
	retrySeconds = 2, -- seconds to retry before fail back when move blocked by other turtles
	backpackWhiteList = {},
	backpackBlackList = {},
	backpackPinnedSlots = {},
}

workState = {
	pos = nil, -- current pos
	facing = nil, -- current facing direction, const.dir.N/S/W/E
	aiming = 0, -- 0:front, 1:up, -1:down
	beginPos = nil, -- pos when the program start
	localFuelStation = {pos = nil, dir = nil},
	localUnloadStation = {pos = nil, dir = nil},
	isDetouring = false,
	interruptStack = {}, -- { {reason: "OutOfFuel"/"NeedUnload", pos: vec(100,0,0)} }
}

function workState:aimingDir()
	if self.aiming == 0 then return self.facing
	else return vec(0, self.aiming, 0) end
end

function workState:lateralDir() -- a direction which is perpendicular to aimingDir
	if self.aiming == 0 then return const.dir.U
	else return self.facing end
end

leftSide = memoize(function(d) return d % const.rotate.left end)
rightSide = memoize(function(d) return d % const.rotate.right end)

-- | run io with specified workMode fields
with = function(wm_patch)
	return function(io)
		return mkIO(function()
			local _wm = workMode
			workMode = deepcopy(_wm)
			for k, v in pairs(wm_patch) do workMode[k] = v end
			r = {io()}
			workMode = _wm
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
	if d == workState.facing then return true
	elseif d == -workState.facing then return turn.back()
	elseif d == leftSide(workState.facing) then return turn.left()
	elseif d == rightSide(workState.facing) then return turn.right()
	else return true end
end)
turn.lateral = mkIO(function() return turn.to(workState:lateralDir()) end)
for k, v in pairs(const.dir) do turn[k] = turn.to(v) end

saveTurning = function(io)
	return mkIO(function()
		local _facing, _aiming = workState.facing, workState.aiming
		r = {io()}
		turn.to(_facing)()
		if _aiming ~= 0 then turn.to(vec(0, _aiming, 0)) end
		return unpack(r)
	end)
end

_wrapAimingSensitiveApi = function(apiName, wrap, rawApis)
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
	move = _wrapAimingSensitiveApi("move", mkIO, {turtle.up, turtle.forward, turtle.down}),
	dig = _wrapAimingSensitiveApi("dig", mkIO),
	place = _wrapAimingSensitiveApi("place", mkIO),
	detect = _wrapAimingSensitiveApi("detect", mkIO),
	inspect = _wrapAimingSensitiveApi("inspect", mkIO),
	compare = _wrapAimingSensitiveApi("compare", mkIO),
	attack = _wrapAimingSensitiveApi("attack", mkIO),
	suck = _wrapAimingSensitiveApi("suck", mkIOfn),
	drop = _wrapAimingSensitiveApi("drop", mkIOfn),
}

detect = _aiming.detect
compare = _aiming.compare
attack = _aiming.attack
suck = _aiming.suck
drop = _aiming.drop

-- | different from turtle.inspect, this only returns res
inspect = mkIO(function()
	ok, res = _aiming.inspect()
	return res
end)

isEmpty = -detect

isNamed = mkIOfn(function(name)
	ok, res = _aiming.inspect()
	return ok and res.name == name
end)

isSame = mkIO(function()
	ok, res = _aiming.inspect()
	return ok and res.name == turtle.getItemDetail().name
end)

isTurtle = mkIO(function()
	ok, res = _aiming.inspect()
	return ok and const.turtleBlocks[res.name] == true
end)

isChest = mkIO(function()
	ok, res = _aiming.inspect()
	return ok and const.chestBlocks[res.name] == true
end)

isCheap = mkIO(function()
	ok, res = _aiming.inspect()
	return ok and const.cheapItems[res.name] == true
end)

isProtected = mkIO(function()
	ok, res = _aiming.inspect()
	return ok and (const.turtleBlocks[res.name] == true or const.chestBlocks[res.name] == true)
end)

has = mkIOfn(function(name) return not not slot.find(name) end)

select = mkIOfn(turtle.select)

dig = mkIO(function()
	-- tidy backpack to reserve slot
	if not slot.findLastEmpty() then
		slot.tidy()
		if not slot.findLastEmpty() then
			turtle.select(slot.findDroppable())
			local io = (saveTurning(turn.lateral * -isChest * drop()) + drop())
			io()
		end
	end
	--
	return _aiming.dig()
end)

-- | keep current slot not empty after place
place = mkIO(function()
	c = turtle.getItemCount()
	s = turtle.getItemSpace()
	if c == 1 and s > 0 then slot.fill() end
	return c > 1 and _aiming.place()
end)

-- | use item, another use case of turtle.place
use = mkIOfn(function(name)
	if turtle.getItemDetail().name ~= name then
		sn = slot.find(name)
		if not sn then return false end
		turtle.select(sn)
	end
	return _aiming.place()
end)

move = mkIO(function()
	-- auto refuel
	refuel(#(workState.beginPos .. workState.pos))
	--
	local mov = _aiming.move
	if workMode.destroy == 1 then
		mov = mov + (rep(-(isCheap * dig)) .. mov)
	elseif workMode.destroy == 2 or workMode.destroy == true then
		mov = mov + (rep(-(-isProtected * dig)) .. mov)
	end
	if workMode.violence then
		mov = mov + (rep(-attack) .. mov)
	end
	if workMode.retrySeconds > 0 and isTurtle() then -- only retry when blocked by turtle
		mov = mov % workMode.retrySeconds
	end
	r = mov()
	if r then workState.pos = workState.pos + workState:aimingDir() end
	-- record backPath
	return r
end)

------------------------- backpack slots management ----------------------------

slot = {
	findThat = function(cond, beginSlot) -- find something after beginSlot which satisfy cond
		for i = beginSlot, const.turtle.backpackSlotsNum do
			if cond(turtle.getItemDetail(i)) then return i end
		end
		return nil
	end,
	findLastThat = function(cond, beginSlot)
		for i = const.turtle.backpackSlotsNum, beginSlot, -1 do
			if cond(turtle.getItemDetail(i)) then return i end
		end
		return nil
	end,
	find = function(name, beginSlot)
		return slot.findThat(function(det) return det and det.name == name end, beginSlot)
	end,
	findLast = function(name, beginSlot)
		return slot.findLastThat(function(det) return det and det.name == name end, beginSlot)
	end,
	findSame = function(sn, beginSlot)
		det = turtle.getItemDetail(sn)
		if det then return slot.find(det.name, beginSlot) end
	end,
	findLastSame = function(sn, beginSlot)
		det = turtle.getItemDetail(sn)
		if det then return slot.findLast(det.name, beginSlot) end
	end,
	findEmpty = function(beginSlot)
		return slot.findThat(function(det) return not det end, beginSlot)
	end,
	findLastEmpty = function(beginSlot)
		return slot.findLastThat(function(det) return not det end, beginSlot)
	end,
	findDroppable = function(beginSlot)
		return slot.findThat(function(det) return const.cheapItems[det.name] end, beginSlot)
	end,
	countAll = function(countSingleSlot)
		local cnt = 0
		for i = 1, const.turtle.backpackSlotsNum do
			n = countSingleSlot(turtle.getItemDetail(i))
			if n then cnt = cnt + n end
		end
		return cnt
	end,
	count = function(name)
		return slot.countAll(function(det) if det and det.name == name then return det.count else return 0 end end)
	end,
	countSame = function(sn)
		det = turtle.getItemDetail(sn)
		if det then return slot.count(det.name) end
	end,
	fill = function(sn) -- use items in slots after sn to make slot sn as full as possible
		_sn = turtle.getSelectedSlot()
		count = turtle.getItemCount(sn)
		space = turtle.getItemSpace(sn)
		if count ~= 0 and space ~= 0 then
			turtle.select(sn)
			for i = const.turtle.backpackSlotsNum, sn + 1, -1 do
				if turtle.compareTo(i) then
					got = turtle.getItemCount(i)
					turtle.select(i)
					turtle.transferTo(sn)
					if got >= space then break end
				end
			end
		end
		turtle.select(_sn)
		return count ~= 0
	end,
	tidy = function()
		for i = 1, const.turtle.backpackSlotsNum do slot.fill(i) end
	end,
	reserve = function()
	end,
}

-------------------------------- auto refuel  ----------------------------------

refuel = function(nStep)
	nStep = math.max(1 , nStep)
	while turtle.getFuelLevel() < nStep do
		fuelSn = slot.findThat(function(det) return const.fuelHeatContent[det.name] end)
		if not fuelSn then return false end
		turtle.select(fuelSn)
		while turtle.getFuelLevel() < nStep and turtle.getItemCount(fuelSn) > 0 do
			if turtle.getItemCount(fuelSn) < 2 then slot.fill(fuelSn) end
			turtle.refuel(1)
		end
	end
	return true
end

------------------------------- advaneced move ---------------------------------

-- | attempt to approach destPos by one step
move.toward = function(destPos)
	return mkIO(function()
		local ok = false
		v = workState.pos .. destPos
		for _, d in ipairs(const.directions) do
			if v:dot(const.dir[d]) > 0 then
				ok = ok or (turn[d] .. move)()
				if ok then break end
			end
		end
		return ok
	end)
end

move.to = function(destPos)
	return mkIO(function()
		while true do
			rep(-move.toward(destPos))()
			if workState.pos == destPos then return true end
			v = workState.pos .. destPos
			local targetDir
			for _, d in ipairs(const.directions) do
				if v:dot(const.dir[d]) > 0 then targetDir = const.dir[d]; break end
			end
			-- targetDir decided
			local detourDir
			for _, d in ipairs(const.directions) do
				if targetDir:dot(const.dir[d]) == 0 then
					ok = (turn.to(const.dir[d]) .. move)()
					if ok then detourDir = const.dir[d]; break end
				end
			end
			if not detourDir then return false end
			-- init detourDir decided
			detourRotate = targetDir ^ detourDir
			detourDirs = {targetDir, detourDir, detourDir % detourRotate, detourDir % detourRotate % detourRotate}
			-- detourDirs decided

			local detourRotateCount = 1
			repeat
				for i = -1, 2 do --NOTE: from detourDir-1 to detourDir+2
					candidateDir = detourDirs[(detourRotateCount + i) % 4 + 1]
					ok = (turn.to(candidateDir) .. move)()
					if ok then
						detourRotateCount = detourRotateCount + i
						break
					end
				end
			until (detourRotateCount % 4 == 0)
		end
	end)
end

move.go = function(destv)
	return mkIO(function()
		move.to(workState.pos + destv)()
	end)
end

------------------------------- main coroutine ---------------------------------

initWorkState = function()
	turtle.dig()
	turtle.select(1)
	turtle.place()
	local ok, r = turtle.inspect()
	assert(ok, "failed to get facing direction (inspect failed)")
	workState.facing = -const.dir[r.state.facing:sub(1,1):upper()]
	assert(workState.facing.y == 0, "failed to get facing direction (not a horizontal direction)")
	turtle.dig()
	workState.pos = vec(gps.locate())
	workState.beginPos = workState.pos
	saveTurning(turn.left .. use("minecraft:chest"))()
end

main = function()
end

begin = function (...)
	parallel.waitForAll(main, ...)
end

------------------------------------- repl -------------------------------------

repl = function()
	os.run(_ENV, "/rom/programs/lua.lua")
end

v1 = vec(1,0,0)
v2 = vec(0,1,0)
v3 = vec(0,0,1)

initWorkState()
saveTurning(move.go(vec(-2,0,0)) .. move.to(vec(203,69,-76)))()
repl()
