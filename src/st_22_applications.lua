--------------------------------- applications ---------------------------------

toArea = function(areaDesc)
	if isArea(areaDesc) then return areaDesc
	elseif vec.isVec(areaDesc) then return workState.pos .. workState.pos + areaDesc
	else error("[toArea] please provide an area, like p1..p2 ") end
end

app = {}
help.app = doc("sub-command of app is useful applications, choose one sub-command for more details")

help.app.buildBox = doc({
	signature = "app.buildBox : Area -> IO Bool",
	usage = "app.buildBox(p1 .. p2)()",
	desc = "build a box wrapping the target area",
})
app.buildBox = markIOfn("app.buildBox(area)")(mkIOfn(function(area)
	area = toArea(area)

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

help.app.buildFrame = doc({
	signature = "app.buildFrame : Area -> IO Bool",
	usage = "app.buildFrame(p1 .. p2)()",
	desc = "build a frame inside the target area",
})
app.buildFrame = markIOfn("app.buildFrame(area)")(mkIOfn(function(area)
	local frame = toArea(area)
	local lines = {}
	for _, v in ipairs(vec.components(frame.diag)) do
		table.insert(lines, frame.low .. (frame.low + v))
		table.insert(lines, frame.high .. (frame.high - v))
		for _, v2 in ipairs(vec.components(frame.diag)) do
			if v2 ~= v then
				table.insert(lines, (frame.low + v) .. (frame.low + v + v2))
			end
		end
	end
	local old_posp = getPosp()
	while #lines > 0 do
		local pos = currentPos()
		local dis = function(line) return vec.manhat(line:vertexNear(pos) - pos) end
		table.sort(lines, comparator(field("low", "y"), field("high", "y"), dis))
		local line = table.remove(lines, 1)
		scan(line:shift(U), U)(turn.D * place)()
	end
	recoverPosp(old_posp)()
	return true
end))

help.app.flatGround = doc({
	signature = "app.flatGround : (Area, Int?) -> IO Bool",
	usage = {
		"app.flatGround(p1 .. p2)()",
		"app.flatGround(p1 .. p2, thickness)()",
	},
	desc = "flat an area, dig all connected things above this area, and build a floor",
})
app.flatGround = markIOfn("app.flatGround(area,thickness)")(mkIOfn(function(area, thickness)
	area = toArea(area)
	thickness = default(1)(thickness)
	buildFloor = currentPos:pipe(function(p) return scan(p .. p + D * (thickness-1), U)(turn.D * place) end)
	return savePosp(with({destroy = true})(scan(area)(buildFloor * turn.U * rep(dig * move))))()
end))

help.app.plant = doc({
	signature = "app.plant : IO Bool",
	usage = "app.plant()",
	desc = "plant a tree and cut it to get wood, need bone_meal to ripen the tree",
})
app.plant = markIO("app.plant")(mkIO(function()
	local pinnedSlot = askForPinnedSlot({
		[1] = {desc = "sapling", itemFilter = glob("*:*_sapling"), depot = {pos = O+R, dir = B}},
		[2] = {desc = "bone_meal", itemFilter = glob("minecraft:bone_meal"), depot = {pos = O+R*2, dir = B}},
	})
	local ripen = retryUntil(isNamed("*:*_log"))(use(2))
	local cutTrunk = dig * move * turn.U * rep(dig * move)
	local cutLeaf = currentPos:pipe(function(p)
		return with({destroy = true})(scan(p+(D+F+L)*2 .. p+(D+B+R)*2, D, 3)(try(turn.U * dig) * turn.D * dig))
	end)
	local needSapling = mkIO(function() return slot.count("*:*_sapling") < 10 end)
	local plant = (isNamed("*:*_log") + (isNamed("*:*_sapling") + use(1)) * ripen) * cutTrunk * try(needSapling * cutLeaf)
	return rep(savePosd(with({pinnedSlot = pinnedSlot})(plant)))()
end))

help.app.mine = doc({
	signature = "app.mine : Area -> IO Bool",
	usage = "app.mine(p1 .. p2)()",
	desc = "mine an area to get ore, dig 1/3 layers",
})
app.mine = markIOfn("app.mine")(mkIOfn(function(area)
	area = toArea(area)
	local a1 = area:shift(D) --TODO: more precise area downside boundary
	local digOre = isNamed("*:*_ore") * dig
	return savePosp( with({destroy = true})( scan(a1, D, 3)(try(turn.U * digOre) * (turn.D * digOre)) ) )()
end))

help.app.clearBlock = doc({
	signature = "app.clearBlock : Area -> IO Bool",
	usage = "app.clearBlock(p1 .. p2)()",
	desc = "clear an area, dig all blocks and discard not-valuable items",
})
app.clearBlock = markIOfn("app.clearBlock")(mkIOfn(function(area)
	area = toArea(area)
	local a1 = area:shift(D) --TODO: more precise area downside boundary
	return savePosp( with({destroy = true})( scan(a1, D, 3)(try(turn.U * dig) * (turn.D * dig)) ) )()
end))

