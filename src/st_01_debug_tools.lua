--------------------------------- debug tools ----------------------------------

DEBUG = true
__assert = assert
if DEBUG then assert = __assert else assert = function() end end
--assert = function(...) if DEBUG then __assert(...) end end

_callStack = {}

-- | markFn : FunctionName -> (a -> b) -> (a -> b)
markFn = function(name)
	if not DEBUG then return function(x) return x end end
	return function(func)
		return function(...)
			_callStack[#_callStack+1] = name
			local r = {func(...)}
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

-- | markIOfn2 : FunctionName -> (a -> b -> IO c) -> (a -> b -> IO c)
markIOfn2 = function(name)
	if not DEBUG then return function(x) return x end end
	return function(iof2)
		return function(...)
			local iof = iof2(...)
			return markIOfn(name)(iof)
		end
	end
end

withColor = function(fg, bg)
	return (mkIOfn(function(io)
		local saved_fg = term.getTextColor()
		local saved_bg = term.getBackgroundColor()
		term.setTextColor(default(saved_fg)(fg))
		term.setBackgroundColor(default(saved_bg)(bg))
		local r = {io()}
		term.setTextColor(saved_fg)
		term.setBackgroundColor(saved_bg)
		return unpack(r)
	end))
end

printC = function(fg, bg)
	return markFn("printC(fg, bg)(io)")(function(...)
		return withColor(fg, bg)(delay(print, ...))()
	end)
end

writeC = function(fg, bg)
	return markFn("writeC(fg, bg)(io)")(function(...)
		return withColor(fg, bg)(delay(write, ...))()
	end)
end

_waitForKeyPress = function(targetKey)
	while true do
		local ev, keyCode = os.pullEvent("key")
		if ev == "key" and keyCode == targetKey then
			--print("[ev] key("..keys.getName(keyCode)..")")
			return keyCode
		end
	end
end

_waitForKeyCombination = function(targetKey1, targetKey2)
	local st = 0 -- matched length
	repeat
		if st == 0 then
			_waitForKeyPress(targetKey1)
			st = 1
		elseif st == 1 then
			local ev, keyCode = os.pullEvent()
			if ev == "key_up" and keyCode == targetKey1 then
				--print("[ev] key_up("..keys.getName(keyCode)..")")
				st = 0
			elseif ev == "key" and keyCode == targetKey2 then
				--print("[ev] key("..keys.getName(keyCode)..")")
				st = 2
			end
		end
	until (st == 2)
end

_printCallStack = function(count, beginDepth, color)
	count = math.max(0, count or 10)
	beginDepth = math.max(1, beginDepth or 1 + #_callStack - count)
	color = color or colors.gray
	withColor(color)(function()
		for dep = beginDepth, beginDepth + count - 1 do
			local record = _callStack[dep]
			if record then
				print("[stack #"..dep.."]", record)
			else
				break
			end
		end
		printC(colors.grey)("[total call stack depth]", #_callStack)
	end)()
end

_printCallStackCo = function()
	while true do
		_waitForKeyCombination(keys.leftCtrl, keys.p)
		_printCallStack(10, nil, colors.blue)
	end
end

