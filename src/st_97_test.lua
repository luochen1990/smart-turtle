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
		return with({workArea = (O + (L + D) * 1000) .. (O + (R + U) * 1000)})(savePosp(move.go(L * 2 + U * 17)))()
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

	_test.buildBox = markIOfn("_test.buildBox(area)")(mkIOfn(function(area)
		if vec.isVec(area) then
			area = workState.pos .. (workState.pos + area)
		end
		assert(isArea(area), "[buildBox] please provide an area, like p1..p2")

		local area1 = (area.low - vec.one) .. (area.high + vec.one)
		local tasks = {}
		for _, d in pairs(const.dir) do
			local face = area1:face(d)
			local a = (face.low + d) .. (face.high + d)
			table.insert(tasks, {area = a, exec = scan(a)(turn.to(-d) * (compare + try(dig) * place))})
		end

		local old_posp = getPosp()
		while #tasks > 0 do
			local pos = currentPos()
			local dis = function(t) return vec.manhat(t.area:vertexNear(pos) - pos) end
			table.sort(tasks, comparator(field("area", "low", "y"), field("area", "high", "y"), dis))
			local task = table.remove(tasks, 1)
			task.exec()
		end
		recoverPosp(old_posp)()
		return true
	end))

	_test.buildFrame = markIOfn("_test.buildFrame(n)")(mkIOfn(function(n)
		local vs = {F * n, R * n, U * n}
		local P = O + U + F
		local Q = P + (F + R + U) * n
		local lines = {}
		for _, v in ipairs(vs) do
			table.insert(lines, P..P+v)
			table.insert(lines, Q..Q-v)
			for _, v2 in ipairs(vs) do
				if v2 ~= v then
					table.insert(lines, P+v..P+v+v2)
				end
			end
		end
		table.sort(lines, comparator(field("low", "y"), field("high", "y")))
		print("lines", literal(lines))
		for _, line in ipairs(lines) do
			scan(line, U)(turn.D * place)()
		end
		move.to(O)()
		turn.to(F)()
		return true
	end))

	_test.flatGround = markIOfn("_test.flatGround(area,depth)")(mkIOfn(function(area, depth)
		if vec.isVec(area) then
			area = workState.pos .. workState.pos + area
		end
		assert(isArea(area), "[flatGround] please provide an area, like p1..p2")

		depth = default(1)(depth)
		buildFloor = currentPos:pipe(function(p) return scan(p .. p + D * (depth-1), U)(turn.D * place) end)
		return savePosp(with({destroy = true})(scan(area)(buildFloor * turn.U * rep(dig * move))))()
	end))

	_test.plant = markIO("_test.plant")(mkIO(function()
		local ripen = retryUntil(isNamed("*:*_log"))(use("minecraft:bone_meal"))
		local cutTrunk = dig * move * turn.U * rep(dig * move)
		local cutLeaf = currentPos:pipe(function(p)
			return with({destroy = true})(scan(p+(D+F+L)*2 .. p+(D+B+R)*2, D, 3)(try(turn.U * dig) * turn.D * dig))
		end)
		return savePosd((isNamed("*:*_log") + (isNamed("*:*_sapling") + use("*:*_sapling")) * ripen) * cutTrunk * cutLeaf)()
	end))

	_test.miner = markIOfn("_test.miner")(mkIOfn(function(n)
		n = math.max(1, n or 1)
		return savePosp(scan(O .. (O + (R + F) * (n-1)), D)(turn.D * rep(try(dig) * move)))()
	end))

	_test.clearBlock = markIOfn("_test.clearBlock")(mkIOfn(function(area)
		if vec.isVec(area) then
			area = workState.pos .. workState.pos + area
		end
		assert(isArea(area), "[clearBlock] please provide an area, like p1..p2")

		return savePosp( with({destroy = true})( scan(area, D, 3)(try(turn.U * dig) * (turn.D * dig)) ) )()
	end))

	_test.clearBlock1 = markIO("_test.clearBlock1")(mkIO(function()
		return _test.clearBlock((O+U*2)..(O+(U+F+R)*2))()
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

