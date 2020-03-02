------------------------- backpack slots management ----------------------------

if turtle then

	slot = {
		isEmpty = function(sn) return turtle.getItemCount(sn) == 0 end,
		isNonEmpty = function(sn) return turtle.getItemCount(sn) > 0 end,
		isCheap = function(sn)
			local det = turtle.getItemDetail(sn)
			return det and const.cheapItems[det.name]
		end,
		isFuel = function(sn)
			local det = turtle.getItemDetail(sn)
			if workMode.asFuel then
				return det and det.name == workMode.asFuel and const.fuelHeatContent[det.name]
			else
				return det and const.fuelHeatContent[det.name]
			end
		end,
		isNamed = function(name)
			return function(sn)
				local det = turtle.getItemDetail(sn)
				return det and det.name == name
			end
		end,
		-- | find a specific slot sn, return nil when not find
		findThat = function(cond, beginSlot) -- find something after beginSlot which satisfy cond
			for sn = default(1)(beginSlot), const.turtle.backpackSlotsNum do
				if cond(sn) then return sn end
			end
		end,
		findLastThat = function(cond, beginSlot)
			for sn = const.turtle.backpackSlotsNum, default(1)(beginSlot), -1 do
				if cond(sn) then return sn end
			end
		end,
		find = function(name, beginSlot)
			return slot.findThat(slot.isNamed(name), beginSlot)
		end,
		findLast = function(name, beginSlot)
			return slot.findLastThat(slot.isNamed(name), beginSlot)
		end,

		-- count item number in the backpack
		countVia = function(countSingleSlot)
			local cnt = 0
			for sn = 1, const.turtle.backpackSlotsNum do
				local n = countSingleSlot(sn)
				if n then cnt = cnt + n end
			end
			return cnt
		end,
		count = function(name)
			return slot.countVia(function(sn)
				local det = turtle.getItemDetail(sn)
				if det and det.name == name then return det.count else return 0 end
			end)
		end,

		-- tidy slot
		fill = function(sn) -- use items in slots after sn to make slot sn as full as possible
			local saved_sn = turtle.getSelectedSlot()
			sn = default(saved_sn)(sn)
			local det = turtle.getItemDetail(sn)
			local count = (det and det.count) or 0
			local space = turtle.getItemSpace(sn)
			if count ~= 0 and space ~= 0 then
				for i = const.turtle.backpackSlotsNum, sn + 1, -1 do
					local det_i = turtle.getItemDetail(i)
					if det_i and det_i.name == det.name then
						turtle.select(i)
						turtle.transferTo(sn)
						space = space - det_i.count
						if space <= 0 then break end
					end
				end
			end
			turtle.select(saved_sn)
			return count ~= 0
		end,
		tidy = function()
			for sn = 1, const.turtle.backpackSlotsNum do slot.fill(sn) end
		end,
	}

	select = mkIOfn(function(selector)
		if type(selector) == "number" then
			return turtle.select(selector)
		elseif type(selector) == "string" then
			local sn = slot.find(selector)
			return sn ~= nil and turtle.select(sn)
		elseif type(selector) == "function" then
			local sn = slot.findThat(selector)
			return sn ~= nil and turtle.select(sn)
		elseif type(selector) == "table" and type(selector.run) == "function" then
			return select(selector())()
		else
			error("[select(selector)] type of selector cannot be "..tostring(selector))
		end
	end)

	selectLast = mkIOfn(function(selector)
		if type(selector) == "string" then
			local sn = slot.findLast(selector)
			return sn ~= nil and turtle.select(sn)
		elseif type(selector) == "function" then
			local sn = slot.findLastThat(selector)
			return sn ~= nil and turtle.select(sn)
		else
			error("[selectLast(selector)] type of selector cannot be "..tostring(selector))
		end
	end)

	-- | find some cheap item slot to drop
	dropCheapItemSlot = function()
		local dropSn = slot.findThat(slot.isCheap)
		if dropSn then
			local saved_sn = turtle.getSelectedSlot()
			turtle.select(dropSn)
			local drp = (saveDir(turn.lateral * -isContainer * drop()) + -isContainer * drop())
			turtle.select(saved_sn)
			if drp() then return dropSn end
		end
	end

	backpackEmpty = -mkIO(slot.findThat, slot.isNonEmpty)

	cryForHelpUnloading = function()
		log.cry("Help me! I need to unload backpack at "..show(workState.pos))
		retry(backpackEmpty)
	end

	-- | the unload interrput: back to unload station and clear the backpack
	unloadBackpack = function()
		workState.isUnloading = true
		workState.back = workState.back or getPosp() --NOTE: in case we are already in another interruption

		_robustVisitStation({
			reqStation = function(triedTimes, singleTripCost)
				local ok, station = requestUnloadStation(0)()
				return ok, station
			end,
			beforeLeave = function(triedTimes, singleTripCost, station)
				workState.unloadStation = station
				print("Visiting unload station "..show(station.pos).."...")
			end,
			beforeRetry = function(triedTimes, singleTripCost, station, cost)
				print("Cost "..cost.." to reach "..triedTimes.."th station, but still unavailable, trying next...")
			end,
			beforeWait = function(triedTimes, singleTripCost, station)
				print("Cost "..cost.." to reach "..triedTimes.."th station, but still unavailable, trying next...")
			end,
			waitForUserHelp = function(triedTimes, singleTripCost, station)
				cryForHelpUnloading()
			end,
		})

		-- drop items into station
		;( isStation *  rep(-backpackEmpty + retry(backpackEmpty + drop)) )()

		recoverPosp(workState.back)()
		workState.back = nil
		workState.isUnloading = false
		return true
	end

	-- | tidy backpack to reserve 1 empty slot
	-- , when success, return the sn of the reserved empty slot
	reserveOneSlot = mkIO(function() -- tidy backpack to reserve 1 empty slot
		local sn = slot.findLastThat(slot.isEmpty)
		if sn then return sn end
		-- tidy backpack
		slot.tidy()
		sn = slot.findLastThat(slot.isEmpty)
		if sn then return sn end
		if not workState.isUnloading then -- avoid recursion
			if not workMode.keepCheapItems then
				sn = dropCheapItemSlot()
				if sn then return sn end
			end
			if workMode.allowInterruption then
				local ok = unloadBackpack()
				if ok then return slot.findLastThat(slot.isEmpty) end
			end
		else
			return dropCheapItemSlot()
		end
	end)

end

