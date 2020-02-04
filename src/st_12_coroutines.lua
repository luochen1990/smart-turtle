------------------------------- main coroutines --------------------------------

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

