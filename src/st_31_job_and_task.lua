--------------------------------- task and job ---------------------------------

task = (function()
	local _task_mt = {}
	local new = function(command, opts) -- {env?, beginPos?, workArea?, costEstimate?}
		local t = {
			command = command,
			opts = opts,
		}
		setmetatable(t, _task_mt)
		return t
	end
	_task_mt.__literal = function(t)
		return "task("..literal(t.command, t.opts)..")"
	end
	local task = {
		new = new,
		isTask = function(x) return getmetatable(x) == _task_mt end,
	}
	setmetatable(task, {
		__call = function(_, cmd, opts) return new(cmd, opts) end,
	})
	return task
end)()

job = (function()
	local _job_mt = {}
	local new = function(mode, subNodes)
		local j = {mode = mode, subNodes = subNodes}
		setmetatable(j, _job_mt)
		return j
	end
	_job_mt.__literal = function(j)
		return "job."..j.mode.."("..literal(j.subNodes)..")"
	end
	local job = {
		par = function(subNodes) return new("par", subNodes) end,
		seq = function(subNodes) return new("seq", subNodes) end,
	}
	return job
end)()

--------------------------------- swarm scan -----------------------------------

-- | split an big area into many small areas
-- , every small area should less than or equal to maxPieceSize
-- , and this algorithm attempt to maximize the size of the smallest piece
splitArea = function(area, maxPieceSize)
	local vol = area:volume()
	if vol <= maxPieceSize then
		return {area}
	else
		local piecesCount = math.ceil(vol / maxPieceSize)
		local axises = {vec.axis.X, vec.axis.Y, vec.axis.Z}
		sort(axises, comparator(function(ax) return math.abs(area.diag:dot(ax)) end))
		local l1 = area.diag:dot(axises[1]) + 1
		local l2 = area.diag:dot(axises[2]) + 1
		local l3 = area.diag:dot(axises[3]) + 1
		local s1, s2, s3
		if l1 >= maxPieceSize then
			local c1 = math.ceil(l1 / maxPieceSize)
			local l = math.ceil(l1 / c1)
		else -- l1 < maxPieceSize
			s1 = l1
			if l1 * l2 >= maxPieceSize then
				s2 = math.floor(maxPieceSize / l1)
			else -- l1 * l2 < maxPieceSize, but l1 * l2 * l3 > maxPieceSize
			end
		end
		local ls = {}
	end
end

swarmScan = function(area, mainDir, layerFilter)
	return mkIOfn(function(tsk)
		assert(task.isTask(tsk))
		local costEst = tsk:costEstimate() + 1
		local singleTaskSize = math.max(math.ceil(60 / costEst), math.sqrt(area:volume()))
		if mainDir then
			local pieces = splitArea(area, singleTaskSize)
			local parJobs = {}
			for _, a in ipairs(pieces) do
				local seqTasks = {}
				for i = 0, math.abs(area.diag:dot(mainDir)) do
					if not layerFilter or layerFilter(i) then
						local ai = a:shift(mainDir * i)
						local cmd = "scan("..literal(ai)..")("..tsk.command..")"
						table.insert(seqTasks, task(cmd, {workArea = ai, costEstimate = ai:volume() * costEst}))
					end
				end
				table.insert(parJobs, job.seq(seqTasks))
			end
			return job.par(parJobs)
		else
			local pieces = splitArea(area, singleTaskSize)
			local parTasks = {}
			for _, a in ipairs(pieces) do
				local cmd = "scan("..literal(a)..")("..tsk.command..")"
				table.insert(parTasks, task(cmd, {workArea = a, costEstimate = a:volume() * costEst}))
			end
			return job.par(parTasks)
		end
	end)
end

