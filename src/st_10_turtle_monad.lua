--------- the Turtle Monad ( ReaderT workMode (StateT workState IO) ) ----------

if turtle then

	workMode = {
		destroy = 1, -- whether auto dig when move blocked: 0:no dig, 1:dig cheap items only, 2:dig all non-protected
		violence = false, -- whether auto attack when move blocked
		detour = true, -- whether to detour when move.to or move.go blocked
		retrySeconds = 2, -- seconds to retry before fail back when move blocked by other turtles
		workArea = nil, -- an electric fence
		backpackWhiteList = {}, -- not used yet
		backpackBlackList = {}, -- not used yet
		backpackPinnedSlots = {}, -- not used yet
	}

	workState = {
		pos = vec.zero, -- current pos
		facing = const.dir.E, -- current facing direction, const.dir.N/S/W/E
		aiming = 0, -- 0:front, 1:up, -1:down
		beginPos = vec.zero, -- pos when the program start
		swarmServerId = nil,
		fuelStation = nil, -- {pos, dir}
		unloadStation = nil, -- {pos, dir}
		isDetouring = false, -- only for inspect
		isRefueling = false,
		isUnloading = false,
	}

	setmetatable(workState, {__index = {
		aimingDir = function()
			if workState.aiming == 0 then return workState.facing
			else return vec(0, workState.aiming, 0) end
		end,
		lateralDir = function()
			if workState.aiming == 0 then return const.dir.U
			else return workState.facing end
		end,
	}})

	-- | run io with specified workMode fields
	with = function(wm_patch)
		return function(io)
			return mkIO(function()
				local _wm = workMode
				workMode = deepcopy(_wm)
				for k, v in pairs(wm_patch) do workMode[k] = v end
				r = {io()}
				workMode = _wm
				return unpack(r)
			end)
		end
	end

end
