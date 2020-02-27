--------------------------------- turtle swarm ---------------------------------

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
		limitation = opts.limitation,
		deliverPriority = opts.deliverPriority,
		reservation = opts.reservation,
		restockPriority = opts.restockPriority,
		facing = opts.facing or nil,
		itemType = opts.itemType or nil,
		itemNumber = 0,
		isVisiting = false,
		currentQueueLength = 0,
		isVisiting = false,
		itemNumber = 0,
		latestCheckTime = now() - 100,
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

-- | interactive register complex station
registerStation = mkIOfn(function()
end)

registerPassiveProvider = mkIO(function()
	local stationDef = {
		pos = gpsPos(),
		limitation = 0,
		deliverPriority = 0, --passive provider
	}
	rednet.send({
	})
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

