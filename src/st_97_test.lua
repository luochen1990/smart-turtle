------------------------------------ tests -------------------------------------

_test = {}

if true then
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
		return app.clearBlock((O+U*3)..(O+U+(F+R)*2))()
	end))

	_test.buildFrame = markIO("_test.buildFrame")(mkIO(function()
		return app.buildFrame((O+U..O+U):expand(1))()
	end))

	_test.pinnedSlot = markIO("_test.pinnedSlot")(mkIO(function()
		local det = retry(mkIO(turtle.getItemDetail, 1))()
		local pinnedSlot = {
			[1] = {
				itemType = det.name,
				stackLimit = slot.stackLimit(1),
				depot = {pos = O, dir = B},
			}
		}
		return with({pinnedSlot = pinnedSlot})(_test.scan)()
	end))

	_test.transportLine = markIO("_test.transportLine")(mkIO(function()
		local s = {pos = O + L * 2 + F * 2 + U * 3, dir = R}
		local t = {pos = O + R * 4 + U, dir = L}
		;(recover(s) * use("minecraft:chest"))()
		;(recover(t) * use("minecraft:chest"))()
		return app.transportLine(s, t)()
	end))

	_test.requestStation = markIO("_test.requestStation")(mkIO(function()
		return _requestSwarm("swarm.services.requestStation("..literal("minecraft:charcoal", 0, workState.pos, turtle.getFuelLevel())..")")
	end))

	_test.race = mkIO(function()
		print("this perf test is for comparing turtle move speed between raw api and st api")
		print("Usage:")
		print(" _test.race.raw -- use the raw api to move 10 steps and return back")
		print(" _test.race.st -- use the st api to move 10 steps and return back")
		print(" _test.race.begin -- begin racing, you can use a pocket computer to execute it")
	end)

	_test.race.begin = mkIO(function()
		rednet.broadcast("begin", "_test.race")
	end)

	_test.race._wrap = mkIOfn(function(label, coreProc)
		local old_label = os.getComputerLabel()
		os.setComputerLabel(label)
		print("[race] waiting for begin signal")
		local senderId, msg = rednet.receive("_test.race")
		print("[race] got msg from "..senderId..": "..msg)
		local beginTime = os.clock()
		coreProc()
		print("[race] finished in "..(os.clock() - beginTime).." seconds")
		os.setComputerLabel(old_label)
	end)

	if turtle then
		_test.race.st = _test.race._wrap("st-turtle", savePosd(move ^ 10))
		_test.race.raw = _test.race._wrap("raw-turtle", function()
			for trip = 1, 2 do
				for step = 1, 10 do
					turtle.forward()
				end
				turtle.turnLeft()
				turtle.turnLeft()
			end
		end)
	end

end

