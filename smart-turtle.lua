------------------  Created by: lc (luochen1990@gmail.com)  --------------------

useage = {
	link = "link(p1, ..., [f])\n such as: link(go(1,0,2), scan('d',2), dig.down)\n"
	go = "go(x, y, z, [p])\n such as: go(1,0,2)\n or: go(pos, [p])\n such as: go({x=1,z=2})\n"
	scan = "scan(dir, times, [p])\n such as: scan('f',2)\n"
	cycle = "cycle(dir, round, [times], [p])\n such as: cycle('r', 'X##XX##X')\n"
	digLine = "digLine(dir, maxdis, [p])\n"
	digAll = "digAll(slots, [maxdis], [p])\n"
	digExcept = "digExcept(slots, [maxdis], [p])\n"
}

------------------------------- assertion tools --------------------------------

DEBUG = true
__assert = assert
if DEBUG then assert = __assert else assert = function() end end

----------------------------- vector improvement -------------------------------

improveVector = function()
	--vecWrap = function(p) -- add new method here like `p.f1 = function(...) ...`
	--end

	--local __vec = vector.new
	--vec = function (x, y, z) return vecWrap(__vec(x, y, z)) end
	--vector.new = vec

	local mt = getmetatable(vector.new(0,0,0))
	mt.__len = function(a) return a:length() end -- use `#a` as `a:length()`
	mt.__mod = function(a, b) return a:cross(b) end -- use `a % b` as `a:cross(b)`
	mt.__concat = function(a, b) return (b - a) end -- use `a .. b` as `b - a`, i.e. a vector from `a` point to `b`
	mt.__pow = function(a, b) return -a:cross(b):normalize() end -- use `a ^ b` to get rotate axis from `a` to `b` so that: forall a, b, a:cross(b) ~= 0 and a:dot(b) == 0  --->  (exists k, a * (a ^ b)) == b * k)
end

improveVector()
vec = vector.new

----------------------- basic knowledge about the game -------------------------

const = {
	turtle = {
		needfuel = true
		backpackSlotsNum = 16
		baseAPIs = {
			"forward", "back", "up", "down", "turnLeft", "turnRight",
			"refuel", "getFuelLevel", "getFuelLimit",
			"select", "getSelectedSlot", "getItemCount", "getItemSpace", "getItemDetail", "transferTo",
			"compare", "compareUp", "compareDown", "compareTo",
			"suck", "suckUp", "suckDown", "drop", "dropUp", "dropDown",
			"dig", "digUp", "digDown", "place", "placeUp", "placeDown",
			"detect", "detectUp", "detectDown", "inspect", "inspectUp", "inspectDown",
			"attack", "attackUp", "attackDown", "equipLeft", "equipRight",
		}
	}
	cheapItems = {
		"minecraft:cobblestone",
		"minecraft:dirt",
		"minecraft:sand",
	}
	afterDig = {
		"minecraft:stone" = "minecraft:cobblestone",
	}
	valuableItems = {
		"minecraft:diamond_ore",
		"minecraft:gold_ore",
		"minecraft:iron_ore",
		"minecraft:coal_ore",
		"minecraft:redstone_ore",
		"minecraft:lapis_ore",
	}
	turtleBlocks = {
		"minecraft:turtle_normal",
	}
	chestBlocks = {
		"minecraft:chest",
		"minecraft:shulker_box",
	}
	fuelHeatContent = { coal = 80, lava = 1000 }
}

const.ori = vec(0,0,0)
const.dir = {
	'E' = vec(1,0,0), 'W' = vec(-1,0,0),
	'U' = vec(0,1,0), 'D' = vec(0,-1,0),
	'S' = vec(0,0,1), 'N' = vec(0,0,-1),
}
const.rotate = {
	left = const.dir.N ^ const.dir.W
	right = const.dir.N ^ const.dir.E
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
			['then'] = function(io1, f2) return _mkIO(function() return f2(io1.run()).run() end) end --  `>>=` in haskell
		}
		setmetatable(io, _ioMetatable)
		return io
	end
	local _mkIOfn = function(f)
		return function(...) return _mkIO(f, ...) end
	end
	_ioMetatable._len = function(io) return _mkIO(function() local r; repeat r = io.run() until(r); return r end) end -- `#io` means repeat until succ,  (use `#-io` as repeat until fail)
	_ioMetatable._call = function(io, ...) return io.run(...) end
	_ioMetatable._concat = function(io1, io2) return _mkIO(function() io1.run(); return io2.run() end) end -- `>>` in haskell
	_ioMetatable._mod = function(io, s) return retry(s)(io) end -- retry for a few seconds
	_ioMetatable._pow = function(io, n) return replicate(n)(io) end -- replicate a few times
	_ioMetatable._add = function(io1, io2) return _mkIO(function() return io1.run() or io2.run() end) end -- if io1 fail then io2
	_ioMetatable._mul = function(io1, io2) return _mkIO(function() return io1.run() or io2.run() end) end -- if io1 succ then io2
	_ioMetatable._unm = function(io) return _mkIO(function() return not io.run() end) end -- `fmap not` in haskell
	return _mkIO, _mkIOfn
