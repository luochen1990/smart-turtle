------------------------------- main coroutines --------------------------------

if turtle then

	-- | provide current real pos and facing dir to correct the coordinate system
	_correctCoordinateSystem = markFn("_correctCoordinateSystem(pos, facing)")(function(pos, facing)
		assert(pos and pos.x, "[_correctCoordinateSystem(pos, facing)] pos must be a vector, but got"..tostring(pos))
		assert(facing and facing.y == 0 and vec.manhat(facing) == 1, "[_correctCoordinateSystem(pos, facing)] facing must be a dir, but got "..tostring(facing))
		local old_pos, old_facing = workState.pos, workState.facing
		local offset = pos - old_pos -- use this to correct all locally maintained positions
		local rot = dirRotationBetween(facing, old_facing)
		workState.beginPos = rot(workState.beginPos) + offset
		O = workState.beginPos
		workState.pos = pos
		workState.facing = facing
		F, B, L, R = facing, -facing, leftSide(facing), rightSide(facing)
		for _, d in ipairs({"F", "B", "L", "R"}) do turn[d] = turn.to(_ST[d]) end
		workState.gpsCorrected = true
		return true
	end)

	_correctCoordinateSystemWithGps = markFn("_correctCoordinateSystemWithGps")(function()
		local p0 = gpsPos(5)
		if not p0 then
			printC(colors.orange)("[_correctCoordinateSystemWithGps] make sure you have wireless modem and gps station nearby")
			return false
		end
		printC(colors.gray)("turtle pos = "..tostring(p0))
		-- got p0 (i.e. pos) here
		if not refuelFromBackpack(2)() then
			printC(colors.orange)("[_correctCoordinateSystemWithGps] I need some fuel")
			return false
		end
		-- ready to get p1 (i.e. dir) here
		local getFacing = function(go, goBack, calcDir)
			local succ = retry(5)(go)()
			if not succ then
				return nil
			end
			local p1 = gpsPos(10)
			while not goBack() do turtle.attack() end --TODO: dig sand but wait for turtle
			if not p1 then
				return nil
			end
			local d = calcDir(p1)
			if vec.manhat(d) ~= 1 then
				printC(colors.gray)("p0 = "..tostring(p0)..", p1 = "..tostring(p1))
				printC(colors.gray)("p0 - p1 = "..tostring(d))
				log.bug("[_correctCoordinateSystemWithGps] weird gps positoin, please check your gps server (p0 = " .. show(p0) .. " p1 = " .. show(p1) .. " d = " .. show(d))
				return nil
			end
			return d
		end
		local d
		if not turtle.detect() then
			d = getFacing(turtle.forward, turtle.back, function(p1) return p1 - p0 end)
		end
		d = d or getFacing(turtle.back, turtle.forward, function(p1) return p0 - p1 end)
		if not d then
			printC(colors.orange)("[_correctCoordinateSystemWithGps] cannot move forward/back and gps locate, please try somewhere else nearby")
			return false
		end
		printC(colors.gray)("turtle facing = "..showDir(d))
		-- got pos and dir here
		return _correctCoordinateSystem(p0, d)
	end)

	_initTurtleCo = markFn("_initTurtleCo")(function()
		local ok1 = _correctCoordinateSystemWithGps()
		if not ok1 then
			printC(colors.yellow)("WARN: failed to get gps pos and dir!")
		else
			os.queueEvent("turtle-posd-ready")
		end
		local ok2, fuelStation = retry(10)(requestFuelStation(0))()
		if ok2 then
			workState.fuelStation = fuelStation
		else
			printC(colors.yellow)("WARN: failed to get fuel station!")
		end
		local ok3, unloadStation = retry(5)(requestUnloadStation(0))()
		if ok3 then
			workState.unloadStation = unloadStation
		else
			printC(colors.yellow)("WARN: failed to get unload station!")
		end
		os.queueEvent("turtle-ready")
		return ok1 and ok2 and ok3
	end)

end -- if turtle

_inspectCo = function()
	local _printCallStackCo = function()
		while true do
			_waitForKeyCombination(keys.leftCtrl, keys.p)
			_printCallStack(table.pack(term.getSize())[2] - 2, nil, colors.blue)
		end
	end

	local _inspectSystemStateCo = function()
		while true do
			_waitForKeyCombination(keys.leftCtrl, keys.i)
			if turtle then
				printC(colors.green)('turtle workMode =', show(workMode))
				printC(colors.green)('turtle workState =', show(workState))
			end
		end
	end
	para_(_printCallStackCo, _inspectSystemStateCo)()
