--------------------------------- Monadic API ----------------------------------

if turtle then

	turn = {
		left = markIO("turn.left")(mkIO(function() turtle.turnLeft(); workState.facing = leftSide(workState.facing); return true end)),
		right = markIO("turn.right")(mkIO(function() turtle.turnRight(); workState.facing = rightSide(workState.facing); return true end)),
		around = markIO("turn.around")(mkIO(function() turtle.turnLeft(); turtle.turnLeft(); workState.facing = -workState.facing; return true end)),
		back = markIO("turn.back")(mkIO(function()
			if workState.aiming == 0 then turtle.turnLeft(); turtle.turnLeft(); workState.facing = -workState.facing
			else workState.aiming = -workState.aiming end
			return true
		end)),
	}
	turn.to = markIOfn("turn.to(d)")(mkIOfn(function(d)
		assert(vec.manhat(d) == 1, "[turn.to(d)] d must be a dir, i.e. E/S/W/N/U/D")
		workState.aiming = d.y
		if d == workState.facing then return true
		elseif d == -workState.facing then return turn.around()
		elseif d == leftSide(workState.facing) then return turn.left()
		elseif d == rightSide(workState.facing) then return turn.right()
		else return true end
	end))
	turn.lateral = markIO("turn.lateral")(mkIO(function() return turn.to(workState:lateralDir())() end))
	for k, v in pairs(const.dir) do turn[k] = turn.to(v) end

	currentPos = mkIO(function() return workState.pos end)
	currentDir = mkIO(function() return workState:aimingDir() end)

	savePosture = markIOfn("savePosture(io)")(function(io)
		return mkIO(function()
			local saved_facing = workState.facing
			local saved_aiming = workState.aiming
			local r = {io()}
			turn.to(saved_facing)()
			workState.aiming = saved_aiming
			return unpack(r)
		end)
	end)

	saveDir = markIOfn("saveDir(io)")(function(io)
		return mkIO(function()
			local saved_dir = workState:aimingDir()
			local r = {io()}
			turn.to(saved_dir)()
			return unpack(r)
		end)
	end)

	-- usage demo: save(currentPos)(move.go(F) * saved:pipe(move.to))
	save, saved = (function()
		local stack = {}
		local _save = function(ioGetValue)
			return markIOfn("save(ioGetValue)(io)")(mkIOfn(function(io)
				table.insert(stack, { ioGetValue() })
				local r = { io() }
				table.remove(stack, 1)
				return unpack(r)
			end))
		end
		local _saved = markIO("saved")(mkIO(function()
			local v = stack[#stack]
			return v and unpack(v)
		end))
		return _save, _saved
	end)()

	_wrapAimingSensitiveApi = function(apiName, wrap, rawApis)
		if rawApis == nil then rawApis = {turtle[apiName..'Up'], turtle[apiName], turtle[apiName..'Down']} end
		assert(#rawApis >= 3, "[init _aiming."..apiName.."] three rawApis must be provided")
		return wrap(markFn("_aiming."..apiName)(function(...)
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
	-- compare = _aiming.compare --NOTE: deprecated
	attack = _aiming.attack
	drop = _aiming.drop

	details = mkIOfn(turtle.getItemDetail)
	selected = mkIO(turtle.getSelectedSlot)

	suck = markIOfn("suck(n)")(mkIOfn(function(n)
		return ( reserveOneSlot * _aiming.suck(n) )()
	end))

	-- | suck into an isolate slot and return true for success
	-- , this will change selected slot
	-- , fail reasons:
	-- , * when reserveOneSlot fails
	-- , * nothing to suck
	suckHold = markIOfn("suckHold(n)")(mkIOfn(function(n)
		return ( reserveOneSlot * select(slot.isEmpty) * _aiming.suck(n) )()
	end))

	suckExact = markIOfn("suckExact(n, itemName)")(mkIOfn(function(n, itemName)
		local old_sn = selected()
		local got = 0
		while got < n do
			local ok = suckHold(math.min(64, n - got))()
			if ok then
				local det = details()()
				if not itemName or det.name == itemName then
					got = got + det.count
				else
					saveDir( turn.lateral * drop() )()
				end
			else
				break
			end
		end
		selected(old_sn)
		return got == n, got
	end))

	dropExact = markIOfn("dropExact(n, itemName)")(mkIOfn(function(n, itemName)
		local old_sn = turtle.getSelectedSlot()
		local dropped = 0
		while dropped < n do
			if select(itemName)() then
				local got = math.min(n - dropped, turtle.getItemCount())
				local ok = drop(got)()
				if ok then
					local left = turtle.getItemCount()
					dropped = dropped + (got - left)
				else -- chest is full
					break
				end
			else -- nothing to drop
				break
			end
		end
		turtle.select(old_sn)
		return dropped == n, dropped
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

	isStation = mkIO(function()
		local ok, res = _aiming.inspect()
		return ok and (const.turtleBlocks[res.name] == true or const.chestBlocks[res.name] == true)
	end)

	isContainer = mkIO(function()
		local ok, res = _aiming.inspect()
		return ok and (const.turtleBlocks[res.name] == true or const.chestBlocks[res.name] == true or const.containerBlocks[res.name] == true)
	end)

	isCheap = mkIO(function()
		local ok, res = _aiming.inspect()
		return ok and (const.cheapItems[res.name] or const.cheapItems[const.afterDig[res.name]]) == true
	end)

	isWorkArea = mkIO(function()
		if workMode.workArea and workMode.workArea:contains(workState.pos) and not workMode.workArea:contains(workState.pos + workState:aimingDir()) then return false else return true end
	end)

	isProtected = mkIO(function()
		local ok, res = _aiming.inspect()
		return ok and (const.turtleBlocks[res.name] == true or const.chestBlocks[res.name] == true)
	end)

	dig = markIO("dig")(mkIO(function()
		return ( reserveOneSlot * _aiming.dig )()
	end))

	-- | dig into an isolate slot and return true for success
	-- , this will change selected slot
	-- , fail reasons:
	-- , * when reserveOneSlot fails
	-- , * nothing to dig
	digHold = markIO("digHold")(mkIO(function()
		return ( reserveOneSlot * select(slot.isEmpty) * _aiming.dig )()
	end))

	-- | keep current slot not empty after place
	place = markIO("place")(mkIO(function()
		local c = turtle.getItemCount()
		local s = turtle.getItemSpace()
		if c == 1 and s > 0 then slot.fill(); c = turtle.getItemCount() end
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
		if not workState.isRefueling then
			savePosd(refuelTo(workState.pos + workState:aimingDir()))() -- refuel may change our pos
		else
			if turtle.getFuelLevel() < 1 then
				cryForHelpRefueling(1000)()
			end
		end

		---- auto refuel
		--local backPos = ((workState.fuelStation and workState.fuelStation.pos) or workState.beginPos)
		--local reserveFuel = 2 * vec.manhat(workState.pos + workState:aimingDir() - backPos)
		--if not workState.isRefueling then
		--	local ok = refuel(reserveFuel)()
		--	if not ok then
		--		waitForHelp(reserveFuel)()
		--	end
		--else
		--	if turtle.getFuelLevel() < 1 then
		--		waitForHelp(reserveFuel)()
		--	end
		--end
		----

		local mov = _aiming.move
		if workMode.destroy == 1 then
			mov = mov + rep(isCheap * dig) * mov
		elseif workMode.destroy == 2 or workMode.destroy == true then
			mov = mov + rep(-isProtected * dig) * mov
		end
		if workMode.violence then
			mov = mov + rep(attack) * mov
		end
		if workMode.retrySeconds > 0 then --NOTE: only worth retry when blocked by turtle
			mov = mov + isTurtle * retry(workMode.retrySeconds)(mov)
		end
		local r = (isWorkArea * mov)()
		if r then workState.pos = workState.pos + workState:aimingDir() end
		return r
	end))

end
