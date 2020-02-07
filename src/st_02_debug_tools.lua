--------------------------------- debug tools ----------------------------------

DEBUG = true
__assert = assert
if DEBUG then assert = __assert else assert = function() end end
--assert = function(...) if DEBUG then __assert(...) end end

_callStack = {}

-- | markFunc : FunctionName -> (a -> b) -> (a -> b)
markFunc = function(name)
	if not DEBUG then return function(x) return x end end
	return function(func)
		return function(...)
			_callStack[#_callStack+1] = name
			local r = {func()}
			_callStack[#_callStack] = nil
			return unpack(r)
		end
	end
end

-- | markIO : FunctionName -> (IO a) -> (IO a)
markIO = function(name)
	if not DEBUG then return function(x) return x end end
	return mkIOfn(function(io)
		_callStack[#_callStack+1] = name
		local r = {io()}
		_callStack[#_callStack] = nil
		return unpack(r)
	end)
end

-- | markIOfn : FunctionName -> (a -> IO b) -> (a -> IO b)
markIOfn = function(name)
	if not DEBUG then return function(x) return x end end
	return function(iof)
		return function(...)
			local io = iof(...)
			return markIO(name)(io)
		end
	end
end

_waitForKeyPress = function(targetKey)
	while true do
		local ev, keyCode = os.pullEvent("key")
		if ev == "key" and keyCode == targetKey then
			return keyCode
		end
	end
end

_waitForKeyCombination = function(targetKey1, targetKey2)
	local st = 0
	repeat
		if st == 0 then
			_waitForKeyPress(targetKey1)
			st = 1
		elseif st == 1 then
			local ev, keyCode = os.pullEvent()
			if ev == "key_up" and keyCode == targetKey1 then
				st = 0
			elseif ev == "key" and keyCode == targetKey2 then
				st = 2
			end
		end
	until (st == 2)
end

_printCallStackCo = function()
	while true do
		_waitForKeyCombination(keys.leftCtrl, keys.p)
		withColor(colors.blue)(function()
			for dep, fname in ipairs(_callStack) do
				print("[stack depth "..dep.."]", fname)
			end
		end)()
	end
end

