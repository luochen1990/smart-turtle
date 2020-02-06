------------------------------- main coroutines --------------------------------

F, B, L, R, O = nil, nil, nil, nil, nil
initWorkState = function()
	if not (rep(dig) * use("minecraft:chest"))() then error("[initWorkState] please give me a chest") end
	local ok, res = turtle.inspect()
	if not ok then error("[initWorkState] failed to get facing direction (inspect failed)") end
	workState.facing = -const.dir[res.state.facing:sub(1,1):upper()]
	turtle.dig()
	workState.pos = gpsPos()
	if workState.pos == nil then error("[initWorkState] failed to get gps location!") end
	workState.beginPos = workState.pos
	saveDir(turn.left * use("minecraft:chest"))() --NOTE: not used yet
	F, B, L, R = workState.facing, -workState.facing, leftSide(workState.facing), rightSide(workState.facing)
	for _, d in ipairs({"F", "B", "L", "R"}) do turn[d] = turn.to(_ENV[d]) end
	O = workState.beginPos
end

main = function()
end

begin = function (...)
	parallel.waitForAll(main, ...)
end

