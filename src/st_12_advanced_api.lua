------------------------------- advaneced apis ---------------------------------

if turtle then

	cryForHelpMoving = markIOfn("cryForHelpMoving(beginPos, destPos)")(mkIOfn(function(beginPos, destPos)
		workState.cryingFor = "moving"
		log.cry("Cannot move from "..show(beginPos).." to "..show(destPos)..", please help")
		printC(colors.green)("Press Ctrl+G to continue...")
		_waitForKeyCombination(keys.leftCtrl, keys.g)
		workState.cryingFor = nil
		move.to(destPos)
	end))

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
			local beginPos = workState.pos

			-- auto refuel
			if not workState.isRefueling then
				refuelTo(destPos)()
			end
			-- refuel may change our pos

			local latestDetourPos
			while true do
				-- attempt to approach destPos
				markCallSite("approaching")(function()
					rep(move.toward(destPos))()
				end)
				local v = destPos - workState.pos
				local md = vec.manhat(v)
				if md <= 1 then return md == 0 end
				if not workMode.detour then return false end
				if workState.pos == latestDetourPos then return false end
				-- begin detouring
				markCallSite("detouring")(function()
					workState.detouring = true
					local detourBeginPos = workState.pos
					local detourCost = 0 -- record detouring cost
					local targetDir
					for _, d in ipairs(const.directions) do
						if v:dot(const.dir[d]) > 0 then targetDir = const.dir[d]; break end
					end
					-- targetDir decided
					local detourDir
					for _, d in ipairs(const.directions) do
						if d ~= 'D' and targetDir:dot(const.dir[d]) == 0 then --NOTE: prefer not to go down
							local ok = (turn.to(const.dir[d]) * move)()
							if ok then detourDir = const.dir[d]; detourCost = detourCost + 1; break end
						end
					end
					if not detourDir then
						detourDir = lateralSide(targetDir)
						-- turn.to(detourDir) --TODO: not sure whether need this line
					end
					-- init detourDir decided
					local rot = dirRotationBetween(targetDir, detourDir)
					local detourDirs = {targetDir, detourDir, rot(detourDir), rot(rot(detourDir))}
					-- detourDirs (i.e. detour plane) decided
					printC(colors.gray)("detouring via "..showDir(targetDir)..","..showDir(detourDir).." to "..tostring(destPos))
					-- begin detouring loop
					local detourRotateCount = 1
					local detourBeginDis = vec.manhat(destPos - detourBeginPos)
					repeat
						for i = -1, 2 do --NOTE: from detourDir-1 to detourDir+2
							candidateDir = detourDirs[(detourRotateCount + i) % 4 + 1]
							local ok = (turn.to(candidateDir) * move)()
							if ok then
								detourRotateCount = detourRotateCount + i
								detourCost = detourCost + 1
								break
							end
						end
					until (vec.manhat(destPos - workState.pos) <= detourBeginDis) --NOTE: this condition is very important
					printC(colors.gray)("cost "..detourCost.." from "..show(detourBeginPos).." to "..show(workState.pos))
					-- finish detouring
					latestDetourPos = detourBeginPos
					workState.detouring = false
				end)
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

	-- | save pos and dir
	savePosd = function(io)
		return saveDir(savePos(io))
	end

	-- | save pos and posture
	savePosp = function(io)
		return savePosture(savePos(io))
	end

	-- recover saved pos and posture
	recoverPosp = markIOfn("recoverPosp(back)")(mkIOfn(function(back)
		move.to(back.pos)()
		turn.to(back.facing)()
		workState.aiming = back.aiming
	end))

	-- | this function scans a plane area
	-- , which is not as useful as the function scan()
	_scan2d = markIOfn2("_scan2d(area)(io)")(function(area)
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
				io = with({workArea = false})(savePosd(try(io)))
				local toward = move.toward(far, function(d, d0) return d ~= -d0 end)
				local loop = save(currentDir)(toward * fmap(negate)(saved):pipe(turn.to)) * rep(io * move)
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
	scan = markIOfn2("scan(area, mainDir)(io)")(function(area, mainDir)
		mainDir = default(workState:aimingDir())(mainDir)
		return function(io)
			return (mkIO(function()
				local projLen = (area.diag + vec.one):dot(mainDir)
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
		assert(station.pos and station.dir, "[visitStation] station.pos and station.dir is required!")
		return (move.to(station.pos) * turn.to(station.dir))()
	end))

	cryingVisitStation = markIOfn("cryingVisitStation(station)")(function(station)
		assert(station.pos and station.dir, "[cryingVisitStation] station.pos and station.dir is required!")
		local leavePos = workState.pos
		return visitStation(station) + cryForHelpMoving(leavePos, station.pos) * turn.to(station.dir)
	end)

	carry = markIOfn("carry(from, to, count, name)")(mkIOfn(function(from, to, count, name)
		local got = slot.count(name)
		--local space = slot.count(slot.spaceFor(name))
		return (visitStation(from) * try(suckExact(count - got, name)) * visitStation(to) * dropExact(count, name))()
	end))

	transportLine = markIOfn("transportLine(from, to)")(mkIOfn(function(from, to)
		if not workState.fuelStation then error("[transportLine] please set a fuel provider") end
		local fuelReservation = 2 * vec.manhat(to.pos - from.pos) + vec.manhat(to.pos - workState.fuelStation.pos) + vec.manhat(from.pos - workState.fuelStation.pos)
		local cnt = 0
		while true do
			refuel(fuelReservation)()
			;(cryingVisitStation(from) * rep(suck()) * cryingVisitStation(to) * rep(select(slot.isNonEmpty) * drop()))()
			cnt = cnt + 1
			if not slot._findThat(slot.isNonEmpty) then
				printC(colors.gray)("[transportLine] finished "..cnt.." trips, now have a rest for 20 seconds...")
				sleep(20)
			else
				printC(colors.gray)("[transportLine] the dest chest is full, waiting for space...")
				;(retry(select(slot.isNonEmpty) * drop()) * rep(select(slot.isNonEmpty) * drop()))()
			end
		end
	end))

end
