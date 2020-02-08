------------------------------- main coroutines --------------------------------

if turtle then
	F, B, L, R, O = nil, nil, nil, nil, nil
	_initTurtleState = function()
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
		workMode.fuelStation = {pos = workState.pos, dir = L}
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
end

--------------------------------------------------------------------------------

begin()

