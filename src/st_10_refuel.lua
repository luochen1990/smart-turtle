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
			local det = turtle.getItemDetail(fuelSn)
			local heat = const.fuelHeatContent[det.name]
			while turtle.getFuelLevel() < nStep and turtle.getItemCount(fuelSn) > 0 do
				if turtle.getItemCount(fuelSn) < 2 then slot.fill(fuelSn) end
				turtle.refuel(math.max(1, (nStep - turtle.getFuelLevel()) / heat))
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
	print("Out of fuel, now backing to fuelStation "..tostring(workMode.fuelStation.pos))
	local fuelBeforeLeave = turtle.getFuelLevel()
	local leavePos = workState.pos
	local leaveDir = workState:aimingDir()
	with({workArea = nil})(visitStation(workMode.fuelStation))()
	local singleTripCost = math.max(0, fuelBeforeLeave - turtle.getFuelLevel())
	print("Cost "..singleTripCost.." to reach the fuelStation, now refueling ("..nStep..")...")
	rep(try(suck()) * -refuelFromBackpack(nStep + singleTripCost * 2))() -- repeat until enough
	rep(suck() * -refuelFromBackpack(turtle.getFuelLimit() - 1000))() -- attempt to full the tank
	print("Finished refueling, now back to work pos "..tostring(leavePos))
	move.to(leavePos)()
	turn.to(leaveDir)()
	workState.refueling = false
end))

refuel = markIOfn("refuel(nStep)")(mkIOfn(function(nStep)
	nStep = math.max(1 , nStep)
	if nStep > turtle.getFuelLimit() then return false end
	local saved_sn = turtle.getSelectedSlot()
	local succ = false
	if refuelFromBackpack(nStep)() then succ = true end
	-- no fuel in backpack, go to fuelStation
	if not succ and workMode.fuelStation and workMode.fuelStation.pos then
		succ = refuelFromFuelStation(nStep)()
	end
	turtle.select(saved_sn)
	return succ
end))

