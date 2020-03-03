----------------------------------- fp utils -----------------------------------

-- | identity : a -> a
identity = function(x) return x end

negate = function(x) return -x end

-- | pipe : (a -> b) -> (b -> c) -> a -> c
-- , pipe == flip compose
pipe = function(f, ...)
	local fs = {...}
	if #fs == 0 then return f end
	return function(...) return pipe(unpack(fs))(f(...)) end
end

-- | default : a -> Maybe a -> a
default = function(dft)
	return function(x) if x ~= nil then return x else return dft end end
end

-- | maybe : (b, a -> b) -> Maybe a -> b
maybe = function(dft, wrap)
	return function(x) if x == nil then return dft else return wrap(x) end end
end

-- | apply : a -> (a -> b) -> b
apply = function(...)
	local args = {...}
	return function (f) return f(unpack(args)) end
end

-- | delay : (a -> b, a) -> IO b
delay = function(f, ...)
	local args = {...}
	return function() return f(unpack(args)) end
end

memoize = function(f)
	local mem = {}
	setmetatable(mem, {__mode = "kv"})
	return function(...)
		local r = mem[{...}]
		if r == nil then
			r = f(...)
			mem[{...}] = r
		end
		return r
	end
end

-------------------------------- general utils ---------------------------------

hasDictKey = function(t)
	if type(t) ~= "table" then return false end
	local x = false
	for _, _ in pairs(t) do
		x = true; break
	end
	return x
end

deepcopy = function(obj)
	local lookup_table = {}
	local function _copy(obj)
		if type(obj) ~= "table" then
			return obj
		elseif lookup_table[obj] then
			return lookup_table[obj]
		end
		local new_table = {}
		lookup_table[obj] = new_table
		for index, value in pairs(obj) do
			new_table[_copy(index)] = _copy(value)
		end
		return setmetatable(new_table, getmetatable(obj))
	end
	return _copy(obj)
end

math.randomseed(os.time() + os.clock()) -- set randomseed for math.random()

_ST = _ENV

-- | eval an expr or a peice of code
eval = function(code, env, readOnlyEnv)
	if not (env or readOnlyEnv) then env, readOnlyEnv = {}, _ST end
	if readOnlyEnv then setmetatable(env, {__index = readOnlyEnv}) end

	local func = load("return unpack(table.pack(" .. code .. "));", "=lua", "t", env)
	if not func then
		func, compileErr = load(code, "=lua", "t", env)
	end

	if func then
		local old_stack = deepcopy(_callStack)
		local res1 = { pcall( func ) }
		if table.remove(res1, 1) then
			if #res1 == 1 and type(res1[1]) == "table" and type(res1[1].run) == "function" then
				-- directly run a single IO monad
				local res2 = { pcall( res1[1].run ) }
				if table.remove(res2, 1) then
					return true, res2
				else
					local new_stack = _callStack
					_callStack = old_stack
					return false, {msg = res2[1], stack = new_stack}
				end
			else -- trivial case
				return true, res1
			end
		else
			local new_stack = _callStack
			_callStack = old_stack
			return false, {msg = res1[1], stack = new_stack}
		end
	else
		return false, {msg = '[compile error] '..compileErr, stack = nil}
	end
end

_ST_SAFE = _ST --TODO: hide unsafe variables

-- | safeEval is supposed to change nothing
-- , use _ST_SAFE as readOnlyEnv by default
safeEval = function(code, readOnlyEnv)
	if not readOnlyEnv then readOnlyEnv = _ST_SAFE end
	return eval(code, {}, readOnlyEnv)
end

-- | execute a piece of code, similar to eval, but print out the result directly
exec = function(code, env, readOnlyEnv)
	if code:sub(1, 7) == "http://" or code:sub(1, 8) == "https://" then
		local h = http.get(code)
		if h then
			code = h.readAll()
		else
			printC(colors.red)("[exec] failed to fetch code from:", code)
			return
		end
	end
	-- got code
	local ok, res = eval(code, env, readOnlyEnv)
	if ok then
		if #res > 0 then
			printC(colors.green)(show(unpack(res)))
		end
	else
		if res.stack then _printCallStack(nil, nil, colors.gray, res.stack) end
		printC(colors.red)(res.msg)
	end
end

-------------------------------- string utils ----------------------------------

-- | convert a value to string for printing
function show(...)
	return _serialiseTable({...}, _show, ",", "", "", "nil")
end

function _show(val)
	local ty = type(val)
	if ty == "table" then
		local mt = getmetatable(val)
		if type(mt) == "table" and type(mt.__tostring) == "function" then
			return tostring(val)
		else
			local ok, s = pcall(textutils.serialise, val)
			if ok then return s else return tostring(val) end
		end
	elseif ty == "string" then
		return _literalString(val)
	else
		return tostring(val)
	end
