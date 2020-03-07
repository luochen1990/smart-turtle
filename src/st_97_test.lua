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
		return with({destroy = false, workArea = (O + (L + D) * 1000) .. (O + (R + U) * 1000)})(savePosp(move.go(L * 2 + U * 17)))()
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

	_test.buildFrame = markIOfn("_test.buildFrame")(mkIOfn(function(n)
		print("n =", n)
		local vs = {F * n, R * n, U * n}
		print("1")
		local P = O + U + F
		print("2")
		local Q = P + (F + R + U) * n
		print("3")
		local lines = {}
		for _, v in ipairs(vs) do
			print(v)
			table.insert(lines, P..P+v)
			table.insert(lines, Q..Q-v)
			for _, v2 in ipairs(vs) do
				if v2 ~= v then
					table.insert(lines, P+v..P+v+v2)
				end
			end
		end
		print("4")
		table.sort(lines, comparator(field("low", "y"), field("high", "y")))
		print("lines", literal(lines))
		for _, line in ipairs(lines) do
			scan(line, U)(turn.D * place)()
		end
		print("5")
		move.to(O)()
		turn.to(F)()
		return true
	end))

	_test.flatGround = markIOfn("_test.flatGround(area,depth)")(mkIOfn(function(area, depth)
		if vec.isVec(area) then
			area = workState.pos .. workState.pos + area
		end
		if not isArea(area) then
			print("[flatGround] please provide an area, like p1..p2")
		end
		depth = default(1)(depth)
		buildFloor = currentPos:pipe(function(p) return scan(p .. p + D * (depth-1), U)(place) end)
		return savePosp(scan(area)(buildFloor * turn.U * rep(dig * move)))()
	end))

	_test.miner = markIOfn("_test.miner")(mkIOfn(function(n)
		n = math.max(1, n or 1)
		return savePosp(scan(O .. (O + (R + F) * (n-1)), D)(turn.D * rep(try(dig) * move)))()
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