end)()

pure = function(x) return mkIO(function() return x end) end

-- | retry : Int -> IO Bool -> IO Bool
-- | retry an action named `io` which might fail for `retrySeconds` seconds
-- | e.g. `retry(3)(turtle.forward)()` works like `turtle.forward()` but will retry for 3 seconds before fail
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

repeatUntil = function(stopCond)
	function(io)
		local r
		repeat r = io() until(stopCond(r))
		return r
	end
end

--------- the Turtle Monad ( ReaderT WorkMode (StateT WorkState IO) ) ----------

workMode = {
	destroy = false, -- whether auto dig when move blocked
	violence = false, -- whether auto attack when move blocked
	retrySeconds = 10, -- seconds to retry before fail back when move blocked
	backpackWhiteList = {}
	backpackBlackList = {}
	backpackPinnedSlots = {}
}

workState = {
	pos = nil
	facing = nil -- const.dir.N/S/W/E
	aiming = 0 --  0:front, 1:up, -1:down
	backPath = {}
	localFuelStation = {pos = nil, dir = nil}
	localUnloadStation = {pos = nil, dir = nil}
	isDetouring = false
	interruptStack = {} -- { {reason: "OutOfFuel"/"NeedUnload", pos: vec(100,0,0)} }
}

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

---- | retryT : IO Bool -> IO Bool
---- | retry an action named `action` which might fail for `workMode.retrySeconds` seconds
--retryT = function(action)
--	return mkIO(function()
--		local retrySeconds = workMode.retrySeconds
--		if #action == true then return true end
--		local maxInterval = 0.5
--		local waitedSeconds = 0.0
--		while waitedSeconds < retrySeconds do -- state: {waitedSeconds, maxInterval}
--			local interval = math.min(retrySeconds - waitedSeconds, math.random() * maxInterval)
--			sleep (interval)
--			if #action == true then return true end
--			waitedSeconds = waitedSeconds + interval
--			maxInterval = maxInterval * 2
--		end
--		return false
--	end)
--end

turn = {
	left = mkIO(function() turtle.turnLeft(); workState.facing = leftSide(workState.facing); return true end)
	right = mkIO(function() turtle.turnRight(); workState.facing = rightSide(workState.facing); return true end)
	back = mkIO(function() turtle.turnLeft(); turtle.turnLeft(); workState.facing = -workState.facing; return true end)
}
turn.to = mkIOfn(function(d)
	workState.aiming = d.y
	if d == -workState.facing then
		#turn.back
	elseif d == leftSide(workState.facing) then
		#turn.left
	elseif d == rightSide(workState.facing) then
		#turn.right
	end
	return true
end)

wrapAimingSensitiveApi = function(apiName, rawFrontDo, rawUpDo, rawDownDo, wrap)
	return wrap(function(...)
		assert(workState.aiming == 0 or workState.aiming == 1 or workState.aiming == -1, "workState.aiming must be 0/1/-1")
		if workState.aiming == 0 then return rawFrontDo(...)
		elseif workState.aiming == 1 then return rawUpDo(...)
		else --[[if workState.aiming == -1 then]] return rawDownDo(...)
		end
	end)
end

aiming = {
	move = wrapAimingSensitiveApi("move", forward, up, down, mkIO)
	dig = wrapAimingSensitiveApi("dig", dig, digUp, digDown, mkIO)
	place = wrapAimingSensitiveApi("place", place, placeUp, placeDown, mkIO)
	detect = wrapAimingSensitiveApi("detect", detect, detectUp, detectDown, mkIO)
	inspect = wrapAimingSensitiveApi("inspect", inspect, inspectUp, inspectDown, mkIO)
	compare = wrapAimingSensitiveApi("compare", compare, compareUp, compareDown, mkIO)
	attack = wrapAimingSensitiveApi("attack", attack, attackUp, attackDown, mkIO)
	suck = wrapAimingSensitiveApi("suck", suck, suckUp, suckDown, mkIOfn)
	drop = wrapAimingSensitiveApi("drop", drop, dropUp, dropDown, mkIOfn)
}

