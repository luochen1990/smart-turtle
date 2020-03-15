-------------------------------- auto refuel  ----------------------------------

if turtle then

	fuelGot = mkIO(turtle.getFuelLevel)

	refuelFromBackpack = markIOfn("refuelFromBackpack(nStep)")(mkIOfn(function(nStep)
		nStep = math.max(1 , nStep)
		local saved_sn = turtle.getSelectedSlot()
		while turtle.getFuelLevel() < nStep do
			local fuelSn = slot._findThat(slot.isFuel)
			if fuelSn then
				turtle.select(fuelSn)
				local det = turtle.getItemDetail(fuelSn)
				local heat = _item.fuelHeatContent(det.name)
				while turtle.getFuelLevel() < nStep and turtle.getItemCount(fuelSn) > 0 do
					if turtle.getItemCount(fuelSn) < 2 then slot.fill(fuelSn) end
					turtle.refuel(math.max(1, (nStep - turtle.getFuelLevel()) / heat))
					local det2 = turtle.getItemDetail()
					if det2 and det2.name ~= det.name then break end -- in case of lava-bucket
				end
			else -- no more fuel in backpack
				turtle.select(saved_sn)
				return false
			end
		end
		turtle.select(saved_sn)
		return true
	end))

	cryForHelpRefueling = markIOfn("cryForHelpRefueling(nStep)")(mkIOfn(function(nStep)
		workState.cryingFor = "refueling"
		log.cry("Help me! I need "..nStep.." fuel at "..show(workState.pos))
		with({asFuel = false})(retry(refuelFromBackpack(nStep)))()
		workState.cryingFor = nil
	end))

	-- | the refuel interruption
	-- , fails when workMode.allowInterruption is false
	-- , will wait for refuel help when there is no fuelStation available
	-- , will wait for manually move when cannot reach a fuelStation
	refuelFromFuelStation = markIOfn("refuelFromFuelStation(nStep)")(mkIOfn(function(nStep)
		if not workMode.allowInterruption then return false end

		workState.isRefueling = true
		workState.back = workState.back or getPosp() --NOTE: in case we are already in another interruption

		local singleTripCost = 0
		local extra = function() return singleTripCost * (2 + 1) end
		local gotoFuelStation
		gotoFuelStation = function(triedTimes)
			local ok, station = requestFuelStation(nStep + extra())()
			if ok then
				workState.fuelStation = station
			else
				return false, triedTimes -- will wait for help
			end
			-- got fresh fuelStation here
			log.verb("Visiting fuel station "..show(workState.fuelStation.pos).."...")
			local leavePos, fuelBeforeLeave = workState.pos, turtle.getFuelLevel()
			with({workArea = false})(cryingVisitStation(workState.fuelStation))()
			-- arrived fuelStation here
			local cost = math.max(0, fuelBeforeLeave - turtle.getFuelLevel())
			singleTripCost = singleTripCost + cost
			if not isStation() then -- the fuelStation is not available
				log.verb("Cost "..cost.." to reach "..triedTimes.."th unavailable fuel station, now trying next...")

				unregisterStation(workState.fuelStation)
				return gotoFuelStation(triedTimes + 1)
			else
				return true, triedTimes
			end
		end
		local succ, triedTimes = gotoFuelStation(1)
		if not succ then
			race_(retry(delay(gotoFuelStation, triedTimes + 1)), cryForHelpRefueling(nStep + extra()))()
			return true
		end
		-- arrived checked fuelStation here
		log.verb("Cost "..singleTripCost.." to reach this fuel station, now refueling ("..nStep.." + "..extra()..")...")
		local enoughRefuel = with({asFuel = workState.fuelStation.itemType})(refuelFromBackpack(nStep + extra()))
		local greedyRefuel = with({asFuel = workState.fuelStation.itemType})(refuelFromBackpack(math.min(math.max(nStep*10 + extra()*2, 2000), turtle.getFuelLimit() - 1000)))
		rep(retry(suck()) * -enoughRefuel)() -- repeat until enough
		if os.getComputerLabel() then
			rep(suck() * -greedyRefuel)() -- try to full the tank
		end
		-- refuel done
		log.verb("Finished refueling, now back to work pos "..show(workState.back.pos))

		recoverPosp(workState.back)()
		workState.back = nil
		workState.isRefueling = false
		return true
	end))

	refuel = markIOfn("refuel(nStep)")(mkIOfn(function(nStep)
		nStep = math.max(1 , nStep or 1)
		if nStep <= turtle.getFuelLevel() then return true end
		if nStep > turtle.getFuelLimit() then return false end
		local saved_sn = turtle.getSelectedSlot()
		local ok = refuelFromBackpack(nStep)()
		if not ok and workMode.allowInterruption then -- no fuel in backpack, go to fuelStation
			ok = with({destroy = 1})(refuelFromFuelStation(nStep))()
		end
		turtle.select(saved_sn)
		return ok
	end))

	refuelTo = markIOfn("refuelTo(destPos)")(mkIOfn(function(destPos)
		if not workState.isRefueling then
			local beginPos = workState.pos
			local refuel_pos = workState.fuelStation and workState.fuelStation.pos
			local refuel_dis = (refuel_pos and math.max(vec.manhat(beginPos - refuel_pos), vec.manhat(destPos - refuel_pos))) or const.activeRadius
			local unload_pos = workState.unloadStation and workState.unloadStation.pos
			local unload_dis = (unload_pos and math.max(vec.manhat(beginPos - unload_pos), vec.manhat(destPos - unload_pos))) or const.activeRadius
			local required_fuel = vec.manhat(beginPos - destPos) + math.max(refuel_dis, unload_dis) * 2
			local ok = refuel(required_fuel * 2)()
			if not ok then
				cryForHelpRefueling(required_fuel * 2)()
			end
		end
	end))
end
