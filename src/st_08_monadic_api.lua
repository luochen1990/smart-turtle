--------------------------------- Monadic API ----------------------------------

turn = {
	left = markIO("turn.left")(mkIO(function() turtle.turnLeft(); workState.facing = leftSide(workState.facing); return true end)),
	right = markIO("turn.right")(mkIO(function() turtle.turnRight(); workState.facing = rightSide(workState.facing); return true end)),
	back = markIO("turn.back")(mkIO(function() turtle.turnLeft(); turtle.turnLeft(); workState.facing = -workState.facing; return true end)),
}
turn.to = markIOfn("turn.to(d)")(mkIOfn(function(d)
	assert(d and ((d.x and d.y and d.z) or (d.run)), "[turn.to(d)] d must be a vector (or IO vector)!")
	if d.run then d = d.run() end -- in case d is IO vector
	assert(math.abs(d.x + d.y + d.z) == 1 and d:length() == 1, "[turn.to(d)] d must be a dir, i.e. E/S/W/N/U/D")
	workState.aiming = d.y
	if d == workState.facing then return true
	elseif d == -workState.facing then return turn.back()
	elseif d == leftSide(workState.facing) then return turn.left()
	elseif d == rightSide(workState.facing) then return turn.right()
	else return true end
end))
turn.lateral = markIO("turn.lateral")(mkIO(function() return turn.to(workState:lateralDir()) end))
for k, v in pairs(const.dir) do turn[k] = turn.to(v) end

currentPos = mkIO(function() return workState.pos end)
currentDir = mkIO(function() return workState:aimingDir() end)

saveDir = markIOfn("saveDir(io)")(function(io)
	return mkIO(function()
		local saved_facing = workState.facing
		local saved_aiming = workState.aiming
		local r = {io()}
		turn.to(saved_facing)()
		workState.aiming = saved_aiming
		return unpack(r)
	end)
end)

_wrapAimingSensitiveApi = function(apiName, wrap, rawApis)
	if rawApis == nil then rawApis = {turtle[apiName..'Up'], turtle[apiName], turtle[apiName..'Down']} end
	assert(#rawApis >= 3, "[init _aiming."..apiName.."] three rawApis must be provided")
	return wrap(markFunc("_aiming."..apiName)(function(...)
		assert(workState.aiming and workState.aiming >= -1 and workState.aiming <= 1, "[_aiming."..apiName.."] workState.aiming must be 0/1/-1")
		local rawApi = rawApis[2 - workState.aiming]
		return rawApi(...)
	end))
end

-- | these are lightweight wrapped apis
-- , which read workState.facing and workState.aiming to decide which raw api to use
-- , but doesn't change workState
_aiming = {
	move = _wrapAimingSensitiveApi("move", mkIO, {turtle.up, turtle.forward, turtle.down}),
	dig = _wrapAimingSensitiveApi("dig", mkIO),
	place = _wrapAimingSensitiveApi("place", mkIO),
	detect = _wrapAimingSensitiveApi("detect", mkIO),
	inspect = _wrapAimingSensitiveApi("inspect", mkIO),
	compare = _wrapAimingSensitiveApi("compare", mkIO),
	attack = _wrapAimingSensitiveApi("attack", mkIO),
	suck = _wrapAimingSensitiveApi("suck", mkIOfn),
	drop = _wrapAimingSensitiveApi("drop", mkIOfn),
}

detect = _aiming.detect
compare = _aiming.compare
attack = _aiming.attack
drop = _aiming.drop

suck = markIOfn("suck(n)")(mkIOfn(function(n)
	return (reserveSlot * _aiming.suck(n))()
end))

-- | different from turtle.inspect, this only returns res
inspect = markIO("inspect")(mkIO(function()
	ok, res = _aiming.inspect()
	return ok and res
end))

isEmpty = -detect

isNamed = mkIOfn(function(name)
	local ok, res = _aiming.inspect()
	return ok and res.name == name
end)

isSame = mkIO(function()
	local ok, res = _aiming.inspect()
	return ok and res.name == turtle.getItemDetail().name
end)

isTurtle = mkIO(function()
	local ok, res = _aiming.inspect()
	return ok and const.turtleBlocks[res.name] == true
end)

isChest = mkIO(function()
	local ok, res = _aiming.inspect()
	return ok and const.chestBlocks[res.name] == true
end)

isCheap = mkIO(function()
	local ok, res = _aiming.inspect()
	return ok and (const.cheapItems[res.name] or const.cheapItems[const.afterDig[res.name]]) == true
end)

isProtected = mkIO(function()
	if workMode.workArea and workMode.workArea:contains(workState.pos) and not workMode.workArea:contains(workState.pos + workState:aimingDir()) then return true end
	local ok, res = _aiming.inspect()
	return ok and (const.turtleBlocks[res.name] == true or const.chestBlocks[res.name] == true)
end)

has = markIOfn("has(itemName)")(mkIOfn(function(itemName) return not not slot.find(itemName) end))

select = mkIOfn(turtle.select)

dig = markIO("dig")(mkIO(function()
	reserveSlot() -- tidy backpack to reserve slot
	return _aiming.dig()
end))

-- | keep current slot not empty after place
place = markIO("place")(mkIO(function()
	c = turtle.getItemCount()
	s = turtle.getItemSpace()
	if c == 1 and s > 0 then slot.fill() end
	return c > 1 and _aiming.place()
end))

-- | use item, another use case of turtle.place
use = markIOfn("use(itemName)")(mkIOfn(function(itemName)
	local det = turtle.getItemDetail()
	if det and det.name == itemName then return _aiming.place() end

	local sn = slot.find(itemName)
	if not sn then return false end

	local saved_sn = turtle.getSelectedSlot()
	turtle.select(sn)
	local r = _aiming.place()
	turtle.select(saved_sn)
	return r
end))

move = markIO("move")(mkIO(function()
	-- auto refuel
	refuel(2 * manhat(workState.pos + workState:aimingDir() - workMode.fuelStation.pos))()
	--
	local mov = _aiming.move
	if workMode.destroy == 1 then
		mov = mov + (rep(isCheap * dig) * mov)
	elseif workMode.destroy == 2 or workMode.destroy == true then
		mov = mov + (rep(dig) * mov)
	end
	if workMode.violence then
		mov = mov + (rep(attack) * mov)
	end
	if workMode.retrySeconds > 0 and isTurtle() then -- only retry when blocked by turtle
		mov = mov % workMode.retrySeconds
	end
	mov = -isProtected * mov
	local r = mov()
	if r then workState.pos = workState.pos + workState:aimingDir() end
	return r
end))

withColor = function(fg, bg)
	return mkIOfn(function(io)
		local saved_fg = term.getTextColor()
		local saved_bg = term.getBackgroundColor()
		term.setTextColor(default(saved_fg)(fg))
		term.setBackgroundColor(default(saved_bg)(bg))
		local r = {io()}
		term.setTextColor(saved_fg)
		term.setBackgroundColor(saved_bg)
		return unpack(r)
	end)
end

echo = mkIOfn(function(...)
	for _, expr in ipairs({...}) do
		local func, err = load("return "..expr, "echo_expr", "t", _ENV)
		if not func then error(err) end
		local r = func()
		withColor(colors.gray)(function()
			print("[echo] "..expr.." ==>", r)
		end)()
	end
	return true
end)

