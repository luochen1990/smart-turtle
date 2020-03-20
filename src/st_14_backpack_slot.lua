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
		slot.itemName = function(sn)
			local det = turtle.getItemDetail(sn)
			return det and det.name
		end
		slot.stackLimit = function(sn)
			local n = turtle.getItemCount(sn)
			local s = turtle.getItemSpace(sn)
			return n ~= 0 and n + s
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
				local nameGlob = glob(slotCounter)
				return slot._countVia(function(sn)
					local det = turtle.getItemDetail(sn)
					if det and nameGlob(det.name) then return det.count else return 0 end
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

	select = markIOfn("select(selector,beginSlot)")(mkIOfn(function(selector, beginSlot)
		if type(selector) == "number" then
			return turtle.select(selector)
		else
			local sn = slot.find(selector, beginSlot)
			return sn and turtle.select(sn)
		end
	end))

	selectLast = markIOfn("selectLast(selector)")(mkIOfn(function(selector)
		local sn = slot.findLast(selector)
		return sn and turtle.select(sn)
	end))

	discard = markIO("discard")(fmap(slot.isFuel)(selected) * mkIO(turtle.refuel) * fmap(slot.isEmpty)(selected) + saveDir(turn.lateral * -isContainer * drop()) + -isContainer * drop())

	cryForHelpUnloading = markIO("cryForHelpUnloading")(mkIO(function()
		workState.cryingFor = "unloading"
		log.cry("Help me! I need to unload backpack at "..show(workState.pos).." (first "..#workMode.pinnedSlot.."slots pinned)")
		retry(-mkIO(slot._findThat, slot.isNonEmpty, #workMode.pinnedSlot + 1))()
		workState.cryingFor = false
	end))

	-- | the unload interrput: back to unload station and clear the backpack
	unloadBackpack = markIO("unloadBackpack")(mkIO(function()
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
		;( isStation * rep( select(slot.isNonEmpty, #workMode.pinnedSlot + 1) * drop() ) )()

		if not slot.find(slot.isEmpty) then
			cryForHelpUnloading()
		end

		recoverPosp(workState.back)()
		workState.back = nil
		workState.isUnloading = false
		return true
	end))

	selectDroppable = markIOfn("selectDroppable")(function(keepLevel)
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
	end)

	-- | tidy backpack to reserve 1 empty slot
	-- , when success, return the sn of the reserved empty slot
	reserveOneSlot = markIO("reserveOneSlot")(mkIO(function() -- tidy backpack to reserve 1 empty slot
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
	end))

	-- | if specified item count is less than lowBar, then restock it to highBar
	ensureItemFromBackpack = markIOfn("ensureItemFromBackpack(itemType,lowBar)")(mkIOfn(function(itemType, lowBar)
		lowBar = default(2)(lowBar)
		local sn = turtle.getSelectedSlot()
		local det = turtle.getItemDetail(sn)
		if det and det.name ~= itemType then
			turtle.transferTo(reserveOneSlot())
			det = nil
		end
		if not det then
			local sn2 = slot.find(itemType)
			if sn2 then
				turtle.select(sn2); turtle.transferTo(sn); turtle.select(sn)
				det = turtle.getItemDetail(sn)
			end
		end
		assert(not det or det.name == itemType)
		local got
		if det then
			if det.count >= lowBar then
				return true
			else
				local totalCount = slot.count(itemType)
				if totalCount >= lowBar then
					slot.fill(sn)
					return true
				else
					got = totalCount
				end
			end
		else -- no such item in backpack
			got = 0
		end
		return false, got
	end))

	callForRestocking = markIOfn("callForRestocking(itemType,count)")(mkIOfn(function(itemType, count)
		log.cry("I need "..count.." "..itemType.." at "..show(myPos()))
		return retry(suckExact(count, itemType) * ensureItemFromBackpack(itemType, count))()
	end))

	waitForHelpRestocking = markIOfn("waitForHelpRestocking(itemType,count,sn)")(mkIOfn(function(itemType, count)
		log.cry("I need "..count.." "..itemType.." at "..show(myPos()))
		return retry(ensureItemFromBackpack(itemType, count))()
	end))

	ensureItem = markIOfn("ensureItem(itemType,lowBar,highBar)")(mkIOfn(function(itemType, lowBar, highBar)
		lowBar = default(2)(lowBar)
		local ok, got = ensureItemFromBackpack(itemType, lowBar)()
		if ok then return true end
		-- need restock here
		local sn = turtle.getSelectedSlot()
		local pinned = workMode.pinnedSlot[sn]
		local stackLimit = (pinned and pinned.stackLimit) or slot.stackLimit(sn) or 1
		highBar = math.max(lowBar, default(math.max(stackLimit, lowBar * 2))(highBar))
		local need = highBar - got
		local depot = (pinned and pinned.depot)
		if depot then
			return (savePosp(visitStation(depot) * (suckExact(need, itemType) + callForRestocking(itemType, need))))()
		else
			return (savePosp(visitStation({pos = workState.beginPos, dir = F}) * waitForHelpRestocking(itemType, need)))()
		end
	end))

	ensureSlot = markIO("ensureSlot")(mkIO(function()
		local sn = turtle.getSelectedSlot()
		local pinned = workMode.pinnedSlot[sn]
		if pinned then
			return ensureItem(pinned.itemType, pinned.lowBar or 2, pinned.highBar)()
		else -- not pinned
			local det = turtle.getItemDetail(sn)
			if det then
				return ensureItem(det.name, 2)()
			else
				return false
			end
		end
	end))
end

