--------------------------------- swarm state ----------------------------------

mkTaskInfo = function(opts) -- not used yet
	local t = {
		["type"] = opts.type,
		workArea = opts.workArea,
		beginPos = opts.beginPos,
		estCost = opts.estCost,
		requiredTools = opts.requiredTools,
		command = opts.command,
		state = "queueing",
		createdTime = now(),
		beginTime = nil,
		workerId = nil,
	}
	assert(t.type and t.beginPos and t.estCost and t.command, "mkTaskInfo(opts) lack required field")
	return t
end

mkStationInfo = function(opts)
	local s = {
		pos = opts.pos,
		dir = opts.dir,
		limitation = opts.limitation,
		deliverPriority = opts.deliverPriority,
		reservation = opts.reservation,
		restockPriority = opts.restockPriority,
		itemType = opts.itemType,
		itemCount = 0,
		hasQueueSpace = true,
		isVisiting = false,
		currentQueueLength = 0,
		--latestCheckTime = now() - 100,
	}
	assert(s.pos and ((s.limitation and s.deliverPriority) or (s.reservation and s.restockPriority)), "[mkStationInfo(opts)] lacks required field")
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

swarm = {
	_state = {
		stationPool = {},
		workerPool = {},
		jobPool = {},
	},
}

-------------------------------- telnet service --------------------------------

