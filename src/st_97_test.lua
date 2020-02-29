------------------------------------ tests -------------------------------------

_test = {}

if turtle then
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

	_test.requestStation = markIO("_test.requestStation")(mkIO(function()
		return _requestSwarm("swarm.services.requestStation("..literal("minecraft:charcoal", 0, workState.pos, turtle.getFuelLevel())..")")
	end))
end

