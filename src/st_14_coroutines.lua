------------------------------- main coroutines --------------------------------

if turtle then

	-- | provide current real pos and facing dir to correct the coordinate system
	_correctCoordinateSystem = markFn("_correctCoordinateSystem(pos, facing)")(function(pos, facing)
		assert(pos and pos.x, "[_correctCoordinateSystem(pos, facing)] pos must be a vector, but got"..tostring(pos))
		assert(facing and facing.y == 0 and manhat(facing) == 1, "[_correctCoordinateSystem(pos, facing)] facing must be a dir"..tostring(facing))
		local oldpos, olddir = workState.pos, workState.facing
		local offset = pos - oldpos -- use this to correct all locally maintained positions
		local dirOffset = facing ^ olddir
		workState.beginPos = (workState.beginPos % dirOffset) + offset
		O = workState.beginPos
		workState.pos = pos
		workState.facing = facing
		F, B, L, R = facing, -facing, leftSide(facing), rightSide(facing)
		for _, d in ipairs({"F", "B", "L", "R"}) do turn[d] = turn.to(_ENV[d]) end
		return true
	end)

	_correctCoordinateSystemWithGps = markFn("_correctCoordinateSystemWithGps")(function()
		local p0 = retry(5)(gpsPos)()
		if not p0 then
			printC(colors.orange)("[_correctCoordinateSystemWithGps] make sure you have wireless modem and gps station nearby")
			return false
		end
		printC(colors.gray)("turtle pos = "..tostring(p0))
		if turtle.getFuelLevel() < 2 then
			printC(colors.orange)("[_correctCoordinateSystemWithGps] please refuel me")
			return false
		end
		local succ = retry(5)(turtle.back)()
		if not succ then
			printC(colors.orange)("[_correctCoordinateSystemWithGps] cannot move back, please help to clean the road")
			return false
		end
		local p1 = retry(5)(gpsPos)()
		if not p1 then
			printC(colors.orange)("[_correctCoordinateSystemWithGps] no gps signal here, please try somewhere else")
			repeat turtle.dig(); turtle.attack() until ( turtle.forward() )
			return false
		end
		repeat turtle.dig(); turtle.attack() until ( turtle.forward() )
		local d = p0 - p1
		if manhat(d) ~= 1 then
			printC(colors.gray)("p0 = "..tostring(p0))
			printC(colors.gray)("p1 = "..tostring(p1))
			printC(colors.gray)("p0 - p1 = "..tostring(d))
			printC(colors.orange)("[_correctCoordinateSystemWithGps] weird gps positoin, please check your gps server")
			return false
		end
		printC(colors.gray)("turtle facing = "..showDir(d))
		return _correctCoordinateSystem(p0, d)
	end)

	_initTurtleState = markFn("_initTurtleState")(function()
		local succ = _correctCoordinateSystemWithGps()
		if not succ then
			printC(colors.orange)("[_initTurtleState] WARN: failed to get gps pos and dir!")
		end
		workState.fuelStation = default(workState.fuelStation)(requestFuelStation())
		if not workState.fuelStation then
			printC(colors.orange)("[_initTurtleState] WARN: failed to get fuelStation!")
		end
		workState.unloadStation = default(workState.fuelStation)(requestUnloadStation())
		if not workState.unloadStation then
			printC(colors.orange)("[_initTurtleState] WARN: failed to get unloadStation!")
		end
		return not not (succ and workState.fuelStation and workState.unloadStation)
	end)

	_initTurtleStateWithChest = function()
		if not (rep(attack) * rep(dig) * use("minecraft:chest"))() then error("[_initTurtleState] please give me a chest") end
		local ok, res = turtle.inspect()
		if not ok then error("[_initTurtleState] failed to get facing direction (inspect failed)") end
		workState.facing = -const.dir[res.state.facing:sub(1,1):upper()]
		F, B, L, R = workState.facing, -workState.facing, leftSide(workState.facing), rightSide(workState.facing)
		for _, d in ipairs({"F", "B", "L", "R"}) do turn[d] = turn.to(_ENV[d]) end
		turtle.dig()
		-- got facing
		workState.pos = gpsPos()
		if workState.pos == nil then error("[_initTurtleState] failed to get gps location!") end
		workState.beginPos = workState.pos
		O = workState.beginPos
		-- got pos
		ok = saveDir(turn.left * try(use("minecraft:chest")) * isChest)()
		if not ok then error("[_initTurtleState] failed to set fuelStation") end
		workState.fuelStation = {pos = workState.pos, dir = L}
		-- got fuelStation
		if DEBUG and math.random() < 0.1 then _test.move() end
	end
end

_mainCo = function()
end

_test = {}

--_replCo = function()
--	os.run(_ENV, "/rom/programs/lua.lua")
--end

begin = function(...)
	term.clear(); term.setCursorPos(1,1)
	if turtle then _initTurtleState() end
	parallel.waitForAll(_mainCo, _replCo, _printCallStackCo, ...)
end

------------------------------------ tests -------------------------------------

if turtle and DEBUG then
	_test.move = markIO("_test.move")(mkIO(function()
		return savePosd(move.go(leftSide(workState.facing) * 2))()
	end))

	_test.scan = markIO("_test.scan")(mkIO(function()
		return savePosd(scan(O .. (O + (U + R + F) * 2), D)(turn.U * try(dig) * place))()
	end))

	_test.scan2d = markIO("_test.scan2d")(mkIO(function()
		return savePosd(_scan2d(O .. (O + (R + F) * 2))(turn.U * try(dig) * place))()
	end))

	_test.transportLine = markIO("_test.transportLine")(mkIO(function()
		local s = {pos = O + L * 2 + F * 2 + U * 3, dir = R}
		local t = {pos = O + R * 4 + U, dir = L}
		;(visitStation(s) * use("minecraft:chest"))()
		;(visitStation(t) * use("minecraft:chest"))()
		return transportLine(s, t)()
	end))

	_test.transportLineTemp = markIO("_test.transportLineTemp")(mkIO(function()
		local s = {pos = vec(188, 65, 27), dir = S}
		local t = {pos = vec(197, 69, -70), dir = N}
		return transportLine(s, t)()
	end))
end

--------------------------------------------------------------------------------

begin()