telnetServerCo = function(ignoreDeposit)
	local eventQueue = {}
	local listenCo = function()
		while true do
			--printC(colors.gray)("[telnet] listening")
			local senderId, msg, _ = rednet.receive("telnet")
			--printC(colors.gray)("[telnet] received from " .. senderId .. ": " .. msg)
			local queueTail = #eventQueue + 1
			if ignoreDeposit then queueTail = 1 end
			eventQueue[queueTail] = {senderId, msg}
		end
	end
	local execCo = function()
		local sleepInterval = 1
		while true do
			if #eventQueue == 0 then
				sleepInterval = math.min(0.5, sleepInterval * 1.1)
				--printC(colors.gray)("[telnet] waiting "..sleepInterval)
				sleep(sleepInterval)
			else -- if #eventQueue > 0 then
				--printC(colors.gray)("[telnet] executing "..#eventQueue)
				sleepInterval = 0.02
				local sender, msg = unpack(table.remove(eventQueue, 1))
				printC(colors.gray)("[telnet] exec cmd from " .. sender .. ": " .. msg)
				if msg == "exit" then break end
				func, err = load("return "..msg, "telnet_cmd", "t", _ENV)
				if func then
					ok, res = pcall(func)
					if ok then
						printC(colors.green)(res)
					else
						printC(colors.yellow)(res)
					end
				else
					printC(colors.orange)(err)
				end
			end
		end
	end
	parallel.waitForAny(listenCo, execCo)
end

--------------------------------- swarm service --------------------------------

swarm._startService = function()
	local eventQueue = {}
	local listenCo = function()
		rednet.host("swarm", "server")
		while true do
			printC(colors.gray)("[swarm] listening")
			local senderId, msg, _ = rednet.receive("swarm-service")
			printC(colors.gray)("[swarm] received from " .. senderId .. ": " .. msg)
			table.insert(eventQueue, {senderId, msg})
		end
	end
	local execCo = function()
		local sleepInterval = 1
		while true do
			if #eventQueue == 0 then
				sleepInterval = math.min(0.5, sleepInterval * 1.1)
				--printC(colors.gray)("[swarm] waiting "..sleepInterval)
				sleep(sleepInterval)
			else -- if #eventQueue > 0 then
				--printC(colors.gray)("[swarm] executing "..#eventQueue)
				sleepInterval = 0.02
				local requesterId, msg = unpack(table.remove(eventQueue, 1))
				printC(colors.gray)("[swarm] exec cmd from " .. requesterId .. "")
				if msg == "exit" then
					break
				end
				local ok, res = eval(msg)
				local resp
				if ok then
					resp = literal(true, res)
					printC(colors.green)("[swarm] response to " .. requesterId .. ": " .. resp)
				else
					resp = literal(false, res.msg)
					printC(colors.yellow)("[swarm] response to " .. requesterId .. ": " .. resp)
				end
				rednet.send(requesterId, resp, "swarm-response")
			end
		end
	end
	parallel.waitForAny(listenCo, execCo)
end

swarm.services = {}

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
	swarm._state.stationPool[itemTy][station.pos] = station
	return true
end

swarm.services.requestStation = function(itemType, itemCount, startPos, fuelLeft)
	local pool = swarm._state.stationPool[itemType]
	if not pool then
		return false, "no such station registered, please register one"
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
	local itemEnough = function(st) if itemCount >= 0 then return st.itemCount >= itemCount else return st.itemCount < itemCount end end
	local queueNotFull = function(st) return st.hasQueueSpace end
	-- number conditions
	local dist = function(st) return vec.manhat(st.pos - startPos) end
	local queEmpty = function(st) if st.currentQueueLength == 0 and st.isVisiting == false then return 0 else return 1 end end
	local que = function(st) if st.isVisiting == false then return st.currentQueueLength else return st.currentQueueLength + 1 end end
	--
	local comparator = function(...)
		local attrs = {...}
		return function(a, b)
			for i, attr in ipairs(attrs) do
				local aa, ab = attr(a), attr(b)
				if i == #attrs or aa ~= ab then return aa < ab end
			end
		end
	end

	local better = comparator(queEmpty, dist, que)
	local best
	for pos, st in pairs(swarm._state.stationPool[itemType]) do
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

--------------------------------- swarm client ---------------------------------

_request = function(swarmServerId, msg, requestProtocol, responseProtocol, timeout)
	rednet.send(swarmServerId, msg, requestProtocol)
	local responserId, resp = rednet.receive(responseProtocol, timeout)
	if responserId then --NOTE: whether need to check responserId == swarmServerId ??
		return true, resp
	else
		return false, "request timeout"
	end
end

_requestSwarm = function(cmd, timeout, retryTimes)
	timeout = default(1)(timeout)
	retryTimes = default(0)(retryTimes)

	if not workState.swarmServerId then
		local serverId = rednet.lookup("swarm", "server")
		if serverId then
			workState.swarmServerId = serverId
		else
			return false, "swarm server not found"
		end
	end

	local ok, resp = _request(workState.swarmServerId, cmd, "swarm-service", "swarm-response", timeout)
	if ok then
		local ok2, res = eval(resp)
		if ok2 then
			return unpack(res)
		else
			log.bug("[_requestSwarm] faild to parse response: ", literal({cmd = cmd, response = res}))
			return false, "faild to parse response"
		end
	else -- timeout
		workState.swarmServerId = nil
		if retryTimes >= 1 then
			return _requestSwarm(cmd, timeout, retryTimes - 1)
		else -- if retryTimes == 0 then
			return false, resp
		end
	end
end

-- | interactive register complex station
registerStation = mkIOfn(function()
end)

registerPassiveProvider = mkIO(function()
	reserveOneSlot()
	select(slot.findThat(slot.isEmpty))()
	suck(1)()
	local det = turtle.getItemDetail()
	drop(1)()
	if not det then
		log.bug("[registerPassiveProvider] cannot get item detail")
		return false
	end
	local stationDef = {
		pos = gpsPos(),
		dir = workState:aimingDir(),
		itemType = det.name,
		limitation = 0,
		deliverPriority = 0, --passive provider
	}
	return _requestSwarm("swarm.services.registerStation("..literal(stationDef)..")")
end)

registerActiveProvider = mkIO(function()
	local stationDef = {
		pos = gpsPos(),
		limitation = 0,
		deliverPriority = 98, --passive provider
	}
	rednet.send({
	})
end)

registerBuffer = mkIO(function()
	local stationDef = {
		pos = gpsPos(),
		reservation = 15,
		restockPriority = 89,
	}
	rednet.send({
	})
end)

registerRequester = mkIO(function()
	local stationDef = {
		pos = gpsPos(),
		reservation = 15,
		restockPriority = 99,
	}
	rednet.send({
	})
end)

inspectStation = mkIO(function()
end)

swarmServiceCo = function()
	rednet.receive()
	rednet.send()
end

requestFuelStation = mkIO(function()
	return O and {pos = O + B, dir = B}
end)

requestUnloadStation = mkIO(function()
	return O and {pos = O + B + U * 2, dir = B}
end)

requestNearestProviderStation = mkIOfn(function(itemName, itemCount, startPos)
	itemCount = default(1)(itemCount)
	startPos = default(workState.pos)(startPos)
	rednet.send()
	rednet.receive()
	return O and {pos = O + B, dir = B}
end)

requestStation = mkIOfn(function(itemName, itemCount, startPos, fuelLeft)
	itemCount = default(0)(itemCount)
	startPos = default(workState.pos)(startPos)
	fuelLeft = default(turtle.getFuelLevel())(fuelLeft)
	return _requestSwarm("swarm.services.requestStation("..literal(itemName, itemCount, startPos, fuelLeft)..")")
end)

