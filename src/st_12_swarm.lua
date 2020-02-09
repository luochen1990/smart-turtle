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

requestFuelStation = mkIO(function()
	return O and {pos = O + B, dir = B}
end)

requestUnloadStation = mkIO(function()
	return O and {pos = O + B + U * 2, dir = B}
end)
