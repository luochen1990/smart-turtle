------------------------------ swarm server state ------------------------------

mkTaskInfo = function(opts) -- not used yet
	local t = {
		["type"] = opts.type,
		workArea = opts.workArea,
		beginPos = opts.beginPos,
		estCost = opts.estCost,
		requiredTools = opts.requiredTools,
		command = opts.command,
		state = "queuing",
		createdTime = now(),
		beginTime = nil,
		workerId = nil,
	}
	assert(t.type and t.beginPos and t.estCost and t.command, "mkTaskInfo(opts) lack required field")
	return t
end

mkStationInfo = function(opts)
	local s = {
		role = opts.role, --NOTE: role field is not very useful, just for display
		pos = opts.pos,
		dir = opts.dir,
		deliverBar = opts.deliverBar,
		deliverPriority = opts.deliverPriority,
		restockBar = opts.restockBar,
		restockPriority = opts.restockPriority,
		itemType = opts.itemType,
		itemStackLimit = opts.itemStackLimit,
		stationHosterId = opts.stationHosterId,
		-- states
		itemCount = opts.itemCount,
		delivering = 0,
		restocking = 0,
		isVisiting = default(false)(opts.isVisiting),
		currentQueueLength = default(0)(opts.currentQueueLength),
		maxQueueLength = default(5)(opts.maxQueueLength),
		--latestCheckTime = now() - 100,
	}
	assert(s.pos and ((s.deliverBar and s.deliverPriority) or (s.restockBar and s.restockPriority)), "[mkStationInfo(opts)] lacks required field")
	assert(not (s.deliverBar and s.restockBar) or (s.deliverBar >= s.restockBar), "[mkStationInfo(opts)] expect s.deliverBar >= s.restockBar")
	return s
end

mkWorkerInfo = function(opts) -- not used yet
	local w = {
		id = opts.id,
		latestPos = nil,
		latestReportTime = nil,
		state = "idle", -- or "busy" or "interrapt"
	}
	return w
end

swarm = {}

swarm.config = {
	asFuel = {"minecraft:charcoal", "minecraft:coal", "minecraft:white_carpet"},
}

swarm._state = {
	stationPool = {},
	workerPool = {},
	jobPool = {},
	vars = {},
}

--------------------------------- swarm service --------------------------------

