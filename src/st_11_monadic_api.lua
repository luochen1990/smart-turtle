--------------------------------- Monadic API ----------------------------------

if turtle then
	myPos = mkIO(function()
		if workState.gpsCorrected and not workState.moveNotCommitted then
			return workState.pos
		else
			return gpsPos()
		end
	end)
elseif pocket then
	myPos = mkIO(function()
		return gpsPos() + const.dir.D
	end)
else
	myPos = mkIO(function()
		return gpsPos()
	end)
end

if turtle then

	help.turn = doc("sub-commands of 'turn' reference to facing and aiming of turtle and call turtle.turnLeft() and turtle.turnRight().")
	turn = {
		left = markIO("turn.left")(mkIO(function() workState.facing = leftSide(workState.facing); turtle.turnLeft(); return true end)),
		right = markIO("turn.right")(mkIO(function() workState.facing = rightSide(workState.facing); turtle.turnRight(); return true end)),
	}
	turn.around = markIO("turn.around")(turn.left * turn.left)
	turn.back = markIO("turn.back")(mkIO(function()
		if workState.aiming == 0 then turn.left(); turn.left()
		else workState.aiming = -workState.aiming end
		return true
	end))

	help.turn.to = doc({
		signature = "turn.to : Dir -> IO Bool",
		usage = "local succ = turn.to(dir)()",
		desc = "turn to the specified direction, see 'tankModel' for more detail",
	})
	turn.to = markIOfn("turn.to(d)")(mkIOfn(function(d)
		assert(vec.manhat(d) == 1, "[turn.to(d)] d must be a dir, i.e. E/S/W/N/U/D")
		workState.aiming = d.y
		if d == workState.facing then return true
		elseif d == -workState.facing then return turn.around()
		elseif d == leftSide(workState.facing) then return turn.left()
		elseif d == rightSide(workState.facing) then return turn.right()
		else return true end
	end))

	_setNamedDirection = function(name, dir)
		_ST[name] = dir
		turn[name] = turn.to(dir)
	end
	_setNamedDirection("U", const.dir.U)
	_setNamedDirection("D", const.dir.D)
	_setNamedDirection("F", vec.axis.X)
	_setNamedDirection("B", -vec.axis.X)
	_setNamedDirection("L", leftSide(vec.axis.X))
	_setNamedDirection("R", rightSide(vec.axis.X))

	help.turn.lateral = doc({
		signature = "turn.lateral : IO Bool",
		usage = "local succ = turn.lateral()",
		desc = {
			"turn to a lateral direction, which is perpendicular to aiming dir",
			"prefer U (when aiming dir is horizental) or facing dir (when aiming dir is vertical)",
		},
	})
	turn.lateral = markIO("turn.lateral")(mkIO(function() return turn.to(workState:lateralDir())() end))

	currentPos = mkIO(function() return workState.pos end)
	currentDir = mkIO(function() return workState:aimingDir() end)

	savePosture = markIOfn("savePosture(io)")(mkIOfn(function(io)
		local old_facing = workState.facing
		local old_aiming = workState.aiming
		local r = { io() }
		turn.to(old_facing)()
		workState.aiming = old_aiming
		return unpack(r)
	end))

	saveDir = markIOfn("saveDir(io)")(mkIOfn(function(io)
		local old_dir = workState:aimingDir()
		local r = { io() }
		turn.to(old_dir)()
		return unpack(r)
	end))

	saveSelected = markIOfn("saveSelected(io)")(mkIOfn(function(io)
		local old_sn = turtle.getSelectedSlot()
		local r = { io() }
		turtle.select(old_sn)
		return unpack(r)
	end))

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
	attack = _aiming.attack

	help.selected = doc({
		signature = "selected : IO Int",
		usage = "local sn = selected()",
		desc = {
			"get current selected slot number",
			"sub-commands of selected provide other info about current selected slot",
		}
	})
	selected = mkIO(turtle.getSelectedSlot)
	selected.name = mkIO(function() local det = turtle.getItemDetail(); return det and det.name end)
	selected.count = mkIO(turtle.getItemCount)
	selected.detail = mkIO(turtle.getItemDetail)
	selected.stackLimit = mkIO(function() local n = turtle.getItemCount(); return n > 0 and n + turtle.getItemSpace() end)

	help.drop = doc({
		signature = "drop : IO Bool",
		usage = "local succ = drop()",
		desc = {
			"drop selected items to the aiming dir",
			"sub-commands of drop provide more precise control",
		},
	})
	drop = markIO("drop")(_aiming.drop())

	help.suck = doc({
		signature = "suck : IO Bool",
		usage = "local succ = suck()",
		desc = {
			"suck items from the aiming dir, into the selected slot",
			"fails when reserveSlot fails or nothing to suck",
			"sub-commands of suck provide more precise control",
		},
	})
	suck = markIO("suck")(mkIO(function()
		return ( reserveSlot * _aiming.suck() )()
	end))

	help.suck.hold = doc({
		signature = "suck.hold : Number -> IO Bool",
		usage = "local succ = suck.hold(n)()",
		desc = {
			"suck into an isolate slot, this will change selected slot",
			"fails when reserveSlot fails or suck fails",
		},
	})
	suck.hold = markIOfn("suck.hold(n)")(mkIOfn(function(n)
		return ( reserveSlot * select(slot.isEmpty) * _aiming.suck(n) )()
	end))

	help.suck.exact = doc({
		signature = "suck.exact : (Number, ItemName) -> IO (Bool, Number)",
		usage = "local succ, sucked = suck.exact(n, name)()",
		desc = {
			"suck exact n specified items, discard unrelated things",
			"fails when sucked items less than n",
		},
	})
	suck.exact = markIOfn("suck.exact(n,itemName)")(mkIOfn(function(n, itemName)
		local old_sn = turtle.getSelectedSlot()
		local got = 0
		while got < n do
			local ok = suck.hold(math.min(64, n - got))()
			if ok then
				local det = selected.detail()
				if not itemName or det.name == itemName then
					got = got + det.count
				else
					saveDir(turn.lateral * drop)()
				end
			else
				break
			end
		end
		turtle.select(old_sn)
		return got == n, got
	end))

	suck.exactTo = markIOfn("suck.exactTo(n,itemName)")(mkIOfn(function(n, itemName)
		local got = slot.count(itemName)
		return suck.exact(n - got, itemName)()
	end))

	help.drop.exact = doc({
		signature = "drop.exact : IO (Bool, Number)",
		usage = "local succ, dropped = drop.exact(n, name)",
		desc = {
			"drop exact n specified items",
			"fails when dropped items less than n",
		},
	})
	drop.exact = markIOfn("drop.exact(n,itemName)")(mkIOfn(function(n, itemName)
		local old_sn = turtle.getSelectedSlot()
		local dropped = 0
		while dropped < n do
			if select(itemName)() then
				local got = math.min(n - dropped, turtle.getItemCount())
				local ok = _aiming.drop(got)()
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

	help.inspect = doc({
		signature = "inspect : IO ItemName?",
		usage = "local itemName = inspect()",
		desc = {
			"get the item name of the block toward the aiming dir",
			"fails when there is no block",
		},
	})
	inspect = markIO("inspect")(mkIO(function()
		local ok, res = _aiming.inspect()
		return ok and res.name
	end))

	compare = markIO("compare")(mkIO(function()
		local ok, res = _aiming.inspect()
		local det = turtle.getItemDetail()
		return ok and det and (res.name == det.name or _item.afterDig(res.name) == det.name)
	end))

	isEmpty = -detect
	isNamed = function(namePat)
		return fmap(glob(namePat))(inspect)
	end
	isTurtle = fmap(_item.isTurtle)(inspect)
	isChest = fmap(_item.isChest)(inspect)
	isContainer = fmap(_item.isContainer)(inspect)
	isGround = fmap(glob(const.groundBlocks))(inspect)
	isStation = mkIO(function()
		local ok, res = _aiming.inspect()
		return ok and (_item.isTurtle(res.name) or _item.isChest(res.name))
	end)

	isWorkArea = mkIO(function()
		return not (workMode.workArea and workMode.workArea:contains(workState.pos) and not workMode.workArea:contains(workState.pos + workState:aimingDir()))
	end)

	help.dig = doc({
		signature = "dig : IO Bool",
		usage = "local succ = dig()",
		desc = {
			"dig a block toward the aiming dir",
			"fails when reserveSlot fails or dig fails",
		},
	})
	dig = markIO("dig")(mkIO(function()
		return ( reserveSlot * _aiming.dig )()
	end))

	help.digHold = doc({
		signature = "digHold : IO Bool",
		usage = "local succ = digHold()",
		desc = {
			"dig into an isolate slot, this will change selected slot",
			"fails when reserveSlot fails or dig fails",
		},
	})
	digHold = markIO("digHold")(mkIO(function()
		return ( reserveSlot * select(slot.isEmpty) * _aiming.dig )()
	end))

	help.place = doc({
		signature = "place : IO Bool",
		usage = "local succ = place()",
		desc = {
			"place a block toward aiming dir, keep current slot not empty after place"
		},
	})
	place = markIO("place")(mkIO(function()
		return (ensureSlot * _aiming.place)()
	end))

	help.use = doc({
		signature = "use : ItemSelector -> IO Bool",
		usage = "local succ = use(selector)()",
		desc = {
			"use item, similar to `select(selector) * place`, but keep selected slot unchanged",
		},
	})
	use = markIOfn("use(selector)")(mkIOfn(function(selector)
		return saveSelected(select(selector) * ensureSlot * _aiming.place)()
	end))

	help.move = doc({
		signature = "move : IO Bool",
		usage = "local succ = move()",
		desc = {
			"move one step toward the aiming dir, it will automatic refuel, and might auto dig/attack/retry when move blocked (see workMode.destroy / .violence / .retrySeconds).",
			"sub-commands of 'move' is high level wrappings of move."
		},
	})
	move = markIO("move")(mkIO(function()
		local dir = workState:aimingDir()
		-- auto refuel
		if not workState.isRefueling then
			local ok = refuel.prepareMoveStep(dir, 0, const.activeRadius * const.fuelReserveRatio)()
			if not ok then
				workState.isRefueling = true
				(move.to(O) * turn.to(F))()
				workState.isRefueling = false
				cryForHelpRefueling(workState.pos + dir, const.activeRadius * const.fuelReserveRatio)()
			end
		else
			if turtle.getFuelLevel() < 1 then
				cryForHelpRefueling(workState.pos + dir, const.activeRadius * const.fuelReserveRatio)()
			end
		end

		local mov = _aiming.move
		if workMode.destroy == 1 then
			mov = mov + rep(isGround * dig) * mov
		elseif workMode.destroy == 2 or workMode.destroy == true then
			mov = mov + rep(-isStation * dig) * mov
		end
		if workMode.violence then
			mov = mov + rep(attack) * mov
		end
		if workMode.retrySeconds > 0 then --NOTE: only worth retry when blocked by turtle
			mov = mov + isTurtle * retry(workMode.retrySeconds)(mov)
		end
		workState.moveNotCommitted = true
		local r = (isWorkArea * mov)()
		if r then workState.pos = workState.pos + dir end
		workState.moveNotCommitted = false
		return r
	end))

end