end

-- | convert a table to string via serialElem for each element
-- , NOTE: `_serialiseTable({1, nil, 2}, show)` will print as "{1}" instead of "{1,nil,2}"
function _serialiseTable(t, serialElem, spliter, head, tail, placeholder)
	spliter = default(",")(spliter)
	head = default("{")(head)
	tail = default("}")(tail)
	local s = head
	for i, v in ipairs(t) do
		if i > 1 then s = s .. spliter end
		s = s .. serialElem(v)
	end
	local sp = #t > 0
	for k, v in pairs(t) do
		if type(k) ~= "number" or k > #t then
			if sp then s = s .. spliter end
			sp = true
			s = s .. _literalKey(k) .. "=" .. serialElem(v) --TODO: wrap special key with [] and escape
		end
	end
	if not sp and placeholder then
		return placeholder
	end
	return s .. tail
end

showWords = function(...) return _serialiseTable({...}, show, " ", "", "", "") end
showLines = function(...) return _serialiseTable({...}, show, "\n", "", "", "") end

function literal(...)
	return _serialiseTable({...}, _literal, ",", "", "", "nil")
end

function _literal(val)
	local ty = type(val)
	if ty == "table" then
		local mt = getmetatable(val)
		if type(mt) == "table" then
			if type(mt.__literal) == "function" then
				return mt.__literal(val)
			else
				return nil
			end
		else
			return _serialiseTable(val, _literal)
		end
	elseif ty == "string" then
		return _literalString(val)
	elseif ty == "function" then
		return nil
	else
		return tostring(val)
	end
end

function _literalString(val)
	return textutils.serialise(val)
end

function _literalKey(k)
	if type(k) == "string" then
		return k --TODO: escape special chars
	else
		return "[" .. _literal(k) .. "]"
	end
end

------------------------------ ui event utils ----------------------------------

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

---------------------------------- fs utils ------------------------------------

readFile = function(fileHandle)
	local isTempHandle = false
	if type(fileHandle) == "string" then -- file path/name used
		fileHandle = fs.open(fileHandle, 'r')
		isTempHandle = true
	end
	if not fileHandle then return nil end
	local res = fileHandle.readAll()
	if isTempHandle then
		fileHandle.close()
	end
	return res
end

writeFile = function(fileHandle, s, mode)
	local isTempHandle = false
	mode = default('w')(mode)
	if type(fileHandle) == "string" then -- file path/name used
		fileHandle = fs.open(fileHandle, mode)
		isTempHandle = true
	end
	fileHandle.write(s)
	if isTempHandle then
		fileHandle.close()
	else
		fileHandle.flush()
	end
end

readLines = function(fileHandle)
	local isTempHandle = false
	if type(fileHandle) == "string" then -- file path/name used
		fileHandle = fs.open(fileHandle, 'r')
		isTempHandle = true
	end
	if not fileHandle then return nil end
	local res = {}
	local line
	while true do
		line = fileHandle.readLine()
		if not line then break end
		table.insert(res, line)
	end
	if isTempHandle then
		fileHandle.close()
	end
	return res
end

writeLines = function(fileHandle, ls, mode)
	local isTempHandle = false
	mode = default('w')(mode)
	if type(fileHandle) == "string" then -- file path/name used
		fileHandle = fs.open(fileHandle, mode)
		isTempHandle = true
	end
	for _, s in ipairs(ls) do
		fileHandle.writeLine(s)
	end
	if isTempHandle then
		fileHandle.close()
	else
		fileHandle.flush()
	end
end

--------------------------------- rednet utils ---------------------------------

function openWirelessModem()
	for _, mSide in ipairs( peripheral.getNames() ) do
		if peripheral.getType( mSide ) == "modem" then
			local modem = peripheral.wrap( mSide )
			if modem.isWireless() then
				rednet.open(mSide)
				return true
			end
		end
	end
	return false
end

_log_colors = {
	info = colors.green,
	warn = colors.yellow,
	bug = colors.red,
	cry = colors.orange,
}

function _log(ty)
	return function(msg)
		rednet.broadcast(literal(ty, msg), "log") --NOTE: use "log" as protocol code
		printC(_log_colors[ty])(msg)
	end
end

log = {
	info = _log("info"), -- information, like global state updation
	warn = _log("warn"), -- some weird things happend, like network error, but not need to process it at once
	bug = _log("bug"), -- bug, some weird things happend or some assertion failed, need to check the code
	cry = _log("cry"), -- there is some turtle needing help, such as refueling or unloading
}