swarm._startService = (function()
	local serviceCo = rpc.buildServer("swarm", "queuing", function(msg)
		return safeEval(msg) --TODO: set proper env
	end)

	local findCarrierTask = function(itemType, pool)
		local providers, requesters = {}, {}
		for _, station in pairs(pool) do
			if station.itemCount then -- only itemCount reported station considered
				local cnt = station.itemCount + station.restocking - station.delivering
				log.verb("station: "..literal(station.role, station.itemType, station.itemCount, station.pos))
				if station.restockPriority and cnt < station.restockBar then
					local intent = station.deliverBar - cnt
					local info = {pos = station.pos, dir = station.dir, intent = intent, priority = station.restockPriority}
					table.insert(requesters, info)
				end
				if station.deliverPriority and cnt > station.deliverBar then
					local intent = cnt - station.restockBar
					local info = {pos = station.pos, dir = station.dir, intent = intent, priority = station.deliverPriority}
					table.insert(providers, info)
				end
			end
		end
		if #providers == 0 or #requesters == 0 then
			return false, "got "..(#providers).." providers and "..(#requesters).." requesters, no task found"
		end
		local cmp = comparator(field("priority"), field("intent"))
		table.sort(providers, cmp)
		table.sort(requesters, cmp)

		local provider = providers[1]
		local requester = requesters[1]
		local priority = math.max(requester.priority, provider.priority)
		if not (priority > 0) then
			return false, "got provider with priority "..provider.priority.." and requester with priority "..requester.priority..", no task found"
		end
		local intent = math.min(provider.intent, requester.intent)
		local capacity = pool[show(provider.pos)].itemStackLimit * const.turtle.backpackSlotsNum * 0.75
		local task = {
			provider = provider,
			requester = requester,
			itemCount = math.min(capacity, intent),
			itemType = itemType,
		}
		return true, task
	end

	local daemonCo = function()
		local carrierClient = rpc.buildClient("swarm-carrier")
		sleep(20)
		printC(colors.gray)("begin finding carrier task...")
		while true do
			for itemType, pool in pairs(swarm._state.stationPool) do
				printC(colors.gray)("finding task for "..literal(itemType))
				local ok, task = findCarrierTask(itemType, pool)
				if ok then
					printC(colors.green)("found task:", literal(task))
					local carriers = carrierClient.broadcast("isIdle(), workState.pos")()
					printC(colors.lime)('carriers:', literal(carriers)) -- r like {id, ok, {isIdle, pos}}
					local candidates = {}
					for _, r in ipairs(carriers) do
						if r[2] and r[3][1] then
							table.insert(candidates, {id = r[1], pos = r[3][2]})
						end
					end
					if #candidates > 0 then
						local cmpDis = function(c) return vec.manhat(c.pos - task.provider.pos) end
						table.sort(candidates, comparator(cmpDis))
						local carrierId = candidates[1].id
						local taskResult = { carrierClient.send(carrierId, "carry("..literal(task.provider, task.requester, task.itemCount, task.itemType)..")()", 1000)() }
						printC(colors.lime)("Task done: ", literal(taskResult))
						sleep(5)
					else
						printC(colors.gray)("no carrier available")
					end
				else
					local msg = task
					printC(colors.yellow)(msg)
				end
			end
			printC(colors.gray)("finished a round...")
			sleep(20)
		end
	end

	return para_(serviceCo, daemonCo)
end)()

swarm.services = {}

swarm.services.setVar = function(k, v, id, label)
	local varInfo = swarm._state.vars[k]
	if not varInfo then -- create new var
		swarm._state.vars[k] = {value = v, setterId = id, setterLabel = label, creatTime = os.date()}
		return true, "var created"
	else -- already exist
		if v == varInfo.value then
			return true, "var already exist before"
		elseif v == nil then -- set to nil, i.e. delete
			swarm._state.vars[k] = nil
			return true, "var deleted"
		else
			return false, "cannot change existing var"
		end
	end
end

swarm.services.inspectVar = function(k)
	return swarm._state.vars[k]
end

swarm.services.getVar = function(k)
	local varInfo = swarm._state.vars[k]
	if varInfo then
		return true, varInfo.value
	else
		return false, "variable not found"
	end
end

swarm.services.registerStation = function(opts)
	if not opts.pos then
		return false, "station pos is required"
	end
	local station = mkStationInfo(opts)
	local itemTy = opts.itemType
	if not itemTy then
		return false, "station itemType is required"
	end
	swarm._state.stationPool[itemTy] = default({})(swarm._state.stationPool[itemTy])
	swarm._state.stationPool[itemTy][show(station.pos)] = station
	return true, "station registered"
end

swarm.services.updateStation = function(opts)
	if not opts.itemType or not opts.pos then
		return false, "station pos and itemType is required"
	end
	local pool = swarm._state.stationPool[opts.itemType]
	if not pool then
		return false, "station not exist (no such type)"
	end
	local station = pool[show(opts.pos)]
	if not station then
		return false, "station not exist (no such pos)"
	end
	for k, v in pairs(opts) do
		station[k] = v
	end
	return true, "station updated"
end

swarm.services.unregisterStation = function(st)
	if not st.itemType or not st.pos then
		return false, "station pos and itemType is required"
	end
	local pool = swarm._state.stationPool[st.itemType]
	if pool then
		pool[show(st.pos)] = nil
	end
	return true, "done"
end

swarm.services.requestStation = function(itemType, itemCount, startPos, fuelLeft)
	local pool = swarm._state.stationPool[itemType]
	if not pool then
		return false, "no such station registered, please register one"
	end
	if type(itemCount) ~= "number" then
		return false, "bad request, please provide itemCount as number"
	end
	if not vec.isVec(startPos) then
		return false, "bad request, please provide startPos as vec"
	end
	if type(fuelLeft) ~= "number" then
		return false, "bad request, please provide fuelLeft as number"
	end
	-- [[
	-- There is three dimention to compare station choices:
	--	1. distance:    |--->
	--	2. item count:   --->|
	--	3. queue time:  |--->#
	--
	-- (Tips about the axis:
	--	 * left to right, worst to best
	--	 * `|` is a basic bar, which means this dimention good enough to this point is required
	--	 * `#` is a significant bar, which means this dimention good enough to this point will make significant difference
	--	 )
	--
	--	the distance dimention has one bar, which means if farer than this distance, then fuelLeft is not enough
	--	the item count dimention has one bar, which means the item count is enough for the request
	--	the queue time dimention has two bar, first means the queue is full, second means the queue is empty
	--
	--	Our strategy is that:
	--	 * if all basic bar can be reached, then we try to reach more (weighted) significant bar;
	--	 * if not, return fail;
	-- ]]
	-- boolean conditions
	local nearer = function(pos1, pos2) return vec.manhat(pos1 - startPos) < vec.manhat(pos2 - startPos) end
	local nearEnough = function(st) return vec.manhat(st.pos - startPos) * 2 <= fuelLeft end
	local itemEnough = function(st) return st.itemCount and st.itemCount >= itemCount end
	local queueNotFull = function(st) return st.currentQueueLength < st.maxQueueLength end
	-- number conditions
	local dist = function(st) return vec.manhat(st.pos - startPos) end
	local queEmpty = function(st) if st.currentQueueLength == 0 and st.isVisiting == false then return 0 else return 1 end end
	local que = function(st) if st.isVisiting == false then return st.currentQueueLength else return st.currentQueueLength + 1 end end
	--

	local better = comparator(queEmpty, dist, que)
	local best
	for _, st in pairs(swarm._state.stationPool[itemType]) do
		if nearEnough(st) and itemEnough(st) and queueNotFull(st) then
			if best == nil or better(st, best) then
				best = st
			end
		end
	end
	if best then
		return true, best
	end
	return false, "no proper station now, please try latter"
end

swarm.services.requestFuelStation = function(nStep, startPos, fuelLeft)
	for _, name in ipairs(swarm.config.asFuel) do
		local count = math.ceil(nStep / _item.fuelHeatContent(name))
		local ok, res = swarm.services.requestStation(name, count, startPos, fuelLeft)
		if ok then
			return true, res
		end
	end
	return false, "no fuel station available, swarm.config.asFuel = "..literal(swarm.config.asFuel)
end

--------------------------------- swarm client ---------------------------------

swarm.client = rpc.buildClient("swarm")

_updateInventoryCo = function(stationDef, needReport)
	local inventoryCount = {
		isDirty = true,
		lastReport = stationDef.itemCount,
	}
	local checkCo = function()
		while true do
			local ev = { os.pullEvent("turtle_inventory") } -- no useful information :(
			inventoryCount.isDirty = true
		end
	end
	if not needReport then
		needReport = function(old_cnt)
			local cnt = slot.count(stationDef.itemType)
			if cnt ~= old_cnt then
				return true, cnt
			else
				return false, cnt
			end
		end
	end
	local updateCo = function()
		local info = {
			pos = stationDef.pos,
			dir = stationDef.dir,
			itemType = stationDef.itemType,
		}
		while true do
			sleep(5)
			if inventoryCount.isDirty then
				local need, cnt = needReport(inventoryCount.lastReport)
				inventoryCount.isDirty = false --NOTE: position of this line is very important
				if need then
					printC(colors.gray)(os.time().." current count: "..cnt)
					info.itemCount = cnt
					swarm.myState.itemCount = cnt
					local ok, res = swarm.client.request("swarm.services.updateStation("..literal(info)..")")()
					if ok then
						inventoryCount.lastReport = cnt
						printC(colors.green)("itemCount reported: "..info.itemCount)
					else
						log.warn("("..stationDef.itemType..") failed to report inventory: "..literal(res))
					end
				end
			end
		end
	end
	return para_(checkCo, updateCo) -- return IO
end

serveAsProvider = mkIO(function()
	local getAndHold
	if isContainer() then -- suck items from chest
		getAndHold = function(n) return suck.hold(n) end
	else -- dig or attack --TODO: check tool
		getAndHold = function(n) return (isContainer * suck.hold(n) + -isContainer * (digHold + try(attack) * suck.hold(n))) end
	end

	local stationDef = {
		role = "provider",
		pos = workState.pos - workState:aimingDir(),
		dir = workState:aimingDir(),
		itemType = nil,
		itemStackLimit = nil,
		restockBar = const.turtle.backpackSlotsNum * 0.25,
		deliverBar = const.turtle.backpackSlotsNum * 0.75,
		deliverPriority = -9, -- passive provider
		stationHosterId = os.getComputerID()
	}

	local registerCo = function()
		printC(colors.gray)("[provider] detecting item")
		local det = retry((select(slot.isNonEmpty) + getAndHold(1)) * selected.detail)()
		stationDef.itemType = det.name
		stationDef.itemStackLimit = det.count + turtle.getItemSpace()
		stationDef.restockBar = stationDef.itemStackLimit * const.turtle.backpackSlotsNum * 0.25
		stationDef.deliverBar = stationDef.itemStackLimit * const.turtle.backpackSlotsNum * 0.75
		printC(colors.green)("[provider] got "..det.name)
		local _reg = function()
			local ok, res = swarm.client.request("swarm.services.registerStation("..literal(stationDef)..")")()
			if not ok then
				log.warn("[provider] failed to register station (network error): "..literal(res)..", retrying...")
				return false
			end
			if not table.remove(res, 1) then
				log.warn("[provider] failed to register station (logic error): "..literal(res)..", retrying...")
				return false
			end
			swarm.myState.stationDef = stationDef
			log.info("[provider] provider of " .. stationDef.itemType .. " registered at " .. show(stationDef.pos))
			return true
		end
		retry(_reg)()
	end

	local produceCo = function()
		with({allowInterruption = false})(function()
			while true do
				-- retry to get items
				local det = retry(getAndHold() * selected.detail)()
				if det.name == stationDef.itemType then -- got target item
					print("inventory +"..det.count)
				else -- got unconcerned item
					saveDir(turn.lateral * drop)()
				end
				sleep(0.01)
			end
		end)()
	end

	registerCo()
	para_(produceCo, _updateInventoryCo(stationDef))()
end)

serveAsUnloader = mkIO(function()
	local stationDef = {
		role = "unloader",
		pos = workState.pos - workState:aimingDir(),
		dir = workState:aimingDir(),
		itemType = "*anything", -- NOTE: this is a special constant value
		restockBar = 0,
		deliverBar = 0, -- deliver everything and keep nothing
		deliverPriority = 10, -- active provider
		stationHosterId = os.getComputerID(),
	}

	local registerCo = function()
		printC(colors.gray)("[unloader] registering unload station")
		local _reg = function()
			local ok, res = swarm.client.request("swarm.services.registerStation("..literal(stationDef)..")")()
			if not ok then
				log.cry("[unloader] failed to register station (network error): "..literal(res))
				return false
			end
			if not table.remove(res, 1) then
				log.cry("[unloader] failed to register station (logic error): "..literal(res))
				return false
			end
			swarm.myState.stationDef = stationDef
			log.info("[unloader] unload station registered at " .. show(stationDef.pos))
			return true
		end
		retry(_reg)()
	end

	local keepDroppingCo = rep(retry(isChest * select(slot.isNonEmpty) * drop))

	registerCo()
	para_(keepDroppingCo, _updateInventoryCo(stationDef))()
end)

serveAsRequester = mkIO(function()
	local stationDef = {
		role = "requester",
		pos = workState.pos - workState:aimingDir(),
		dir = workState:aimingDir(),
		itemType = nil,
		itemStackLimit = nil,
		restockBar = const.turtle.backpackSlotsNum * 0.5,
		restockPriority = 9,
		deliverBar = const.turtle.backpackSlotsNum * 1.0,
		stationHosterId = os.getComputerID()
	}

	local registerCo = function()
		printC(colors.gray)("[requester] detecting item")
		local det = retry((select(slot.isNonEmpty) + suck.hold(1)) * selected.detail)()
		stationDef.itemType = det.name
		stationDef.itemStackLimit = det.count + turtle.getItemSpace()
		stationDef.restockBar = stationDef.itemStackLimit * const.turtle.backpackSlotsNum * 0.5
		stationDef.deliverBar = stationDef.itemStackLimit * const.turtle.backpackSlotsNum * 1.0
		printC(colors.green)("[requester] got "..det.name)
		local _reg = function()
			local ok, res = swarm.client.request("swarm.services.registerStation("..literal(stationDef)..")")()
			if not ok then
				log.cry("[requester] failed to register station (network error): "..literal(res))
				return false
			end
			if not table.remove(res, 1) then
				log.cry("[requester] failed to register station (logic error): "..literal(res))
				return false
			end
			swarm.myState.stationDef = stationDef
			log.info("[requester] requester of " .. stationDef.itemType .. " registered at " .. show(stationDef.pos))
			return true
		end
		retry(_reg)()
	end

	local keepDroppingCo = rep(retry(isChest * select(slot.isNonEmpty) * drop))

	registerCo()
	para_(keepDroppingCo, _updateInventoryCo(stationDef))()
end)

serveAsStorage = mkIO(function()
	local stationDef = {
		role = "storage",
		pos = workState.pos - workState:aimingDir(),
		dir = workState:aimingDir(),
		itemType = nil,
		itemStackLimit = nil,
		restockBar = const.turtle.backpackSlotsNum * 0.25,
		restockPriority = 1, --NOTE: lower than requester
		deliverBar = const.turtle.backpackSlotsNum * 0.75,
		deliverPriority = 0, --NOTE: higher than provider, but still passive
		stationHosterId = os.getComputerID()
	}

	local registerCo = function()
		printC(colors.gray)("[storage] detecting item")
		local det = retry((select(slot.isNonEmpty) + suck.hold(1)) * selected.detail)()
		stationDef.itemType = det.name
		stationDef.itemStackLimit = det.count + turtle.getItemSpace()
		stationDef.restockBar = stationDef.itemStackLimit * const.turtle.backpackSlotsNum * 0.25
		stationDef.deliverBar = stationDef.itemStackLimit * const.turtle.backpackSlotsNum * 0.75
		printC(colors.green)("[storage] got "..det.name)
		local _reg = function()
			local ok, res = swarm.client.request("swarm.services.registerStation("..literal(stationDef)..")")()
			if not ok then
				log.cry("[storage] failed to register station (network error): "..literal(res))
				return false
			end
			if not table.remove(res, 1) then
				log.cry("[storage] failed to register station (logic error): "..literal(res))
				return false
			end
			swarm.myState.stationDef = stationDef
			log.info("[storage] storage of " .. stationDef.itemType .. " registered at " .. show(stationDef.pos))
			return true
		end
		retry(_reg)()
	end

	local needReport = function(old_cnt)
		local new_cnt = slot.count(stationDef.itemType)
		local target = (stationDef.restockBar - 1)
		local intent = target - new_cnt
		if intent > 0 then
			local ok, sucked = (isChest * suck.exact(intent, stationDef.itemType))()
			--log.verb(literal({ok = ok, sucked = sucked, intent = intent, item = stationDef.itemType}))
			new_cnt = new_cnt + (sucked or 0)
		elseif intent < 0 then
			local ok, dropped = (isChest * drop.exact(-intent, stationDef.itemType))()
			--log.verb(literal({ok = ok, dropped = dropped, intent = intent, item = stationDef.itemType}))
			new_cnt = new_cnt - (dropped or 0)
		end
		return (new_cnt ~= old_cnt), new_cnt
	end

	registerCo()
	_updateInventoryCo(stationDef, needReport)()
end)

serveAsCarrier = mkIO(function()
	local serviceCo = rpc.buildServer("swarm-carrier", "blocking", function(msg)
		swarm.myState.isRunningSwarmTask = true
		workState.isRunningSwarmTask = true
		local res = { safeEval(msg) } --TODO: set proper env
		workState.isRunningSwarmTask = false
		swarm.myState.isRunningSwarmTask = false
		return unpack(res)
	end)

	workState.isRunningSwarmTask = false
	swarm.myState.isRunningSwarmTask = false
	serviceCo()
end)

--foldSuccFlag = function(reqSucc, resp)
--	if reqSucc then return unpack(resp) else return false, resp end
--end

foldSuccFlag = function(reqSucc, resp)
	if reqSucc then
		local ok, res = unpack(resp)
		if ok then
			return ok, res
		else
			return false, {title = "logic error", msg = res}
		end
	else
		return false, {title = "network error", msg = resp}
	end
end

requestStation = mkIOfn(function(itemName, itemCount, startPos, fuelLeft)
	itemCount = default(0)(itemCount)
	startPos = default(workState.pos)(startPos)
	fuelLeft = default(turtle.getFuelLevel())(fuelLeft)
	return foldSuccFlag(swarm.client.request("swarm.services.requestStation("..literal(itemName, itemCount, startPos, fuelLeft)..")")())
end)

requestFuelStation = mkIOfn(function(nStep, startPos, fuelLeft)
	startPos = default(workState.pos)(startPos)
	fuelLeft = default(turtle.getFuelLevel())(fuelLeft)
	return foldSuccFlag(swarm.client.request("swarm.services.requestFuelStation("..literal(nStep, startPos, fuelLeft)..")")())
end)

requestUnloadStation = mkIOfn(function(emptySlotRequired, startPos, fuelLeft)
	startPos = default(workState.pos)(startPos)
	fuelLeft = default(turtle.getFuelLevel())(fuelLeft)
	return foldSuccFlag(swarm.client.request("swarm.services.requestStation("..literal("*anything", 0, startPos, fuelLeft)..")")()) --TODO: calc slot number
end)

unregisterStation = function(st)
	return foldSuccFlag(swarm.client.request("swarm.services.unregisterStation("..literal({itemType = st.itemType, pos = st.pos})..")")())
end

-- | turtle is idle means: repl is not running command and workState.isRunningSwarmTask = false
isIdle = mkIO(function()
	--return not (_repl.state.isRunningCommand or workState.isRunningSwarmTask)
	return not (_repl.state.isRunningCommand)
end)

displayLog = mkIOfn(function(computerId)
	_logPrintCo(nil, computerId)
end)

_stTurtles = rpc.buildClient("st-turtle")
_stComputers = rpc.buildClient("st-computer")

swarm.reboot = mkIO(function()
	return _stComputers.broadcast("os.reboot()")()
end)

-- List (IO (a -> b)) -> IO a -> IO ()
_displayIO = function(ioFs)
	local colorList = {colors.green, colors.lightGray, colors.yellow}
	return mkIOfn(function(io)
		local ls = io()
		local fs = {}
		for _, mf in ipairs(ioFs) do
			if type(mf) == "string" then
				table.insert(fs, field(mf))
			elseif type(mf) == "function" then
				table.insert(fs, mf)
			elseif isIO(mf) then
				table.insert(fs, mf())
			end
		end
		for i = 1, #ls do
			for j, f in ipairs(fs) do
				if j > 1 then write(" ") end
				withColor(colorList[(j - 1) % #colorList + 1])(function()
					write(show(f(ls[#ls + 1 - i])))
				end)()
			end
			write("\n")
		end
		return true
	end)
end

list = {}
list.turtles = mkIO(function()
	local resps = _stTurtles.broadcast("gpsPos(), swarm.myRole or '~', os.getComputerLabel(), swarm.myState")()
	local rs = {}
	for _, r in ipairs(resps) do
		if r[2] then
			table.insert(rs, {id = r[1], pos = r[3][1], role = r[3][2], label = r[3][3], state = r[3][4]})
		end
	end
	table.sort(rs, comparator(pipe(field("pos"), distance(myPos()))))
	return rs
end)
list.turtles.display = _displayIO({"label", "pos", myPos:pipe(function(p) return pure(combine(distance(p))(field("pos"))) end)})(list.turtles)

list.turtles.filterRole = function(roleFilter)
	local io = mkIO(function()
		local ls = list.turtles()
		local rs = {}
		for _, x in ipairs(ls) do
			if roleFilter(x.role) then
				table.insert(rs, x)
			end
		end
		return rs
	end)
	io.display = _displayIO({"label", "pos", myPos:pipe(function(p) return pure(combine(distance(p))(field("pos"))) end)})(io)
	return io
end

list.stations = list.turtles.filterRole(glob({"provider", "requester", "storage", "unloader"}))
list.stations.display = _displayIO({field("state", "stationDef", "itemType"), "label", field("state", "itemCount"), "pos", myPos:pipe(function(p) return pure(combine(distance(p))(field("pos"))) end)})(list.stations)

list.stations.filterItem = function(itemFilter)
	if type(itemFilter) == "string" or type(itemFilter) == "table" then
		itemFilter = glob(itemFilter)
	end
	assert(type(itemFilter) == "function", "[list.stations.filterItem] itemFilter should be function")
	local io = mkIO(function()
		local ls = list.stations()
		local rs = {}
		for _, x in ipairs(ls) do
			if x.state and itemFilter(x.state.stationDef.itemType) then --TODO: get station.itemType somehow
				table.insert(rs, x)
			end
		end
		return rs
	end)
	io.display = _displayIO({field("state", "stationDef", "itemType"), "label", field("state", "itemCount"), "pos", myPos:pipe(function(p) return pure(combine(distance(p))(field("pos"))) end)})(io)
	return io
end

swarm.vars = {}
swarm.vars.inspect = function(k)
	return foldSuccFlag(swarm.client.request("swarm.services.inspectVar("..literal(k)..")")())
end
setmetatable(swarm.vars, {
	__index = function(d, k)
		local ok, res = foldSuccFlag(swarm.client.request("swarm.services.getVar("..literal(k)..")")())
		if ok then
			return res
		else
			printC(colors.yellow)("failed to get variable "..showLit(k)..": "..showLit(res))
			return nil
		end
	end,
	__newindex = function(d, k, v)
		local ok, res = foldSuccFlag(swarm.client.request("swarm.services.setVar("..literal(k, v, os.getComputerID(), os.getComputerLabel())..")")())
		if ok then
			printC(colors.green)(res)
		else
			printC(colors.yellow)("failed to set variable"..showLit(k)..": "..showLit(res))
		end
	end,
})

---------------------------------- swarm roles ---------------------------------

swarm.roles = {
	["swarm-server"] = {
		check = function() return true end,
		daemon = function()
			swarm._startService()
		end,
	},
	["log-monitor"] = {
		check = function() return true end,
		daemon = function()
			os.pullEvent("system-ready")
			_logPrintCo({verb = false})
		end,
	},
	["debugger"] = {
		check = function() return true end,
		daemon = function()
			os.pullEvent("system-ready")
			_logPrintCo({verb = true, info = false, warn = true, cry = false, bug = true})
		end,
	},
	["unloader"] = {
		check = function() return turtle ~= nil end,
		daemon = function()
			os.pullEvent("turtle-posd-ready")
			serveAsUnloader()
		end,
	},
	["provider"] = {
		check = function() return turtle ~= nil end,
		daemon = function()
			os.pullEvent("turtle-posd-ready")
			serveAsProvider()
		end,
	},
	["requester"] = {
		check = function() return turtle ~= nil end,
		daemon = function()
			os.pullEvent("turtle-posd-ready")
			serveAsRequester()
		end,
	},
	["storage"] = {
		check = function() return turtle ~= nil end,
		daemon = function()
			os.pullEvent("turtle-posd-ready")
			serveAsStorage()
		end,
	},
	["carrier"] = {
		check = function() return turtle ~= nil end,
		daemon = function()
			os.pullEvent("system-ready")
			serveAsCarrier()
		end,
	},
	["blinker"] = {
		check = function() return true end,
		daemon = function()
			os.pullEvent("system-ready")
			local b = false
			local side = "back"
			if turtle then side = "front" end
			while true do
				redstone.setOutput(side, b)
				b = not b
				sleep(0.5)
			end
		end,
	},
}

