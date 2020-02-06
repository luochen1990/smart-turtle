--------- the Turtle Monad ( ReaderT workMode (StateT workState IO) ) ----------

workMode = {
	destroy = 1, -- whether auto dig when move blocked: 0:no dig, 1:dig cheap items only, 2:dig all non-protected
	violence = false, -- whether auto attack when move blocked
	retrySeconds = 2, -- seconds to retry before fail back when move blocked by other turtles
	workArea = nil, -- an electric fence
	backpackWhiteList = {}, -- not used yet
	backpackBlackList = {}, -- not used yet
	backpackPinnedSlots = {}, -- not used yet
	fuelStation = nil, -- {pos = nil, dir = nil}
	unloadStation = nil, -- {pos = nil, dir = nil}, -- not used yet
}

workState = {
	pos = nil, -- current pos
	facing = nil, -- current facing direction, const.dir.N/S/W/E
	aiming = 0, -- 0:front, 1:up, -1:down
	beginPos = nil, -- pos when the program start
	isDetouring = false, -- not very useful yet
	interruptStack = {}, -- { {reason: "OutOfFuel"/"NeedUnload", pos: vec(100,0,0)} } -- not used yet
}

function workState:aimingDir()
	if self.aiming == 0 then return self.facing
	else return vec(0, self.aiming, 0) end
end

function workState:lateralDir() -- a direction which is perpendicular to aimingDir
	if self.aiming == 0 then return const.dir.U
	else return self.facing end
end

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

