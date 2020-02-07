------------------------------- advaneced apis ---------------------------------

-- | attempt to approach destPos by one step
move.toward = markIOfn("move.toward(destPos, cond)")(function(destPos, cond)
	return mkIO(function()
		local ok = false
		local v = destPos - workState.pos
		local d0 = workState:aimingDir()
		for _, d in ipairs(const.directions) do
			if v:dot(const.dir[d]) > 0 and (not cond or cond(const.dir[d], d0)) then
				ok = ok or (turn[d] * move)()
				if ok then break end
			end
		end
		return ok
	end)
end)

move.to = markIOfn("move.to(destPos)")(function(destPos)
	return mkIO(function()
		local latestDetourPos
		while true do
			-- attempt to approach destPos
			rep(move.toward(destPos))()
			local v = destPos - workState.pos
			local md = manhat(v)
			if md <= 1 then return md == 0 end
			if workState.pos == latestDetourPos then return false end
			-- begin detouring
			local detourBeginPos = workState.pos
			local targetDir
			for _, d in ipairs(const.directions) do
				if v:dot(const.dir[d]) > 0 then targetDir = const.dir[d]; break end
			end
			-- targetDir decided
			local detourDir
			for _, d in ipairs(const.directions) do
				if targetDir:dot(const.dir[d]) == 0 then
					local ok = (turn.to(const.dir[d]) * move)()
					if ok then detourDir = const.dir[d]; break end
				end
			end
			if not detourDir then return false end
			-- init detourDir decided
			local detourRotate = targetDir ^ detourDir
			local detourDirs = {targetDir, detourDir, detourDir % detourRotate, detourDir % detourRotate % detourRotate}
			-- detourDirs decided
			withColor(colors.yellow)(function()
				print("detouring... (destPos: "..destPos..")")
				print("             (targetDir: "..targetDir..")")
				print("             (detourDir: "..detourDir..")")
			end)()
			-- begin detouring loop
			local detourRotateCount = 1
			repeat
				for i = -1, 2 do --NOTE: from detourDir-1 to detourDir+2
					candidateDir = detourDirs[(detourRotateCount + i) % 4 + 1]
					local ok = (turn.to(candidateDir) * move)()
					if ok then
						detourRotateCount = detourRotateCount + i
						break
					end
				end
			until (detourRotateCount % 4 == 0)
			-- finish detouring
			latestDetourPos = detourBeginPos
		end
	end)
end)

move.go = markIOfn("move.go(destVec)")(function(destVec)
	return mkIO(function()
		return move.to(workState.pos + destVec)()
	end)
end)

savePos = markIOfn("savePos(io)")(function(io)
	return mkIO(function()
		local saved_pos = workState.pos
		local r = {io()}
		move.to(saved_pos)()
		return unpack(r)
	end)
end)

-- save pos and dir
savePosd = function(io)
	return saveDir(savePos(io))
end

-- usage demo: save(currentPos) * move.to(vec(0,1,0)) * move.to(saved)
save, saved = (function()
	local saved_value = nil
	local _save = markIOfn("save(ioGetValue)")(mkIOfn(function(ioGetValue)
		saved_value = {ioGetValue()}
		return true
	end))
	local _saved = markIO("saved")(mkIO(function()
		return unpack(saved_value)
	end))
	return _save, _saved
end)()

-- | this function scans a plane area
-- , which is not as useful as the function scan()
_scan2d = markIOfn("_scan2d(area)")(function(area)
	assert(area and area.diag.x * area.diag.y * area.diag.z == 0, "[_scan2d(area)] area should be 2d, but got "..tostring(area))
	return function(io)
		return with({workArea = area})(mkIO(function()
			local near = area.low
			for _, p in ipairs(area:vertexes()) do
				if (p - workState.pos):length() < (near - workState.pos):length() then near = p end
			end
			local far = area.low + area.high - near
			if area:volume() <= 0 then return true end
			if not move.to(near)() then return false end
			io = try(saveDir(io))
			local toward = move.toward(far, function(d, d0) return d ~= -d0 end)
			local loop = save(currentDir) * toward * turn.to(fmap(negate)(saved)) * rep(io * move)
			local run = io * toward * rep(io * move) * rep(loop)
			run()
			return true
		end))
	end
end)

-- | a very useful function, scan over an 3d area (including trivial cases)
-- , it scans layer by layer toward the mainDir
-- , when you want to dig an area, you might want to choose your mainDir same as your dig direction
-- , and when placing, choose your mainDir opposite to your place direction
scan = markIOfn("scan(area, mainDir)")(function(area, mainDir)
	mainDir = default(workState:aimingDir())(mainDir)
	return function(io)
		return with({workArea = area})(mkIO(function()
			local projLen = (area.diag + const.positiveDir):dot(mainDir)
			local low0, high0
			if projLen == 0 then
				return true
			elseif projLen > 0 then
				low0, high0 = area.low, (area.high - mainDir * (projLen - 1))
			else --[[ if projLen < 0 then ]]
				low0, high0 = (area.low + mainDir * (projLen + 1)), area.high
			end
			for i = 0, math.abs(projLen) - 1 do
				local a = (low0 + mainDir * i) .. (high0 + mainDir * i)
				_scan2d(a)(io)()
			end
			return true
		end))
	end
end)

visitStation = markIOfn("visitStation(station)")(mkIOfn(function(station)
	assert(station.pos and station.dir, "[_visitStation] station.pos and station.dir is required!")
	return (move.to(station.pos) * turn.to(station.dir))()
end))

transportLine = markIOfn("transportLine(sourceStation, destStation, fuelStation)")(mkIOfn(function(sourceStation, destStation, fuelStation)
	if fuelStation then workMode.fuelStation = fuelStation end
	if not workMode.fuelStation then error("[transportLine] fuelStation must be provided") end
	local fuelReservation = 2 * manhat(destStation.pos - sourceStation.pos) + manhat(destStation.pos - workMode.fuelStation.pos) + manhat(sourceStation.pos - workMode.fuelStation.pos)
	while true do
		if turtle.getFuelLevel() < fuelReservation then refuel(turtle.getFuelLimit() - 1000)() end
		(visitStation(sourceStation) * suck() ^ 15 * visitStation(destStation) * drop() ^ 15)()
	end
end))
