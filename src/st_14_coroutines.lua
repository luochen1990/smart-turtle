------------------------------- main coroutines --------------------------------

F, B, L, R, O = nil, nil, nil, nil, nil
_initWorkState = function()
	if not (rep(attack) * rep(dig) * use("minecraft:chest"))() then error("[_initWorkState] please give me a chest") end
	local ok, res = turtle.inspect()
	if not ok then error("[_initWorkState] failed to get facing direction (inspect failed)") end
	workState.facing = -const.dir[res.state.facing:sub(1,1):upper()]
	F, B, L, R = workState.facing, -workState.facing, leftSide(workState.facing), rightSide(workState.facing)
	for _, d in ipairs({"F", "B", "L", "R"}) do turn[d] = turn.to(_ENV[d]) end
	turtle.dig()
	-- got facing
	workState.pos = gpsPos()
	if workState.pos == nil then error("[_initWorkState] failed to get gps location!") end
	workState.beginPos = workState.pos
	O = workState.beginPos
	-- got pos
	ok = saveDir(turn.left * try(use("minecraft:chest")) * isChest)()
	if not ok then error("[_initWorkState] failed to set fuelStation") end
	workMode.fuelStation = {pos = workState.pos, dir = L}
	-- got fuelStation
end

_mainCo = function()
end

_test = {}

--_replCo = function()
--	os.run(_ENV, "/rom/programs/lua.lua")
--end

begin = function(...)
	_initWorkState()
	if math.random() < 0.1 then _test.move() end
	parallel.waitForAll(_mainCo, _replCo, _printCallStackCo, ...)
end

------------------------------------ tests -------------------------------------

v1 = vec(1,0,0)
v2 = vec(0,1,0)
v3 = vec(0,0,1)

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
	return transportLine({pos = vec(14,6,195), dir = W}, {pos = vec(8,6,193), dir = E})()
end))

--------------------------------------------------------------------------------

begin()

