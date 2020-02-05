------------------------------- advaneced move ---------------------------------

-- | attempt to approach destPos by one step
move.toward = function(destPos)
	return mkIO(function()
		local ok = false
		local v = destPos - workState.pos
		for _, d in ipairs(const.directions) do
			if v:dot(const.dir[d]) > 0 then
				ok = ok or (turn[d] * move)()
				if ok then break end
			end
		end
		return ok
	end)
end

move.to = function(destPos)
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
end

move.go = function(destVec)
	return mkIO(function()
		return move.to(workState.pos + destVec)()
	end)
end

savePos = function(io)
	return mkIO(function()
		local saved_pos = workState.pos
		local r = {io()}
		move.to(saved_pos)()
		return unpack(r)
	end)
end

