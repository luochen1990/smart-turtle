-------------------------------- auto refuel  ----------------------------------

if turtle then

	fuelGot = mkIO(turtle.getFuelLevel)
	--fuelGot.available = mkIO()
	--fuelGot.reserved = mkIO()
	--fuelGot.reserveRatio = mkIO()

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

	refuel.fromBackpack.to = markIOfn("refuel.fromBackpack.to")(function(lowBar)
		local limit = turtle.getFuelLimit()
		return saveSelected(mkIO(function()
			while true do
				local got = turtle.getFuelLevel()
				if got >= lowBar then return true end
				local sn = slot._findThat(slot.isFuel)
				if not sn then return false, "no more fuel available" end
				local det = turtle.getItemDetail(sn)
				local heat = det and _item.fuelHeatContent(det.name)
				if got + heat > limit then return false, "fuel tank almost full" end
				turtle.select(sn)
				turtle.refuel(math.min(math.floor((limit - got) / heat), math.ceil((lowBar - got) / heat)))
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
	refuel.fromStation = markIOfn("refuel.fromStation")(mkIOfn(function(availableLowBar, availableHighBar)
		if not workState:isOnline() then return false, "workState:isOnline() is false" end

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
				log.verb("Cost "..singleTripCost.." to reach this fuel station, now refueling (".. availableLowBar + singleTripCost * 2 ..")...")
			end,
		})

		local lowBar = availableLowBar + singleTripCost * 2
		local highBar = default(availableLowBar * 10)(availableHighBar) + singleTripCost * 2
		local enoughRefuel = with({asFuel = workState.fuelStation.itemType})(refuel.fromBackpack.to(lowBar))
		local greedyRefuel = with({asFuel = workState.fuelStation.itemType})(refuel.fromBackpack.to(math.max(highBar, 2000)))
		rep(retry(suck) * -enoughRefuel)() -- repeat until enough --TODO: suck.hold(?)
		if os.getComputerLabel() then
			rep(suck * -greedyRefuel)() -- try to greedy refuel
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

