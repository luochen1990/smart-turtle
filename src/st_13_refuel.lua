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

	refuel = mkIO(function()
		local det = turtle.getItemDetail()
		if not det then return false, "no fuel available in selected slot" end
		local heat = _item.fuelHeatContent(det.name)
		if not heat then return false, "selected slot cannot be use as fuel" end
		local limit = turtle.getFuelLimit()
		local got = turtle.getFuelLevel()
		if got + heat > limit then return false, "fuel tank almost full" end
		turtle.refuel(math.floor((limit - got) / heat))
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
				turtle.refuel(math.min(math.floor((limit - got) / heat), math.ceil((target - got) / heat)))
			end
		end))
	end)

	cryForHelpRefueling = markIOfn("cryForHelpRefueling(nStep)")(mkIOfn(function(nStep)
		workState.cryingFor = "refueling"
		log.cry("Help me! I need "..nStep.." fuel at "..show(workState.pos))
		with({asFuel = false})(retry(refuelFromBackpack(nStep)))()
		workState.cryingFor = false
	end))

	-- | the refuel interrput: back to fuel station and refuel
	refuel.fromStation = markIOfn("refuel.fromStation(availableLowBar,availableHighBar)")(mkIOfn(function(availableLowBar, availableHighBar)
		if not workState:isOnline() then return false, "turtle is offline" end

		workState.isRefueling = true
		workState.back = workState.back or getPosp() --NOTE: in case we are already in another interruption

		local singleTripCost
		_robustVisitStation({
			reqStation = function(triedTimes, singleTripCost)
				local ok, station = requestFuelStation(availableLowBar + singleTripCost * 2)()
				return ok, station
			end,
			beforeLeave = function(triedTimes, singleTripCost, station)
				workState.fuelStation = station
				log.verb("Visiting fuel station "..show(station.pos).."...")
			end,
			beforeRetry = function(triedTimes, singleTripCost, station, cost)
				log.verb("Cost "..cost.." to reach "..triedTimes.."th fuel station, but still unavailable, trying next...")
			end,
			beforeWait = function(triedTimes, singleTripCost, station)
				log.verb("Cost "..singleTripCost.." and visited "..triedTimes.." fuel stations, but all unavailable, now waiting for help...")
			end,
			waitForUserHelp = function(triedTimes, singleTripCost, station)
				cryForHelpRefueling()
			end,
			afterArrive = function(triedTimes, singleTripCost, station)
				singleTripCost = singleTripCost
			end,
		})

		local reserveForBack = singleTripCost * const.fuelReserveRatio
		local reserved = reserveForBack + _fuelToReserve1({workState.pos, O}, workState.back.pos)
		local lowBar = availableLowBar + reserved
		local highBar = default(availableLowBar * const.greedyRefuelRatio)(availableHighBar) + reserved
		log.verb("Cost "..singleTripCost.." to reach this fuel station, now refueling (".. lowBar ..")...")
		-- begin refuel
		local enoughRefuel = with({asFuel = workState.fuelStation.itemType})(refuel.fromBackpack.to(lowBar))
		local greedyRefuel = with({asFuel = workState.fuelStation.itemType})(refuel.fromBackpack.to(math.max(const.activeRadius * const.greedyRefuelRatio, highBar)))
		rep(retry(suck) * -enoughRefuel)() -- repeat until enough --TODO: suck.exact(?)
		if os.getComputerLabel() then
			rep(suck * -greedyRefuel)() -- try to greedy refuel, stop when suck fail
		end
		-- refuel done
		log.verb("Finished refueling, now back to work pos "..show(workState.back.pos))

		recoverPosp(workState.back)()
		workState.back = nil
		workState.isRefueling = false
		return true
	end))

	refuel.to = mkIOfn(function(availableLowBar, availableHighBar)
		if availableLowBar <= turtle.getFuelLevel() then return true end
		if availableLowBar > turtle.getFuelLimit() then return false end
		local ok = refuel.fromBackpack.to(availableLowBar)()
		if not ok and workMode.allowInterruption then -- no fuel in backpack, go to fuelStation
			ok = with({destroy = 1})(refuel.fromFuelStation(availableLowBar, availableHighBar))()
		end
		return ok
	end)

	refuel.prepareMoveTo = mkIOfn(function(destPos)
		if not workState.isRefueling then
			local beginPos = workState.pos
			local refuel_pos = workState.fuelStation and workState.fuelStation.pos
			local refuel_dis = (refuel_pos and math.max(vec.manhat(beginPos - refuel_pos), vec.manhat(destPos - refuel_pos))) or const.activeRadius
			local unload_pos = workState.unloadStation and workState.unloadStation.pos
			local unload_dis = (unload_pos and math.max(vec.manhat(beginPos - unload_pos), vec.manhat(destPos - unload_pos))) or const.activeRadius
			local required_fuel = vec.manhat(beginPos - destPos) + math.max(refuel_dis, unload_dis) * 2
			local ok = refuel.to(required_fuel * 2)()
			if not ok then
				(try(move.to(O) * turn.to(F)) * cryForHelpRefueling(required_fuel * 2))()
			end
		end
	end)

end

