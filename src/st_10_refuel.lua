-------------------------------- auto refuel  ----------------------------------

fuelEnough = markIOfn("fuelEnough(nStep)")(mkIOfn(function(nStep)
	return turtle.getFuelLevel() >= nStep
end))

refuelFromBackpack = markIOfn("refuelFromBackpack(nStep)")(mkIOfn(function(nStep)
	nStep = math.max(1 , nStep)
	local saved_sn = turtle.getSelectedSlot()
	while turtle.getFuelLevel() < nStep do
		local fuelSn = slot.findThat(function(det) return det and const.fuelHeatContent[det.name] end)
		if fuelSn then
			turtle.select(fuelSn)
			while turtle.getFuelLevel() < nStep and turtle.getItemCount(fuelSn) > 0 do
				if turtle.getItemCount(fuelSn) < 2 then slot.fill(fuelSn) end
				turtle.refuel(1)
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
	print("Out of fuel, now backing to fuelStation...")
	local fuelBeforeLeave = turtle.getFuelLevel()
	local leavePos = workState.pos
	local leaveDir = workState:aimingDir()
	with({workArea = nil})(visitStation(workMode.fuelStation))()
	local singleTripCost = turtle.getFuelLevel() - fuelBeforeLeave
	print("Cost "..singleTripCost.." to reach the fuelStation, now refueling...")
	rep(try(suck(1)) * -refuelFromBackpack(nStep))() -- repeat until full
	print("Finished refueling, now back to work pos "..leavePos)
	move.to(leavePos)()
	turn.to(leaveDir)()
end))

refuel = markIOfn("refuel(nStep)")(mkIOfn(function(nStep)
	nStep = math.max(1 , nStep)
	local saved_sn = turtle.getSelectedSlot()
	local succ = refuelFromBackpack(nStep)()
	if not succ then -- no fuel in backpack, go to fuelStation and attempt to full the tank
		refuelFromFuelStation(turtle.getFuelLimit() - 1000)
	end
	turtle.select(saved_sn)
	return true
end))

