------------------------------------ tests -------------------------------------

_test = {}

if turtle then
	_test.move = markIO("_test.move")(mkIO(function()
		return saveState(move.go(leftSide(workState.facing) * 2))()
	end))

	_test.scan = markIO("_test.scan")(mkIO(function()
		return saveState(scan(O .. (O + (U + R + F) * 2), D)(turn.U * try(dig) * place))()
	end))

	_test.scan2d = markIO("_test.scan2d")(mkIO(function()
		return saveState(_scan2d(O .. (O + (R + F) * 2))(turn.U * try(dig) * place))()
	end))

	_test.miner = markIOfn("_test.miner")(mkIOfn(function(n)
		n = math.max(1, n or 1)
		return saveState(scan(O .. (O + (R + F) * (n-1)), D)(turn.D * rep(try(dig) * move)))()
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