end

_initComputerCo = function()
	local succ = openWirelessModem()
	if not succ and turtle then
		local equip = mkIO(function()
			local ok = turtle.equipLeft()
			return ok
		end)
		local ok -- equip modem success
		local sn = slot.find(slot.isTool("modem"))
		if sn then
			ok = ( select(sn) * equip )()
		end
		if ok then
			succ = openWirelessModem()
		end
	end
	if not succ then
		printC(colors.yellow)("WARN: wireless modem not found!")
		return false
	end
	os.queueEvent("computer-modem-ready")
	os.queueEvent("computer-ready")
	return true
end

-- | init system state
-- , including computer general state and turtle specific state
_initSystemCo = function()
	_initComputerCo()
	if turtle then
		_initTurtleCo()
	end
	os.queueEvent("system-ready")
end

-- | detect device role via label and device type
-- , and run related script
_roleDaemonCo = function()
	local label = os.getComputerLabel()

	if label == "swarm-server" then
		_role = "swarm-server"
		swarm._startService()
	elseif label == "log-printer" then
		_role = "log-printer"
		os.pullEvent("system-ready")
		_logPrintCo()
	elseif turtle and label == "provider" then
		_role = "provider"
		os.pullEvent("turtle-posd-ready")
		serveAsProvider()
	elseif turtle and label == "unloader" then
		_role = "unloader"
		os.pullEvent("turtle-posd-ready")
		serveAsUnloader()
	elseif turtle and label == "requester" then
		_role = "requester"
		os.pullEvent("turtle-posd-ready")
		serveAsRequester()
	elseif turtle and label == "storage" then
		_role = "storage"
		os.pullEvent("turtle-posd-ready")
		serveAsStorage()
	elseif turtle and label == "carrier" then
		_role = "carrier"
		os.pullEvent("system-ready")
		serveAsCarrier()
	--elseif turtle and label == "register" then
	--	_role = "register"
	--	os.pullEvent("turtle-posd-ready")
	--	registerPassiveProvider()
	elseif label == "blinker" then
		_role = "blinker"
		os.pullEvent("system-ready")
		local b = false
		while true do
			redstone.setOutput("front", b)
			b = not b
			sleep(0.5)
		end
	elseif turtle and string.sub(label, 1, 6) == "guard-" then
		_role = "guard"
		os.pullEvent("system-ready")
		local d = string.sub(label, 7, 7)
		if const.dir[d] then
			if d == "D" then
				followYouCo(D)
			else
				followYouCo(const.dir[d])
			end
		end
	elseif pocket and label == "follow-me" then
		_role = "follow-me"
		os.pullEvent("system-ready")
		followMeCo()
	else
		if turtle then
			_role = "worker"
		else
			_role = "pc"
		end
	end
end

_startupScriptCo = function()
	-- startup logic by script st_startup.lua
	local code = readFile("/st_startup.lua")
	if code then exec(code) end
end

_daemonScriptCo = function()
	local code = readFile("/st_daemon.lua")
	if code then exec(code) end
end

_main = function(...)
	term.clear(); term.setCursorPos(1, 1)

	local args = {...}
	if #args > 0 then
		printC(colors.gray)('cli arguments: ', show(args))

		-- exec command from cli args
		race_(_inspectCo, para_(function() exec(args[1], {}, _ENV) end, _initSystemCo))()
	else
		local _startupCo = race_(_startupScriptCo, delay(_waitForKeyCombination, keys.leftCtrl, keys.c))

		local _daemonCo = function()
			local _exitCo = function()
				_waitForKeyCombination(keys.leftCtrl, keys.q)
				print("[ctrl+q] exit daemon process")
			end
			race_(_exitCo, para_(_daemonScriptCo, _roleDaemonCo))()
		end

		local _replCo = function()
			os.pullEvent("system-ready")
			local _exitCo = function()
				_waitForKeyCombination(keys.leftCtrl, keys.d)
				print("[ctrl+d] exit repl")
			end
			race_(_exitCo, _replMainCo)()
		end

		-- run startup scripts & init system state
		race_(_inspectCo, para_(_startupCo, _daemonCo, _replCo, _initSystemCo))()

	end
end

