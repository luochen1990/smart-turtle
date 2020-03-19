------------------------------------ tests -------------------------------------

_test = {}

if turtle then
	_test.move = markIO("_test.move")(mkIO(function()
		return savePosp(move.go(L * 2))()
	end))

	_test.move2 = markIO("_test.move2")(mkIO(function()
		return savePosp(move.go(F + L))()
	end))

	_test.move3 = markIO("_test.move3")(mkIO(function()
		return savePosp(move.go(F + R))()
	end))

	_test.moveVertical = markIO("_test.moveVertical")(mkIO(function()
		return with({workArea = (O + (L + D) * 1000) .. (O + (R + U) * 1000)})(savePosp(move.go(L * 2)))()
	end))

	_test.maze = markIO("_test.maze")(mkIO(function()
		return with({workArea = (O + L * 100) .. (O + R * 100 + U * 17)})(savePosp(move.go(L * 2 + U * 17) / mkIO(sleep, 10)))()
	end))

	_test.scan = markIO("_test.scan")(mkIO(function()
		return savePosp(scan(O .. (O + (U + R + F) * 2), D)(turn.U * try(dig) * place))()
	end))

	_test.scan2d = markIO("_test.scan2d")(mkIO(function()
		return savePosp(scan(O .. (O + (R + F) * 2))(turn.U * try(dig) * place))()
	end))

	_test.scan2dU = markIO("_test.scan2dU")(mkIO(function()
		return savePosp(scan(O .. (O + (R + U) * 2), D)(turn.U * try(dig) * place))()
	end))

	_test.scan1d = markIO("_test.scan1d")(mkIO(function()
		return savePosp(scan(O .. (O + F * 2))(turn.U * try(dig) * place))()
	end))

	_test.scan0d = markIO("_test.scan0d")(mkIO(function()
		return savePosp(scan(O .. O)(turn.U * try(dig) * place))()
	end))

	_test.clearBlock = markIO("_test.clearBlock")(mkIO(function()
		return app.clearBlock((O+U*2)..(O+(U+F+R)*2))()
	end))

	_test.buildFrame = markIO("_test.buildFrame")(mkIO(function()
		return app.buildFrame((O+U..O+U):expand(1))()
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

