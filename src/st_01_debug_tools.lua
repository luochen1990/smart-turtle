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

_printCallStack = function(count, beginDepth, color, stack)
	stack = default(_callStack)(stack)
	count = math.max(0, count or 10)
	beginDepth = math.max(1, beginDepth or 1 + #stack - count)
	color = color or colors.gray
	withColor(color)(function()
		for dep = beginDepth, beginDepth + count - 1 do
			local record = stack[dep]
			if record then
				print("[stack #"..dep.."]", record)
			else
				break
			end
		end
		printC(colors.grey)("[total call stack depth]", #stack)
	end)()
end

