------------------------- backpack slots management ----------------------------

if turtle then

	slot = (function()
		local slot = {}

		slot.isEmpty = function(sn) return turtle.getItemCount(sn) == 0 end
		slot.isNonEmpty = function(sn) return turtle.getItemCount(sn) > 0 end
		slot.isFuel = function(sn)
			local det = turtle.getItemDetail(sn)
			return det and (workMode:useAsFuel(det.name)) and not not _item.fuelHeatContent(det.name)
		end
		slot.fuelHeatContent = function(sn)
			local det = turtle.getItemDetail(sn)
			return (det and _item.fuelHeatContent(det.name) or 0) * (det and det.count or 0)
		end
		slot.name = function(sn) local det = turtle.getItemDetail(sn); return det and det.name end
		slot.count = turtle.getItemCount
		slot.detail = turtle.getItemDetail
		slot.stackLimit = function(sn) local n = turtle.getItemCount(sn); return n > 0 and n + turtle.getItemSpace(sn) end
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
				return slot._findThat(slotFilter, beginSlot)
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
				return slot._findLastThat(slotFilter, beginSlot)
			else
				error("[slot.findLast(slotFilter)] slotFilter should be string or function")
			end
		end

		slot.findDroppable = function(keepLevel)
			if keepLevel == true then keepLevel = 3 end
			if keepLevel == false then keepLevel = 0 end
			local sn
			if keepLevel < 3 then
				sn = slot._findLastThat(slot.isCheap, #workMode.pinnedSlot + 1)
				if not sn and keepLevel < 2 then
					sn = slot._findLastThat(slot.isNotValuable, #workMode.pinnedSlot + 1)
					if not sn and keepLevel < 1 then
						sn = slot._findLastThat(slot.isValuable, #workMode.pinnedSlot + 1)
					end
				end
			end
			return sn ~= nil and sn
		end

		-- | count item number in the backpack
		-- , countSingleSlot(sn) = c  where c is either number or boolean
		slot._countVia = function(countSingleSlot, beginSlot, limit)
			local cnt = 0
			for sn = default(1)(beginSlot), const.turtle.backpackSlotsNum do
				local n = countSingleSlot(sn)
				if type(n) == "boolean" then
					if n == true then n = 1 else n = 0 end
				elseif type(n) == "number" then
					cnt = cnt + n
				end
				if limit and cnt >= limit then break end
			end
			return cnt
		end

		-- | a polymorphic wrapper of _countVia
		slot.count = function(slotCounter, beginSlot, limit)
			if type(slotCounter) == "string" then
				local nameGlob = glob(slotCounter)
				return slot._countVia(function(sn)
					local det = turtle.getItemDetail(sn)
					if det and nameGlob(det.name) then return det.count else return 0 end
				end, beginSlot, limit)
			elseif type(slotCounter) == "function" then
				return slot._countVia(slotCounter, beginSlot, limit)
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
			return turtle.getSelectedSlot() == selector or turtle.select(selector)
		elseif type(selector) == "string" or type(selector) == "function" then
			local sn = slot.find(selector, beginSlot)
			return sn and (turtle.getSelectedSlot() == sn or turtle.select(sn))
		else
			error("[select(selector)] selector should be number or string or function")
		end
	end))

	selectLast = markIOfn("selectLast(selector)")(mkIOfn(function(selector)
		local sn = slot.findLast(selector)
		return sn and turtle.select(sn)
	end))

	discard = markIO("discard")(fmap(slot.isFuel)(selected) * mkIO(turtle.refuel) * fmap(slot.isEmpty)(selected) + saveDir(turn.lateral * -isContainer * drop) + -isContainer * drop)

	cryForHelpUnloading = markIO("cryForHelpUnloading")(mkIO(function()
		workState.cryingFor = "unloading"
		log.cry("Help me! I need to unload backpack at "..show(workState.pos).." (first "..#workMode.pinnedSlot.."slots pinned)")
		retry(-mkIO(slot._findThat, slot.isNonEmpty, #workMode.pinnedSlot + 1))()
		workState.cryingFor = false
	end))

	-- | unload turtle's backpack to depot or station
	unload = markIO("unload")(mkIO(function()
		if not workMode.allowInterruption then return false end
		local succ = false
		if workMode.preferLocal then
			succ = (unloadToDepot + unloadToStation)()
		else -- prefer swarm
			succ = (unloadToStation + unloadToDepot)()
		end
		return succ or (try(move.to(workMode.depot or O)) * cryForHelpUnloading)()
	end))

	unloadToDepot = markIO("unloadToDepot")(mkIO(function()
		if not workMode.depot then return false, "workMode.depot is not provided" end

		return saveSelected(savePosp(visitDepot(workMode.depot) * isStation * rep(select(slot.isNonEmpty, #workMode.pinnedSlot + 1) * drop)))()
	end))

	-- | the unload interrput: back to unload station and clear the backpack
	unloadToStation = markIO("unloadToStation")(mkIO(function()
		if not workState:isOnline() then return false, "workState:isOnline() is false" end

		workState.isUnloading = true
		workState.back = workState.back or getPosp() --NOTE: in case we are already in another interruption

		_visitStation({
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
		saveSelected(isStation * rep(select(slot.isNonEmpty, #workMode.pinnedSlot + 1) * drop))()

		if not slot.find(slot.isEmpty) then
			cryForHelpUnloading()
		end

		recoverPosp(workState.back)()
		workState.back = nil
		workState.isUnloading = false
		return true
	end))

	-- | tidy backpack to reserve at least 1 empty slot
	-- , when success, return the sn of one reserved empty slot
	-- , there will be at least 3 empty unpinned slots if tidied/dropped/unloaded
	reserveSlot = markIO("reserveSlot")(mkIO(function()
		local sn = slot._findLastThat(slot.isEmpty, #workMode.pinnedSlot + 1)
		if sn then return true end -- have at least 1 empty slot
		-- tidy backpack
		slot.tidy()
		local empty_cnt = slot.count(slot.isEmpty, #workMode.pinnedSlot + 1, 3)
		if empty_cnt >= 3 then return true end -- have at least 3 empty slot after tidy

		local keepLevel = (workState.isUnloading and 1) or workMode.keepItems
		local discarded = saveSelected(replicate(3 - empty_cnt)(mkIO(slot.findDroppable, keepLevel):pipe(select) * discard))()
		empty_cnt = empty_cnt + discarded

		if empty_cnt >= 3 then return true end -- have at least 3 empty slot after discarded

		if not workState.isUnloading then -- avoid recursion
			local ok = unload()
			if ok then return true end
		end
		return false
	end))

	-- | if specified item count is less than lowBar, then restock it to highBar
	ensureItemFromBackpack = markIOfn("ensureItemFromBackpack(itemType,lowBar)")(mkIOfn(function(itemType, lowBar)
		lowBar = default(2)(lowBar)
		local sn = turtle.getSelectedSlot()
		local det = turtle.getItemDetail(sn)
		if det and det.name ~= itemType then
			reserveSlot()
			turtle.transferTo(slot.find(slot.isEmpty))
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
		log.cry("I need "..count.." "..itemType.." at "..show(myPos())) --TODO: create swarm task
		return retry(try(suck.exactTo(count, itemType)) * ensureItemFromBackpack(itemType, count))()
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
			return (savePosp(visitDepot(depot) * (suck.exact(need, itemType) + callForRestocking(itemType, need))))()
		else
			return (savePosp(visitDepot({pos = O, dir = F}) * waitForHelpRestocking(itemType, need)))()
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

	-- | slotConfig is like {[1] = {desc, itemFilter, lowBar, highBar, depot}}
	askForPinnedSlot = function(slotConfig)
		local pinnedSlot = {}
		for i, cfg in ipairs(slotConfig) do
			printC(colors.blue)("slot ["..i.."] need "..cfg.desc)
		end
		for i, cfg in ipairs(slotConfig) do
			turtle.select(i)
			local det = retry(mkIO(function()
				local det = turtle.getItemDetail(i)
				if det then
					if (not cfg.itemFilter or cfg.itemFilter(det.name)) then
						printC(colors.green)("slot ["..i.."] got item "..showLit(det.name))
						det.stackLimit = slot.stackLimit(i)
						return det
					else
						printC(colors.yellow)("slot ["..i.."] got invalid item "..showLit(det.name)..", please try other type of item")
						sleep(1)
						reserveSlot()
						turtle.transferTo(slot.find(slot.isEmpty))
						return false
					end
				else
					return false
				end
			end))()
			pinnedSlot[i] = {
				itemType = det.name,
				stackLimit = det.stackLimit,
				lowBar = 1,
				highBar = det.stackLimit,
				depot = cfg.depot or {pos = O + R * i, dir = B},
			}
			--TODO: support edit default value
		end
		return pinnedSlot
	end
end

