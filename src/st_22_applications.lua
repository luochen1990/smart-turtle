--------------------------------- applications ---------------------------------

app = {}

app.buildBox = markIOfn("app.buildBox(area)")(mkIOfn(function(area)
	if vec.isVec(area) then
		area = workState.pos .. (workState.pos + area)
	end
	assert(isArea(area), "[app.buildBox] please provide an area, like p1..p2")

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

app.buildFrame = markIOfn("app.buildFrame(n)")(mkIOfn(function(n)
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

app.flatGround = markIOfn("app.flatGround(area,depth)")(mkIOfn(function(area, depth)
	if vec.isVec(area) then
		area = workState.pos .. workState.pos + area
	end
	assert(isArea(area), "[app.flatGround] please provide an area, like p1..p2")

	depth = default(1)(depth)
	buildFloor = currentPos:pipe(function(p) return scan(p .. p + D * (depth-1), U)(turn.D * place) end)
	return savePosp(with({destroy = true})(scan(area)(buildFloor * turn.U * rep(dig * move))))()
end))

app.plant = markIO("app.plant")(mkIO(function()
	local ripen = retryUntil(isNamed("*:*_log"))(use("minecraft:bone_meal"))
	local cutTrunk = dig * move * turn.U * rep(dig * move)
	local cutLeaf = currentPos:pipe(function(p)
		return with({destroy = true})(scan(p+(D+F+L)*2 .. p+(D+B+R)*2, D, 3)(try(turn.U * dig) * turn.D * dig))
	end)
	local needSapling = mkIO(function() return slot.count("*:*_sapling") < 10 end)
	return savePosd((isNamed("*:*_log") + (isNamed("*:*_sapling") + use("*:*_sapling")) * ripen) * cutTrunk * try(needSapling * cutLeaf))()
end))

app.miner = markIOfn("app.miner")(mkIOfn(function(n)
	n = math.max(1, n or 1)
	return savePosp(scan(O .. (O + (R + F) * (n-1)), D)(turn.D * rep(try(dig) * move)))()
end))

app.clearBlock = markIOfn("app.clearBlock")(mkIOfn(function(area)
	if vec.isVec(area) then
		area = workState.pos .. workState.pos + area
	end
	assert(isArea(area), "[app.clearBlock] please provide an area, like p1..p2")

	return savePosp( with({destroy = true})( scan(area, D, 3)(try(turn.U * dig) * (turn.D * dig)) ) )()
end))

