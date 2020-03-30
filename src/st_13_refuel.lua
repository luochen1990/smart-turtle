-------------------------------- auto refuel  ----------------------------------

if turtle then

	fuelGot = mkIO(turtle.getFuelLevel)
	fuelGot.safeLine = mkIO(function() return vec.manhat(workState.pos - O) end)
	fuelGot.swarmSafeLine = mkIO(function() return workState.fuelStation and vec.manhat(workState.pos - workState.fuelStation.pos) end)
	fuelGot.reserved = mkIO(function() return const.fuelReserveRatio * math.max(fuelGot.safeLine(), fuelGot.swarmSafeLine() or 0) end)
	fuelGot.available = mkIO(function() return fuelGot() - fuelGot.reserved() end)

	_fuelToReserve1 = function(dests, begin)
		local s = default(workState.pos)(begin)
		local r = 0
		for _, t in ipairs(dests) do
			r = math.max(r, vec.manhat(s - t))
		end
		return r
	end

	_fuelToReserve = function(dests, begins)
		begins = default({workState.pos})(begins)
		local r = 0
		for _, s in ipairs(begins) do
			for _, t in ipairs(dests) do
				r = math.max(r, vec.manhat(s - t))
			end
		end
		return r
	end

	_fuelCount = (function(limit)
		return function(heat, target, got)
			got = got or turtle.getFuelLevel()
			return math.min(math.floor((limit - got) / heat), math.ceil((target - got) / heat))
		end
	end)(turtle.getFuelLimit())

	refuel = mkIO(function()
		local det = turtle.getItemDetail()
		if not det then return false, "no fuel available in selected slot" end
		local heat = _item.fuelHeatContent(det.name)
		if not heat then return false, "selected slot cannot be use as fuel" end
		local limit = turtle.getFuelLimit()
		local got = turtle.getFuelLevel()
		if got + heat > limit then return false, "fuel tank almost full" end
		return turtle.refuel(math.floor((limit - got) / heat))
	end)

	refuel.fromBackpack = mkIO(function()
		return saveSelected(rep(select(slot.isFuel) * refuel))()
	end)

	refuel.fromBackpack.to = markIOfn("refuel.fromBackpack.to(target)")(function(target)
		local limit = turtle.getFuelLimit()
		return saveSelected(mkIO(function()
			while true do
				local got = turtle.getFuelLevel()
				if got >= target then return true end
				local sn = slot._findThat(slot.isFuel)
				if not sn then return false, "no more fuel available" end
				local det = turtle.getItemDetail(sn)
				local heat = det and _item.fuelHeatContent(det.name)
				if got + heat > limit then return false, "fuel tank almost full" end
				turtle.select(sn)
				turtle.refuel(_fuelCount(heat, target, got))
			end
		end))
	end)

	cryForHelpRefueling = markIOfn("cryForHelpRefueling(destPos,availableLowBar)")(mkIOfn(function(destPos, availableLowBar)
		workState.cryingFor = "refueling"

		local reserveForMove = vec.manhat(workState.pos - destPos) * const.fuelReserveRatio
		local reserveForRefuel = _fuelToReserve({O, (workState.fuelStation and workState.fuelStation.pos or nil)}, {workState.pos, destPos}) * const.fuelReserveRatio
		local lowBar = availableLowBar + reserveForMove + reserveForRefuel

		log.cry("Help me! I want move to "..show(destPos).." and need "..lowBar.." fuel at "..show(workState.pos))
		with({asFuel = true})(retry(refuel.fromBackpack.to(lowBar)))()
		workState.cryingFor = false
	end))

	-- | the refuel interrput: back to fuel station and refuel
	-- , if destState is provided then go to destState.pos after refuel
	refuel.fromStation = markIOfn("refuel.fromStation(availableLowBar,availableHighBar)")(mkIOfn(function(availableLowBar, availableHighBar, destState)
		if workState.isRefueling then return false, "already interrputing to refuel" end
		if not workState:isOnline() then return false, "turtle is offline" end

		local back_st = workState:pickle()
		table.insert(workState.interruptionStack, {reason = "refueling", back = back_st, dest = destState})
		workState.isRefueling = true

		local _, _, singleTripCost, station = _visitStation({
			reqStation = function(triedTimes, singleTripCost)
				local ok, station = requestFuelStation(0)() --TODO: more precise calc
				return ok, station
			end,
			beforeLeave = function(triedTimes, singleTripCost, station)
				log.verb("Visiting fuel station "..show(station.pos).."...")
			end,
			beforeRetry = function(triedTimes, singleTripCost, station, cost)
				log.verb("Cost "..cost.." to reach "..triedTimes.."th fuel station, but still unavailable, trying next...")
			end,
			beforeWait = function(triedTimes, singleTripCost, station)
				log.verb("Cost "..singleTripCost.." and visited "..triedTimes.." fuel stations, but all unavailable, now waiting for help...")
			end,
			waitForUserHelp = function(triedTimes, singleTripCost, station)
				cryForHelpRefueling(back_st.pos, availableLowBar)()
			end,
		})
		if station then
			workState.fuelStation = station
		else --NOTE: implies user helped
			return true
		end

		local reserveForBack = singleTripCost * const.fuelReserveRatio
		local reserveForRefuel = _fuelToReserve1({workState.pos, O}, back_st.pos) * const.fuelReserveRatio
		local lowBar = availableLowBar + reserveForBack + reserveForRefuel
		local highBar = default(availableLowBar * const.greedyRefuelRatio)(availableHighBar) + reserveForBack + reserveForRefuel
		log.verb("Cost "..singleTripCost.." to reach this fuel station, now refueling (".. lowBar ..")...")

		-- begin refuel
		local greedyTarget = math.max(const.activeRadius * const.greedyRefuelRatio, highBar)
		local enoughRefuel = with({asFuel = station.itemType})(refuel.fromBackpack.to(lowBar))
		local greedyRefuel = with({asFuel = station.itemType})(refuel.fromBackpack.to(greedyTarget))
		local heat = _item.fuelHeatContent(station.itemType)
		local suckFuelTo = function(target)
			return suck.exact(math.min(station.itemStackLimit, _fuelCount(heat, target)))
		end
		rep(retry(suckFuelTo(lowBar)) * -enoughRefuel)() -- repeat until fuel enough
		if os.getComputerLabel() then
			rep(suckFuelTo(greedyTarget) * -greedyRefuel)() -- try to greedy refuel, stop when suck failed
		end
		-- refuel done
		log.verb("Finished refueling, now back to work pos "..show(back_st.pos))

		local interruption = workState.interruptionStack[#workState.interruptionStack]
		interruption.recovering = true
		workState.isRefueling = false
		local recovered = recover(interruption.dest or interruption.back)()
		if recovered then
			workState.interruptionStack[#workState.interruptionStack] = nil
			return true
		else
			cryForHelpMoving()
		end
	end))

	refuel._prepare = mkIOfn(function(opts)
		local availableLowBar = default(0)(opts.availableLowBar)
		local destPos = default(workState.pos)(opts.destPos)

		local reserveForMove = vec.manhat(workState.pos - destPos) * const.fuelReserveRatio
		local reserveForRefuel = _fuelToReserve({O, (workState.fuelStation and workState.fuelStation.pos or nil)}, {workState.pos, destPos}) * const.fuelReserveRatio
		local lowBar = availableLowBar + reserveForMove + reserveForRefuel
		if turtle.getFuelLevel() >= lowBar then return true end

		local ok = refuel.fromBackpack.to(lowBar)()
		if not ok then -- no enough fuel in backpack
			if workMode.allowInterruption and not workState.isRefueling then -- go to fuel station
				ok = with({destroy = 1})(refuel.fromStation(availableLowBar, opts.availableHighBar, opts.destState))()
			end
		end
		return ok
	end)

	refuel.prepare = markIOfn("refuel.prepare()")(function(availableLowBar, availableHighBar)
		return refuel._prepare({
			availableLowBar = availableLowBar,
			availableHighBar = availableHighBar,
		})
	end)

	refuel.prepareMoveStep = markIOfn("refuel.prepareMoveStep()")(function(dir, availableLowBar, availableHighBar)
		return refuel._prepare({
			destPos = workState.pos + dir,
			availableLowBar = availableLowBar,
			availableHighBar = availableHighBar,
		})
	end)

	refuel.prepareMoveTo = markIOfn("refuel.prepareMoveTo()")(function(destPos, availableLowBar, availableHighBar)
		return refuel._prepare({
			destPos = destPos,
			availableLowBar = availableLowBar,
			availableHighBar = availableHighBar,
			destState = {pos = destPos, gpsCorrected = workState.gpsCorrected},
		})
	end)

end

