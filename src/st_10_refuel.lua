-------------------------------- auto refuel  ----------------------------------

if turtle then

	fuelEnough = markIOfn("fuelEnough(nStep)")(mkIOfn(function(nStep)
		return turtle.getFuelLevel() >= nStep
	end))

	refuelFromBackpack = markIOfn("refuelFromBackpack(nStep)")(mkIOfn(function(nStep)
		nStep = math.max(1 , nStep)
		local saved_sn = turtle.getSelectedSlot()
		while turtle.getFuelLevel() < nStep do
			local fuelSn = slot.findThat(slot.isFuel)
			if fuelSn then
				turtle.select(fuelSn)
				local det = turtle.getItemDetail(fuelSn)
				local heat = const.fuelHeatContent[det.name]
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

	refuelFromFuelStation = markIOfn("refuelFromFuelStation(nStep)")(mkIOfn(function(nStep)
		workState.refueling = true
		print("Out of fuel, now backing to fuelStation "..tostring(workState.fuelStation.pos))
		local fuelBeforeLeave = turtle.getFuelLevel()
		local leavePos, leaveFacing, leaveAiming = workState.pos, workState.facing, workState.aiming
		with({workArea = nil})(visitStation(workState.fuelStation))()
		local singleTripCost = math.max(0, fuelBeforeLeave - turtle.getFuelLevel())
		print("Cost "..singleTripCost.." to reach the fuelStation, now refueling ("..nStep..")...")
		local enoughRefuel = refuelFromBackpack(nStep + singleTripCost * 2)
		local greedyRefuel = refuelFromBackpack(turtle.getFuelLimit() - 1000)
		if not isChest() then -- the fuelStation is not available, waiting for help
			printC(colors.orange)("[refuelFromFuelStation] the fuel station on "..tostring(workState.fuelStation.pos).." is not available, waiting for help...")
			retry(enoughRefuel)() --TODO: try to update fuelStation info
		else
			rep(retry(suck()) * -enoughRefuel)() -- repeat until enough
			if os.getComputerLabel() then
				rep(suck() * -greedyRefuel)() -- try to full the tank
			end
		end
		print("Finished refueling, now back to work pos "..tostring(leavePos))
		move.to(leavePos)()
		turn.to(leaveFacing)()
		workState.aiming = leaveAiming
		workState.refueling = false
		return true
	end))

	refuel = markIOfn("refuel(nStep)")(mkIOfn(function(nStep)
		nStep = math.max(1 , nStep or 1)
		if nStep <= turtle.getFuelLevel() then return true end
		if nStep > turtle.getFuelLimit() then return false end
		local saved_sn = turtle.getSelectedSlot()
		local succ = false
		if refuelFromBackpack(nStep)() then succ = true end
		-- no fuel in backpack, go to fuelStation
		if not succ and workState.fuelStation and workState.fuelStation.pos then
			succ = refuelFromFuelStation(nStep)()
		end
		turtle.select(saved_sn)
		return succ
	end))

end
