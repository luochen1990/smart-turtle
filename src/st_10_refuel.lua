-------------------------------- auto refuel  ----------------------------------

fuelEnough = mkIOfn(function(nStep)
	return turtle.getFuelLevel() >= nStep
end)

refuelFromBackpack = mkIOfn(function(nStep)
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
end)

refuel = mkIOfn(function(nStep)
	nStep = math.max(1 , nStep)
	local saved_sn = turtle.getSelectedSlot()
	local succ = refuelFromBackpack(nStep)
	if not succ then -- no fuel in backpack, go to fuelStation and attempt to full the tank
		print("Out of fuel, now backing to fuelStation...")
		--local fuelBeforeLeave = turtle.getFuelLevel()
		local leavePos = workState.pos
		local leaveDir = workState:aimingDir()
		with(workArea = nil)(visitStation(workMode.fuelStation))()
		--local singleTripCost = turtle.getFuelLevel() - fuelBeforeLeave
		local refuelTarget = turtle.getFuelLimit() - 1000
		print("refueling...")
		rep(try(suck(1)) * -refuelFromBackpack(refuelTarget))() -- repeat until full
		print("Refuel done, now back to work...")
		move.to(leavePos)()
		turn.to(leaveDir)()
	end
	turtle.select(saved_sn)
	return true
end)

