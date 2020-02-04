--------------------------------- Monadic API ----------------------------------

turn = {
	left = mkIO(function() turtle.turnLeft(); workState.facing = leftSide(workState.facing); return true end),
	right = mkIO(function() turtle.turnRight(); workState.facing = rightSide(workState.facing); return true end),
	back = mkIO(function() turtle.turnLeft(); turtle.turnLeft(); workState.facing = -workState.facing; return true end),
}
turn.to = mkIOfn(function(d)
	workState.aiming = d.y
	if d == workState.facing then return true
	elseif d == -workState.facing then return turn.back()
	elseif d == leftSide(workState.facing) then return turn.left()
	elseif d == rightSide(workState.facing) then return turn.right()
	else return true end
end)
turn.lateral = mkIO(function() return turn.to(workState:lateralDir()) end)
for k, v in pairs(const.dir) do turn[k] = turn.to(v) end

saveTurning = function(io)
	return mkIO(function()
		local _facing, _aiming = workState.facing, workState.aiming
		r = {io()}
		turn.to(_facing)()
		if _aiming ~= 0 then turn.to(vec(0, _aiming, 0)) end
		return unpack(r)
	end)
end

_wrapAimingSensitiveApi = function(apiName, wrap, rawApis)
	if rawApis == nil then rawApis = {turtle[apiName..'Up'], turtle[apiName], turtle[apiName..'Down']} end
	assert(#rawApis >= 3, "three rawApis must be provided")
	return wrap(function(...)
		rawApi = rawApis[2 - workState.aiming]
		assert(rawApi ~= nil, "workState.aiming must be 0/1/-1")
		return rawApi(...)
	end)
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
suck = _aiming.suck
drop = _aiming.drop

-- | different from turtle.inspect, this only returns res
inspect = mkIO(function()
	ok, res = _aiming.inspect()
	return res
end)

isEmpty = -detect

isNamed = mkIOfn(function(name)
	ok, res = _aiming.inspect()
	return ok and res.name == name
end)

isSame = mkIO(function()
	ok, res = _aiming.inspect()
	return ok and res.name == turtle.getItemDetail().name
end)

isTurtle = mkIO(function()
	ok, res = _aiming.inspect()
	return ok and const.turtleBlocks[res.name] == true
end)

isChest = mkIO(function()
	ok, res = _aiming.inspect()
	return ok and const.chestBlocks[res.name] == true
end)

isCheap = mkIO(function()
	ok, res = _aiming.inspect()
	return ok and const.cheapItems[res.name] == true
end)

isProtected = mkIO(function()
	ok, res = _aiming.inspect()
	return ok and (const.turtleBlocks[res.name] == true or const.chestBlocks[res.name] == true)
end)

has = mkIOfn(function(name) return not not slot.find(name) end)

select = mkIOfn(turtle.select)

dig = mkIO(function()
	-- tidy backpack to reserve slot
	if not slot.findLastEmpty() then
		slot.tidy()
		if not slot.findLastEmpty() then
			turtle.select(slot.findDroppable())
			local io = (saveTurning(turn.lateral * -isChest * drop()) + drop())
			io()
		end
	end
	--
	return _aiming.dig()
end)

-- | keep current slot not empty after place
place = mkIO(function()
	c = turtle.getItemCount()
	s = turtle.getItemSpace()
	if c == 1 and s > 0 then slot.fill() end
	return c > 1 and _aiming.place()
end)

-- | use item, another use case of turtle.place
use = mkIOfn(function(name)
	if turtle.getItemDetail().name ~= name then
		sn = slot.find(name)
		if not sn then return false end
		turtle.select(sn)
	end
	return _aiming.place()
end)

move = mkIO(function()
	-- auto refuel
	refuel(#(workState.beginPos .. workState.pos))
	--
	local mov = _aiming.move
	if workMode.destroy == 1 then
		mov = mov + (rep(-(isCheap * dig)) .. mov)
	elseif workMode.destroy == 2 or workMode.destroy == true then
		mov = mov + (rep(-(-isProtected * dig)) .. mov)
	end
	if workMode.violence then
		mov = mov + (rep(-attack) .. mov)
	end
	if workMode.retrySeconds > 0 and isTurtle() then -- only retry when blocked by turtle
		mov = mov % workMode.retrySeconds
	end
	r = mov()
	if r then workState.pos = workState.pos + workState:aimingDir() end
	-- record backPath
	return r
end)