--wrapDirectionSensitiveApi = function(apiName, wrap)
--	local aimingDo = aiming[apiName]
--	local apiDict = {}
--	for dirName, dir in pairs(const.dir) do
--		apiDict[dirName] = wrap(aimingDo, dir, apiName, dirName)
--	end
--	return apiDict
--end

--dig = wrapDirectionSensitiveApi("dig", function(aimingDo, dir) --TODO: reserve slot
--	return turn.to(dir) > aimingDo --NOTE: `io1 > io2` is similar to `io1 >> io2` in haskell, so this line is same as `return mkIO(function() #turn.to(dir); #aimingDo end)`
--end)
--
--place = wrapDirectionSensitiveApi("place", function(aimingDo, dir) -- TODO: select slot focus
--	return turn.to(dir) > aimingDo
--end)
--
--detect = wrapDirectionSensitiveApi("detect", function(aimingDo, dir)
--	return turn.to(dir) > aimingDo
--end)
--
--inspect = wrapDirectionSensitiveApi("inspect", function(aimingDo, dir)
--	return turn.to(dir) > aimingDo
--end)
--
--compare = wrapDirectionSensitiveApi("compare", function(aimingDo, dir) -- TODO: select slot focus
--	return turn.to(dir) > aimingDo
--end)
--
--attack = wrapDirectionSensitiveApi("attack", function(aimingDo, dir)
--	return turn.to(dir) > aimingDo
--end)
--
--suck = wrapDirectionSensitiveApi("suck", function(aimingDoFn, dir)
--	return function(...) return turn.to(dir) > aimingDoFn(...) end
--end)
--
--drop = wrapDirectionSensitiveApi("drop", function(aimingDoFn, dir) -- TODO: select slot focus
--	return function(...) return turn.to(dir) > aimingDoFn(...) end
--end)
--
--move = wrapDirectionSensitiveApi("move", function(aimingDo, dir) -- TODO: refuel
--	return turn.to(dir) > aimingDo
--end)

