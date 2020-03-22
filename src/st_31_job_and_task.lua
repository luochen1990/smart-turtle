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

swarmScan = function(area, mainDir, layerFilter)
	return mkIOfn(function(io)
		local t0 = task("", {})
	end)
end

