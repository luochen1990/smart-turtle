------------------------------- main coroutines --------------------------------

if turtle then

	-- | provide current real pos and facing dir to correct the coordinate system
	_correctCoordinateSystem = markFn("_correctCoordinateSystem(pos, facing)")(function(pos, facing)
		assert(pos and pos.x, "[_correctCoordinateSystem(pos, facing)] pos must be a vector, but got"..tostring(pos))
		assert(facing and facing.y == 0 and vec.manhat(facing) == 1, "[_correctCoordinateSystem(pos, facing)] facing must be a dir, but got "..tostring(facing))
		local old_pos, old_facing = workState.pos, workState.facing
		local offset = pos - old_pos -- use this to correct all locally maintained positions
		local rot = dirRotationBetween(facing, old_facing)
		local trans = function(p) return rot(p) + offset end
		O = trans(O)
		if workMode.depot and workMode.depot.pos then
			workMode.depot.pos = trans(workMode.depot.pos)
		end
		for _, pinned in ipairs(workMode.pinnedSlot) do
			if pinned.depot then
				pinned.depot = trans(pinned.depot)
			end
		end
		_setNamedDirection("F", facing)
		_setNamedDirection("B", -facing)
		_setNamedDirection("L", leftSide(facing))
		_setNamedDirection("R", rightSide(facing))
		for _, dirName in ipairs(const.absoluteDirectionNames) do
			_setNamedDirection(dirName, const.dir[dirName])
		end
		workState.pos, workState.facing = pos, facing
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
		if not workState.hasModem then return false end

		local ok1 = _correctCoordinateSystemWithGps()
		if not ok1 then
			printC(colors.yellow)("WARN: failed to get gps pos and dir!")
		else
			os.queueEvent("turtle-posd-ready")
		end
		local ok2, fuelStation = retry(5)(requestFuelStation(0))()
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
		local sn = slot.find(slot.nameSat(_item.isModem))
		if sn then
			ok = ( select(sn) * equip )()
		end
		if ok then
			succ = openWirelessModem()
		end
	end
	if succ then
		if turtle then workState.hasModem = true end
		os.queueEvent("computer-modem-ready")
	else
		printC(colors.yellow)("WARN: wireless modem not found!")
	end
	os.queueEvent("computer-ready")
	return succ
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
-- , and run related daemon process
_roleDaemonCo = function()

	local detectSwarmRole = function()
		local label = os.getComputerLabel()
		local surfixIdx = string.find(label, "-%d*$")
		if surfixIdx then
			label = string.sub(label, 1, surfixIdx-1)
		end
		local roleCfg = swarm.roles[label]
		if roleCfg and roleCfg.check() then
			return label, roleCfg
		end
	end

	local role, roleCfg = detectSwarmRole()
	if role then
		os.setComputerLabel(role .. "-" .. os.getComputerID())
		swarm.myRole = role
		swarm.myState = {}
		printC(colors.gray)("my role is "..role..", now running daemon...")
		roleCfg.daemon()
	else
		local label = os.getComputerLabel()
		if turtle and string.sub(label, 1, 6) == "guard-" then
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
		end
	end
end

-- | run device type related daemon process
_deviceDaemonCo = function()
	local turtleDaemon = rpc.buildServer("st-turtle", "queuing", function(msg)
		return safeEval(msg) --TODO: set proper env
	end, rpc._nopeLogger)

	local computerDaemon = rpc.buildServer("st-computer", "queuing", function(msg)
		return safeEval(msg) --TODO: set proper env
	end, rpc._nopeLogger)

	if turtle then
		para_(turtleDaemon, computerDaemon)()
	else
		computerDaemon()
	end
end

_startupScriptCo = function()
	-- startup logic by script st_startup.lua
	local code = readFile("/st_startup.lua")
	if code then exec(code, _ST) end
end

_daemonScriptCo = function()
	local code = readFile("/st_daemon.lua")
	if code then exec(code) end
end

_main = function(...)
	term.clear(); term.setCursorPos(1, 1)

	local _exitCo = function()
		_waitForKeyCombination(keys.leftCtrl, keys.d)
		print("[ctrl+d] exit smart-turtle")
	end

	local args = {...}
	if #args > 0 then
		printC(colors.gray)('cli arguments: ', show(args))

		-- exec command from cli args
		local _cliCommandCo = function()
			exec(args[1], {}, _ENV)
		end

		race_(_exitCo, _cliCommandCo, para_(_inspectCo, _initSystemCo))()
	else
		local _startupCo = race_(_startupScriptCo, delay(_waitForKeyCombination, keys.leftCtrl, keys.c))

		local _daemonCo = function()
			local _exitCo = function()
				_waitForKeyCombination(keys.leftCtrl, keys.q)
				print("[ctrl+q] exit daemon process")
			end
			race_(_exitCo, para_(_daemonScriptCo, _deviceDaemonCo, _roleDaemonCo))()
		end

		local _replCo = function()
			race_(function() os.pullEvent("turtle-posd-ready") end, function() sleep(2) end)()
			_repl.start()
		end

		-- run startup scripts & init system state
		race_(_exitCo, _replCo, para_(_inspectCo, _startupCo, _daemonCo, _initSystemCo))()
	end
end