--[[
fp api usage:

repeatUntil(eq(false))(dig)
rep = repeatUntil(eq(false))
smartMove = move + (#-dig .. #-attack .. move)

replicate(10)(dig)
]]

-------------------------------generate base api----------------------

slot = {
	first = function(s)
		turtle.select(s)
		for i = 1, s do
			if turtle.compareTo(i) then
				s = i
				break
			end
		end
		return s
	end
	
	last = function(s)
		turtle.select(s)
		for i = const.slotnum, s, -1 do
			if turtle.compareTo(i) then
				s = i
				break
			end
		end
		return s
	end
	
	count = function(s)
		local c = turtle.getItemCount(s)
		if c == 0 then return 0 end
		turtle.select(s)
		for i = s + 1, const.slotnum do
			if turtle.compareTo(i) then
				c = c + turtle.getItemCount(i)
			end
		end
		return c
	end
	
	packUp = function(i)
		-- use items in slots after i to make slot i as full as possible .
		
		count = turtle.getItemCount(i)
		space = turtle.getItemSpace(i)
		if count ~= 0 and space ~= 0 then
			turtle.select(i)
			for j = const.slotnum, i + 1, -1 do 
				if turtle.compareTo(j) then
					got = turtle.getItemCount(j)
					turtle.select(j)
					if got >= space then
						turtle.transferTo(i, space)
						break
					else 
						turtle.transferTo(i, got)
					end
					turtle.select(i)
				end
			end
		end
	end
	
	packUpAll = function()
		for i = 1, const.slotnum do
			slot.packUp(i)
		end
	end
	
	waitingForReloading = function(s, time, amont)
		amont = withDefault(amont, 2)
		print (string.format('Please reload slot%d to at least %d in %ds', s, amont, time))
		local t = 0
		while slot.count(s) < amont do
			sleep(2)
			t = t + 1
			if t >= time then
				forceTryBack(string.format('lack of stuff in slot%d', s))
			end
		end
		io.write("Leaving soon ")
		for i = 1, 3 do sleep(2) io.write(".") end
		print(" byebye!")
		slot.packUp(s)
	end
	
	checkList = function(list, must)
		must = withDefault(must, #list)
		print('Checking List (load them now):')
		for s = 1, #list do
			local part1 = '['..s..']: <'..list[s][1]..'>'
			if s > must then
				part1 = '['..s..']: ['..list[s][1]..']'
			end
			local part2 = ''
			if #list[s] > 1 then
				part2 = ' * '..(list[s][2] + 1)
			end
			print(part1..part2)
		end
		for s = 1, must do
			local amont = withDefault(list[s][2], 0) + 1
			local t = 0
			while slot.count(s) < amont do
				sleep(2)
				t = t + 1
				if t >= 30 then
					forceTryBack('lack of <'..list[s][1]..'>')
				end
			end
		end
		io.write("Leaving soon ")
		for i = 1, 6 do sleep(1) io.write(".") end
		print(" byebye!")
		slot.packUpAll()
	end
	
	firstnSlots = function(slots)
		if type(slots) == 'number' then
			local s = {}
			for i = 1, slots do
				if const.needfuel then
					s[#s + 1] = i + 1
				else
					s[#s + 1] = i
				end
			end
			slots = s
		end
		return slots
	end
}

refuel = function(moves)
	moves = math.max(1, moves)
	if not (turtle.getItemCount(status.slots.fuel) > 1) then
		slot.packUp(status.slots.fuel)
	end
	while turtle.getFuelLevel() < moves and turtle.getItemCount(status.slots.fuel) > 1 do
		turtle.select(status.slots.fuel)
		turtle.refuel(1)
	end
	if not (turtle.getItemCount(status.slots.fuel) > 1) then
		print("More fuel needed !")
		slot.waitingForReloading(status.slots.fuel, 30)
	end
end

------------------------------advanced apis in move---------------------------------

move.to = function(dest, wm) 
	dest.x = withDefault(dest.x, status.pos.x)
	dest.y = withDefault(dest.y, status.pos.y)
	dest.z = withDefault(dest.z, status.pos.z)

	local p1 = {destroy = false force = false tryTime = 0}
	
	while status.posDis(dest, status.pos) > 0 do
		local moved = false
		for k, v in pairs(status.dif) do
			if status.posDis(dest, status.posAdd(status.pos, v)) < status.posDis(dest, status.pos) then
				moved = moved or move[k](p1)
				if moved then break end
			end
		end
		if not moved then
			for k, v in pairs(status.dif) do
				if status.posDis(dest, status.posAdd(status.pos, v)) < status.posDis(dest, status.pos) then
					moved = moved or move[k](wm)
					if moved then break end
				end
			end
		end
	end
	return true
end

move.go = function(destv, wm)
	return move.to(status.posAdd(status.pos, destv), wm)
end

function forceTryBack(msg)
	print (msg)
	move.to({x = 0, y = 0, z = 0}, {destroy = true, force = true, tryTime = 10000, autoRefuel = false, echo = const.debuging})
	status.turnTo('f')
	slot.packUpAll()
	error(string.format("FORCE BACK: %s", msg))
end


------------------------------recursive apis---------------------------------

search = function(deep, check, p)
	p = workMode.asDefault(p, true)
	p.withStart = withDefault(p.withStart, false)
	p.needBack = withDefault(p.needBack, true)
	p.allowFail = withDefault(p.allowFail, true)
	p.branch = withDefault(p.branch, true)
	p.append = withDefault(p.append, function () return true end)
	
	local function tryRun (fun, pa)
		if fun ~= nil then fun(unpack(pa)) end
	end
	
	local startPos = status.pos
	
	local function rec (d, dir)
		if d >= deep then
			return p.append(startPos, dir, d)
		end
		tryRun (p.beforeArrive, {startPos, dir, d})
		if not move[dir](p) then
			return false
		end
		tryRun (p.afterArrive, {startPos, dir, d})
		
		local r = true
		local branched = 0
		for i = 0, 5 do
			local next_dir = status.innerDirection[(status.numberedDirection[dir] + i) % 6]
			if check(startPos, next_dir, d) then
				if p.allowFail or r then
					if p.branch or branched == 0 then
						local ri = rec (d + 1, next_dir)
						if ri then
							branched = branched + 1
						end
					end
					r = r and ri
				end
			end
		end
		
		if p.needBack then
			tryRun (p.beforeLeave, {startPos, dir, d})
			if not move[status.negativeDirection[dir]](p) then
				forceTryBack('failed to backtrack')
			end	;
			tryRun (p.afterLeave, {startPos, dir, d})
		end
		return r
	end
	
	local r = true
	local branched = 0
	local d = -1
	if p.withStart then 
		d = 0
	end
	for i = 0, 5 do
		local next_dir = status.innerDirection[i]
		if check(startPos, next_dir, d) then
			if p.allowFail or r then
				if p.branch or branched == 0 then
					if p.withStart then 
						tryRun (p.afterArrive, {startPos, next_dir, d})
					end
					local ri = rec (d + 1, next_dir)
					if p.withStart then 
						tryRun (p.beforeLeave, {startPos, next_dir, d})
					end
					if ri then
						branched = branched + 1
					end
				end
				r = r and ri
			end
		end
	end
	return r
end

--------------------------------link function---------------------------

link = function(...)
	local p = deepcopy({...})
	local startPos = status.pos
	
	local bind = function(pi, fi, fj)
		local beforeLeave = pi.beforeLeave
		pi.beforeLeave = function(searchStartPos, searchDir, searchDeep)
			if pi.linked(searchStartPos, searchDir, searchDeep, startPos) then
				fj()
			end
			if beforeLeave ~= nil then
				beforeLeave(searchStartPos, searchDir, searchDeep)
			end
			return r
		end
		return pi
	end
	
	local f = {}
	
	if type(p[#p]) == 'function' then
		f[#p] = p[#p] p[#p] = nil
	else
		f[#p + 1] = function() return true end
	end
	
	for k, v in ipairs(p) do
		if not (type(p[k]) == "table") then
			error ("PARAM ERROR: api.link()")
		end
		f[k] = withParam(search, {p[k].deep, p[k].check, p[k]})
	end
	
	for k, v in ipairs(p) do
		p[k] = bind(p[k], f[k], f[k + 1])
	end
	
	local r = f[1]()
	return r
end

--------------------------------user tools---------------------------

scan = function (dir, times, p)
	p = workMode.asDefault(p, true)
	p.withStart = withDefault(p.withStart, true)
	p.step = withDefault(p.step, 1)
	p.first = withDefault(p.first, 0)
	
	p.deep = p.first + (times - 1) * p.step + 1
	p.branch = false
	p.check = function(searchStartPos, searchDir, searchDeep)
		return searchDir == dir
	end
	p.linked = function (searchStartPos, searchDir, searchDeep, startPos)
		local dis = status.posDis(status.pos, searchStartPos)
		return dis >= p.first and ((dis - p.first) % p.step) == 0
	end
	return p
end

cycle = function (dir, round, times, p)
	if type(times) == 'table' then
		p, times = times, p
	end
	p = workMode.asDefault(p, true)
	p.withStart = withDefault(p.withStart, true)
	p.first = withDefault(p.first, 0)
	p.last = withDefault(p.last, p.first + #round * times - 1)
	p.deep = p.last + 1
	p.branch = false
	p.check = function(searchStartPos, searchDir, searchDeep)
		return searchDir == dir
	end
	p.linked = function (searchStartPos, searchDir, searchDeep, startPos)
		local dis = status.posDis(status.pos, searchStartPos)
		if type(round) == 'table' then
			return round[dis % #round + 1] > 0
		else
			local c = string.char(string.byte(round, dis % #round + 1))
			return c ~= ' ' and c ~= '#'
		end
	end
	return p
end

go = function (x, y, z, p)
	local destv = false
	if type(x) == 'table' then
		destv, p = x, y
	else
		destv = pos(x, y, z)
	end
	p = workMode.asDefault(p, true)
	p.withStart = true
	p.deep = 0
	p.branch = false
	p.afterArrive = function()
		move.go(destv, p)
	end
	p.beforeLeave = function(searchStartPos)
		move.to(searchStartPos)
	end
	p.check = function() return true end
	p.linked = function() return true end
	return p
end

digLine = function (dir, maxdis, p)
	p = workMode.asDefault(p, {destroy = true})
	p.withStart = withDefault(p.withStart, true)
	
	p.deep = withDefault(maxdis, 100)
	p.branch = false
	p.check = function(searchStartPos, searchDir, searchDeep)
		if searchDir ~= dir then return false end
		if detect[searchDir]() then
			dig[searchDir]()
			return searchDeep + 1 < r.deep
		end
		return false
	end
	p.linked = function (searchStartPos, searchDir, searchDeep, startPos)
		return false
	end
	return p
end

digAll = function (slots, maxdis, p)
	p = workMode.asDefault(p, {destroy = true})
	p.withStart = withDefault(p.withStart, true)
	local tmp = slot.firstnSlots(slots)
	slots = tmp
	
	p.deep = withDefault(maxdis, 100)
	p.branch = true
	p.check = function(searchStartPos, searchDir, searchDeep)
		for k, v in ipairs(slots) do
			if compare[searchDir](v) then
				dig[searchDir]()
				return searchDeep + 1 < p.deep
			end
		end
		return false
	end
	p.linked = function (searchStartPos, searchDir, searchDeep, startPos)
		return false
	end
	return p
end

digExcept = function (slots, maxdis, p)
	local tmp = slot.firstnSlots(slots)
	slots = tmp
	
	local r = digAll(slots, maxdis, p)
	r.check = function(searchStartPos, searchDir, searchDeep)
		if detect[searchDir]() then
			for k, v in ipairs(slots) do
				if compare[searchDir](v) then
					return false
				end
			end
			dig[searchDir]()
			return searchDeep + 1 < r.deep
		else
			return false
		end
	end
	return r
end

pos = function(a, b, c)
	return {x = a, y = b, z = c}
end


----------------------- main coroutine ----------------------

st_main = function()
end

begin = function (...)
	parallel.waitForAll(st_main, ...)
end


---------------------------------------------------------------------


function withWirelessModem(proc)
	for _, mSide in ipairs( peripheral.getNames() ) do
		if peripheral.getType( mSide ) == "modem" then
			local modem = peripheral.wrap( mSide )
			if modem.isWireless() then
				print("found wireless modem: " .. mSide)
				rednet.open(mSide)
				proc(modem)
				rednet.close(mSide)
			end
		end
	end
end

function run_puppet()
	while true do
		local senderId, msg, _ = rednet.receive("puppet")
		print("Command from " .. senderId .. ": " .. msg)
		if msg == "exit" then
			break
		elseif msg == "f" then
			move.f()
		elseif msg == "b" then
			move.b()
		elseif msg == "l" then
			move.l()
		elseif msg == "r" then
			move.r()
		elseif msg == "u" then
			move.u()
		elseif msg == "d" then
			move.d()
		else
			func, err = load("return "..msg, "remote_cmd", "t", _ENV)
			if func then
				ok, res = pcall(func)
				print(res)
			else
				print(err)
			end
		end
	end
end

function run_puppeteer(cmd)
	rednet.broadcast(cmd, "puppet")
end

function getPos()
	local fx, fz, fy = gps.locate()
	local x, y, z = math.floor(fx), math.floor(fy), math.floor(fz)
	return pos(x, -y, z)
end

args = {...}
withWirelessModem(function ()
	if turtle ~= nil and #args == 0 then
		run_puppet()
	elseif turtle == nil and #args == 1 then
		local cmd = args[1]
		if cmd == "follow" then
			local p0 = getPos()
			while true do
				sleep(0.1)
				local p1 = getPos()
				if status.posDis(p0, p1) > 0 then
					local v = status.posDif(p1, p0)
					run_puppeteer("move.go({x = "..v.x..", y = "..v.y..", z = "..v.z.."})")
					p0 = p1
				end
			end
		else
			run_puppeteer(cmd)
		end
	else
		print("usage: puppet [cmd]")
	end
end)
--lua
os.loadAPI('lc/api') for k, v in pairs(api) do loadstring(string.format("%s = api.%s", k, k))() end

slots = {
	[1] = {"fuel"}
}
slot.checkList(slots, 1)


-----------------------
--
--
--
miner = function(slots, forwardDis, digDis)
	workMode.destroy = true
	workMode.force = true
	workMode.tryTime = 30

	f = function()
		if (status.pos.y - status.pos.z * 2 + 100) % 5 == 0 then
			link(scan('f', forwardDis), digExcept(slots, digDis))
		end
	end
	link(scan('l', 6), scan('u', 6), f)
	status.turnTo('f')
	slot.packUpAll()
end

args = {...}
if #args < 1 or #args > 3 then
	print("useage: miner slots [forwardDis] [digDis]")
else
	for k, v in ipairs(args) do
		args[k] = tonumber(v)
	end
	if #args == 1 then
		miner(args[1], 100, 1)
	elseif #args == 2 then
		miner(args[1], args[2], 1)
	elseif #args == 3 then
		miner(args[1], args[2], args[3])
	end
end

