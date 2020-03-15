------------------------- backpack slots management ----------------------------

if turtle then

	slot = (function()
		local slot = {}

		slot.isEmpty = function(sn) return turtle.getItemCount(sn) == 0 end
		slot.isNonEmpty = function(sn) return turtle.getItemCount(sn) > 0 end
		slot.isFuel = function(sn)
			local det = turtle.getItemDetail(sn)
			return det and (not workMode.asFuel or det.name == workMode.asFuel) and not not _item.fuelHeatContent(det.name)
		end
		slot.fuelHeatContent = function(sn)
			local det = turtle.getItemDetail(sn)
			return (det and _item.fuelHeatContent(det.name) or 0) * (det and det.count or 0)
		end
		slot.nameSat = function(judge)
			return function(sn)
				local det = turtle.getItemDetail(sn)
				return det and judge(det.name)
			end
		end
		slot.isCheap = slot.nameSat(_item.isCheap)
		slot.isValuable = slot.nameSat(_item.isValuable)
		slot.isNotValuable = slot.nameSat(_item.isNotValuable)
		slot.isNamed = function(namePat) return slot.nameSat(glob(namePat)) end

		-- | find a specific slot sn, return nil when not find
		slot._findThat = function(cond, beginSlot) -- find something after beginSlot which satisfy cond
			for sn = default(1)(beginSlot), const.turtle.backpackSlotsNum do
				if cond(sn) then return sn end
			end
		end

		-- | find from back to front
		slot._findLastThat = function(cond, beginSlot)
			for sn = const.turtle.backpackSlotsNum, default(1)(beginSlot), -1 do
				if cond(sn) then return sn end
			end
		end

		-- | a polymorphic wrapper of _findThat
		slot.find = function(slotFilter, beginSlot)
			if type(slotFilter) == "string" then
				local name = slotFilter
				return slot._findThat(slot.isNamed(name), beginSlot)
			elseif type(slotFilter) == "function" then
				return slot._findThat(slotFilter)
			else
				error("[slot.find(slotFilter)] slotFilter should be string or function")
			end
		end

		-- | a polymorphic wrapper of _findLastThat
		slot.findLast = function(slotFilter, beginSlot)
			if type(slotFilter) == "string" then
				local name = slotFilter
				return slot._findLastThat(slot.isNamed(name), beginSlot)
			elseif type(slotFilter) == "function" then
				return slot._findLastThat(slotFilter)
			else
				error("[slot.findLast(slotFilter)] slotFilter should be string or function")
			end
		end

		-- | count item number in the backpack
		-- , countSingleSlot(sn) = c  where c is either number or boolean
		slot._countVia = function(countSingleSlot)
			local cnt = 0
			for sn = 1, const.turtle.backpackSlotsNum do
				local n = countSingleSlot(sn)
				if type(n) == "boolean" then
					if n == true then n = 1 else n = 0 end
				end
				if n then cnt = cnt + n end
			end
			return cnt
		end

		-- | a polymorphic wrapper of _countVia
		slot.count = function(slotCounter)
			if type(slotCounter) == "string" then
				local name = slotCounter
				return slot._countVia(function(sn)
					local det = turtle.getItemDetail(sn)
					if det and det.name == name then return det.count else return 0 end
				end)
			elseif type(slotCounter) == "function" then
				return slot._countVia(slotCounter)
			else
				error("[slot.count(slotCounter)] slotCounter should be string or function")
			end
		end

		-- | fill a slot using items from slots behind this slot
		slot.fill = function(sn)
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
		end

		-- | tidy backpack slots
		slot.tidy = function()
			for sn = 1, const.turtle.backpackSlotsNum do slot.fill(sn) end
		end

		return slot
	end)()

	select = mkIOfn(function(selector)
		if type(selector) == "number" then
			return turtle.select(selector)
		elseif type(selector) == "string" then
			local sn = slot.find(selector)
			return sn ~= nil and turtle.select(sn)
		elseif type(selector) == "function" then
			local sn = slot._findThat(selector)
			return sn ~= nil and turtle.select(sn)
		else
			error("[select(selector)] type of selector cannot be "..tostring(selector))
		end
	end)

	selectLast = mkIOfn(function(selector)
		if type(selector) == "string" then
			local sn = slot.findLast(selector)
			return sn ~= nil and turtle.select(sn)
		elseif type(selector) == "function" then
			local sn = slot._findLastThat(selector)
			return sn ~= nil and turtle.select(sn)
		else
			error("[selectLast(selector)] type of selector cannot be "..tostring(selector))
		end
	end)

	discard = markIO("discard")(fmap(slot.isFuel)(selected) * mkIO(turtle.refuel) * fmap(slot.isEmpty)(selected) + saveDir(turn.lateral * -isContainer * drop()) + -isContainer * drop())

	backpackEmpty = -mkIO(slot._findThat, slot.isNonEmpty)

	cryForHelpUnloading = function()
		workState.cryingFor = "unloading"
		log.cry("Help me! I need to unload backpack at "..show(workState.pos))
		retry(backpackEmpty)
		workState.cryingFor = false
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
				log.verb("Visiting unload station "..show(station.pos).."...")
			end,
			beforeRetry = function(triedTimes, singleTripCost, station, cost)
				log.verb("Cost "..cost.." to reach "..triedTimes.."th station, but still unavailable, trying next...")
			end,
			beforeWait = function(triedTimes, singleTripCost, station)
				log.verb("Cost "..singleTripCost.." and visited "..triedTimes.." stations, but all unavailable, now waiting for help...")
			end,
			waitForUserHelp = function(triedTimes, singleTripCost, station)
				cryForHelpUnloading()
			end,
		})

		-- drop items into station
		log.verb("Begin unloading...")
		;( isStation * rep( select(slot.isNonEmpty) * drop() ) )()

		if not slot.find(slot.isEmpty) then
			cryForHelpUnloading()
		end

		recoverPosp(workState.back)()
		workState.back = nil
		workState.isUnloading = false
		return true
	end

	selectDroppable = function(keepLevel)
		local sel = pure(false)
		if keepLevel == true then keepLevel = 3 end
		if keepLevel == false then keepLevel = 0 end
		if keepLevel < 3 then
			sel = select(slot.isCheap)
			if keepLevel < 2 then
				sel = sel + select(slot.isNotValuable)
				if keepLevel < 1 then
					sel = sel + select(slot.isValuable)
				end
			end
		end
		return sel
	end

	-- | tidy backpack to reserve 1 empty slot
	-- , when success, return the sn of the reserved empty slot
	reserveOneSlot = mkIO(function() -- tidy backpack to reserve 1 empty slot
		local sn = slot._findLastThat(slot.isEmpty)
		if sn then return sn end
		-- tidy backpack
		slot.tidy()
		sn = slot._findLastThat(slot.isEmpty)
		if sn then return sn end

		if not workState.isUnloading then -- avoid recursion
			sn = saveSelected(selectDroppable(workMode.keepItems) * discard * selected)()
			if sn then return sn end

			if workMode.allowInterruption then
				local ok = unloadBackpack()
				if ok then return slot._findLastThat(slot.isEmpty) end
			end
		else
			return saveSelected(selectDroppable(1) * discard * selected)()
		end
	end)

end

