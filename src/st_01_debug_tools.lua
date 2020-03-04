--------------------------------- debug tools ----------------------------------

DEBUG = true
__assert = assert
if DEBUG then assert = __assert else assert = function() end end
--assert = function(...) if DEBUG then __assert(...) end end

_callStack = {}

-- | markCallSite : CallSiteName -> (() -> a) -> a
markCallSite = function(callSiteDesc)
	if not DEBUG then return function(x) return x end end
	return function(lazyProc)
		table.insert(_callStack, "*"..callSiteDesc)
		local r = { lazyProc() }
		table.remove(_callStack, #_callStack)
		return unpack(r)
	end
end

-- | markFn : FunctionName -> (a -> b) -> (a -> b)
markFn = function(name)
	if not DEBUG then return function(x) return x end end
	return function(func)
		return function(...)
			table.insert(_callStack, name)
			local r = { func(...) }
			table.remove(_callStack, #_callStack)
			return unpack(r)
		end
	end
end

-- | markIO : FunctionName -> (IO a) -> (IO a)
markIO = function(name)
	if not DEBUG then return function(x) return x end end
	return mkIOfn(function(io)
		table.insert(_callStack, name)
		local r = { io() }
		table.remove(_callStack, #_callStack)
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

withColor = function(fg, bg, _term)
	local t = default(term)(_term)
	return (mkIOfn(function(io)
		local saved_fg = t.getTextColor()
		local saved_bg = t.getBackgroundColor()
		t.setTextColor(default(saved_fg)(fg))
		t.setBackgroundColor(default(saved_bg)(bg))
		local r = {io()}
		t.setTextColor(saved_fg)
		t.setBackgroundColor(saved_bg)
		return unpack(r)
	end))
end

printC = function(fg, bg)
	return markFn("printC(fg, bg)(...)")(function(...)
		return withColor(fg, bg)(delay(print, ...))()
	end)
end

writeC = function(fg, bg)
	return markFn("writeC(fg, bg)(...)")(function(...)
		return withColor(fg, bg)(delay(write, ...))()
	end)
end

_callStackDepth = function(stack)
	stack = default(_callStack)(stack)
	local dep = 0
	for i, record in ipairs(stack) do
		if record.sub(1, 1)	~= "*" then -- a new call
			dep = dep + 1
		end
	end
	return dep
end

-- | convert a call stack into a list of string
_showCallStack = function(count, beginDepth, stack)
	stack = default(_callStack)(stack)
	count = math.max(0, default(#stack)(count))
	beginDepth = math.max(1, default(1 + #stack - count)(beginDepth))
	local dep, res = 0, {}
	for i, record in ipairs(stack) do
		if string.sub(record, 1, 1)	~= "*" then -- a new call
			dep = dep + 1
			if dep >= beginDepth + count then
				break
			end
			if dep >= beginDepth then
				table.insert(res, "[" .. dep .. "] " .. record)
			end
		else -- a call site desc
			if dep >= beginDepth and #res > 0 then
				res[#res] = res[#res] .. " " .. record
			end
		end
	end
	return res
end

_printCallStack = function(count, beginDepth, color, stack)
	stack = default(_callStack)(stack)
	count = math.max(0, default(#stack)(count))
	beginDepth = math.max(1, default(1 + #stack - count)(beginDepth))
	color = color or colors.gray
	local ls = _showCallStack(count, beginDepth, stack)
	local s = table.concat(ls, "\n")
	withColor(color)(function()
		local dep = _callStackDepth(stack)
		local maxLines = table.pack(term.getSize())[2] - 2
		local more = #ls - maxLines
		if more > 0 then
			maxLines, more = maxLines - 1, more + 1
			printC(colors.gray)("[printing call stack] " .. (more) .. "more lines left...")
		end
		textutils.pagedPrint(s, maxLines)
		printC(colors.gray)("[total call stack depth]", dep)
	end)()
end

