--------------------------------- turtle swarm ---------------------------------

mkTask = function(opts)
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
	assert(t.type and t.beginPos and t.estCost and t.command, "mkTask(opts) lack required field")
	return t
end

mkStation = function(opts)
	local s = {
		pos = opts.pos,
		facing = opts.facing,
		cargo = opts.cargo,
		limitation = opts.limitation,
		deliverPriority = opts.deliverPriority,
		reservation = opts.reservation,
		restockPriority = opts.restockPriority,
		queueLength = 0,
		idle = true,
		inventory = 0,
		updateTime = now() - 100,
	}
	assert(s.pos and ((s.limitation and s.deliverPriority) or (s.reservation and s.restockPriority)), "mkStation(opts) lack required field")
	return s
end

mkWorker = function(opts)
	local w = {
		id = opts.id,
		latestPos = nil,
		latestReportTime = nil,
		state = "idle", -- or "busy" or "interrapt"
	}
	return w
end

