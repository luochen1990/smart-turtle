--------- the Turtle Monad ( ReaderT workMode (StateT workState IO) ) ----------

if turtle then

	workMode = {
		verbose = true, -- whether broadcast verb log
		destroy = 1, -- whether auto dig when move blocked: 0:no dig, 1:dig cheap items only, 2:dig all non-protected
		violence = false, -- whether auto attack when move blocked
		detour = true, -- whether to detour when move.to or move.go blocked
		retrySeconds = 2, -- seconds to retry before fail back when move blocked by other turtles
		workArea = false, -- an electric fence
		asFuel = true, -- use what as fuel in backpack, when negative never refuel from backpack, when true use everything possible
		keepItems = 2, -- 0:always drop, 1:only keep valuable items, 2:keep non-cheap items, 3:keep all
		allowInterruption = true, -- whether allow turtle interrupt current task to refuel or unload or fetch
		pinnedSlot = {}, -- pinned slots, element like {itemType = "minecraft:coal", stackLimit = 64, lowBar = 2, highBar = 64, depot = {pos, dir}}
		depot = {pos = vec.zero, dir = -vec.axis.X}, -- local depot to unload items
		preferLocal = true, -- prefer to visit local depot or swarm station
		--backpackWhiteList = {}, -- not used yet
		--backpackBlackList = {}, -- not used yet
	}

	setmetatable(workMode, {__index = {
		useAsFuel = (function()
			local latest_asFuel = nil
			local latest_glob = nil
			return function(wm, itemName)
				if not wm.asFuel then
					return false
				elseif wm.asFuel == true then
					return true
				elseif wm.asFuel == latest_asFuel then
					return latest_glob(itemName)
				else
					latest_asFuel = wm.asFuel
					latest_glob = glob(latest_asFuel)
					return latest_glob(itemName)
				end
			end
		end)(),
	}})

	workState = {
		gpsCorrected = false,
		pos = vec.zero, -- current pos
		facing = vec.axis.X, -- current facing direction, should be one of E/S/W/N, init is E
		aiming = 0, -- 0:front, 1:up, -1:down
		fuelStation = false,
		unloadStation = false,
		isRefueling = false,
		isUnloading = false,
		isFetching = false,
		cryingFor = false,
		isRunningSwarmTask = false,
		moveNotCommitted = false,
		interruptionStack = {}, -- save interruption reason and back state
		hasModem = false,
	}
	O = vec.zero -- pos when process begin, this init value is used before gps corrected

	setmetatable(workState, {__index = {
		aimingDir = function()
			if workState.aiming == 0 then return workState.facing
			else return vec(0, workState.aiming, 0) end
		end,
		lateralDir = function()
			if workState.aiming == 0 then return const.dir.U
			else return workState.facing end
		end,
		preferDirections = function()
			local d0 = workState.facing
			local d1 = leftSide(d0)
			return {U, d0, d1, leftSide(d1), rightSide(d0), D}
		end,
		isOnline = function()
			if not workState.hasModem then return false, "wireless modem not available" end
			if not workState.gpsCorrected then return false, "gps not available" end
			--if not workState.fuelStation or workState.unloadStation then return false, "swarm server not available" end
			return true
		end,
		picklePosd = function()
			return {
				gpsCorrected = workState.gpsCorrected,
				pos = workState.pos,
				dir = workState:aimingDir(),
			}
		end,
		picklePosp = function()
			return {
				gpsCorrected = workState.gpsCorrected,
				pos = workState.pos,
				facing = workState.facing,
				aiming = workState.aiming,
			}
		end,
		pickle = function()
			return {
				gpsCorrected = workState.gpsCorrected,
				pos = workState.pos,
				facing = workState.facing,
				aiming = workState.aiming,
				selected = turtle.getSelectedSlot(),
			}
		end,
	}})

	-- | run io with specified workMode fields
	-- , NOTE: use `false` as a placeholder for `nil`
	with = function(wm_patch)
		return function(io)
			return mkIO(function()
				local _wm = workMode
				workMode = deepcopy(_wm)
				for k, v in pairs(wm_patch) do
					if workMode[k] ~= nil then
						workMode[k] = v
					else
						error("[with] workMode has no such field: `"..k.."`")
					end
				end
				r = { io() }
				workMode = _wm
				return unpack(r)
			end)
		end
	end

end
