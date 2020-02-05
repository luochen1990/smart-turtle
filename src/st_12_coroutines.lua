------------------------------- main coroutines --------------------------------

gpsPos = mkIO(function()
	x, y, z = gps.locate()
	if x then return vec(x, y, z) else return nil end
end)

initWorkState = function()
	(rep(dig) * use("minecraft:chest"))()
	local ok, r = turtle.inspect()
	assert(ok, "failed to get facing direction (inspect failed)")
	workState.facing = -const.dir[r.state.facing:sub(1,1):upper()]
	assert(workState.facing.y == 0, "failed to get facing direction (not a horizontal direction)")
	turtle.dig()
	workState.pos = gpsPos()
	assert(workState.pos ~= nil, "failed to get gps location!")
	workState.beginPos = workState.pos
	saveDir(turn.left * use("minecraft:chest"))()
end

main = function()
end

begin = function (...)
	parallel.waitForAll(main, ...)
end

