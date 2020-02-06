-------------------------------- auto refuel  ----------------------------------

refuel = function(nStep)
	nStep = math.max(1 , nStep)
	local saved_sn = turtle.getSelectedSlot()
	while turtle.getFuelLevel() < nStep do
		local fuelSn = slot.findThat(function(det) return det and const.fuelHeatContent[det.name] end)
		if not fuelSn then return false end
		turtle.select(fuelSn)
		while turtle.getFuelLevel() < nStep and turtle.getItemCount(fuelSn) > 0 do
			if turtle.getItemCount(fuelSn) < 2 then slot.fill(fuelSn) end
			turtle.refuel(1)
		end
	end
	turtle.select(saved_sn)
	return true
end

