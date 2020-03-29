----------------------------------- fp utils -----------------------------------

-- | identity : a -> a
identity = function(x) return x end

negate = function(x) return -x end

notb = function(b) return not b end

eq = function(x) return function(y) return x == y end end

plus = function(x) return function(y) return x + y end end

combine = function(f) return function(g) return function(x) return f(g(x)) end end end

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

-- | default : Dict k a -> Maybe (Dict k a) -> Dict k a
defaultDict = function(dft)
	return function(d)
		if type(d) == "table" then
			local rst = deepcopy(dft)
			for k, v in pairs(d) do
				rst[k] = v
			end
			return rst
		else
			return dft
		end
	end
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

sign = function(x) if x > 0 then return 1 elseif x < 0 then return -1 else return 0 end end
bool2int = function(b) if b then return 1 else return -1 end end

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

math.randomseed(os.time() * 1000) -- set randomseed for math.random()

-- | generate a comparator via a list of attribute getters
function comparator(...)
	local attrs = {...}
	return function(a, b)
		for i, attr in ipairs(attrs) do
			local aa, ab = attr(a), attr(b)
			if i == #attrs or aa ~= ab then return aa < ab end
		end
	end
end

function field(k, ...)
	local rest = {...}
	if #rest == 0 then
		return function(tabl)
			return tabl[k]
		end
	else
		return function(tabl)
			return field(unpack(rest))(tabl[k])
		end
	end
end

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
			if #res1 == 1 and isIO(res1[1]) then -- a single IO monad
				local res2 = { pcall( res1[1].run ) }
				if table.remove(res2, 1) then
					return true, res2
				else
					local new_stack = _callStack
					_callStack = old_stack
					return false, {title = 'runtime error', msg = res2[1], stack = new_stack}
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
		return false, {title = 'compile error', msg = compileErr}
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
-- , NOTE: this function might fail and returns nil when `serialElem` returns nil
function _serialiseTable(t, serialElem, spliter, head, tail, placeholder)
	spliter = default(",")(spliter)
	head = default("{")(head)
	tail = default("}")(tail)
	local s = head
	for i, v in ipairs(t) do
		if i > 1 then s = s .. spliter end
		--print("(1) v =", tostring(v))
		local sv = serialElem(v)
		if not sv then
			return nil
		end
		s = s .. sv
	end
	local sp = #t > 0
	for k, v in pairs(t) do
		if type(k) ~= "number" or k > #t then
			if sp then s = s .. spliter end
			sp = true
			local sk = _literalKey(k)
			--print("(2) v =", literal(v))
			local sv = serialElem(v)
			if not (sk and sv) then
				return nil
			end
			s = s .. sk .. "=" .. sv
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

-- | fail and return nil when got a function
function _literal(val)
	local ty = type(val)
	if ty == "table" then
		local mt = getmetatable(val)
		if type(mt) == "table" then
			if type(mt.__literal) == "function" then
				return mt.__literal(val)
			else
				error("[literal] non-trivial table which not impl __literal metamethod is not serialisable")
			end
		else
			return _serialiseTable(val, _literal)
		end
	elseif ty == "string" then
		return _literalString(val)
	elseif ty == "function" then
		error("[literal] function is not serialisable")
	else
		return tostring(val)
	end
end

function _literalString(val)
	return textutils.serialise(val)
end

function _literalKey(k)
	if type(k) == "string" then
		if string.match(k, "^[a-zA-Z_]+$") then -- simple identifier
			return k
		else
			return "[" .. _literalString(k) .. "]"
		end
	else
		return "[" .. _literal(k) .. "]"
	end
end

function showLit(...)
	return _serialiseTable({...}, _showLit, ",", "", "", "nil")
end

-- | never fail version of literal()
function _showLit(val)
	local ty = type(val)
	if ty == "table" then
		local mt = getmetatable(val)
		if type(mt) == "table" then
			if type(mt.__literal) == "function" then
				return mt.__literal(val)
			else
				return tostring(val)
			end
		else
			return _serialiseTable(val, _showLit)
		end
	elseif ty == "string" then
		return _literalString(val)
	else
		return tostring(val)
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

------------------------------- peripheral utils -------------------------------

function findPeripheral(deviceType, sides)
	sides = default( peripheral.getNames() )(sides)
	for _, side in ipairs(sides) do
		if peripheral.getType(side) == deviceType then
			return peripheral.wrap(side)
		end
	end
end

_monitor = findPeripheral("monitor")
if _monitor then
	_monitor.setTextScale(0.5)
end

function printM(fg, bg)
	if _monitor then
		return markFn("printM(fg, bg)(...)")(function(...)
			local old_term = term.redirect(_monitor)
			printC(fg, bg)(...)
			term.redirect(old_term)
		end)
	else
		return printC(fg, bg)
	end
end

function writeM(fg, bg)
	if _monitor then
		return markFn("writeM(fg, bg)(...)")(function(...)
			return withColor(fg, bg)(delay(_monitor.write, ...))()
		end)
	else
		return writeC(fg, bg)
	end
end

--------------------------------- rednet utils ---------------------------------

function openWirelessModem()
	for _, mSide in ipairs( peripheral.getNames() ) do
		if peripheral.getType( mSide ) == "modem" then
			local modem = peripheral.wrap( mSide )
			if (not modem.isWireless) or modem.isWireless() then
				rednet.open(mSide)
				return true
			end
		end
	end
	return false
end

_log_colors = {
	verb = colors.gray,
	info = colors.green,
	warn = colors.yellow,
	bug = colors.red,
	cry = colors.orange,
}

function _log(ty)
	if ty == "verb" then
		return function(msg)
			if turtle and workMode.verbose then
				rednet.broadcast(literal(ty, msg), "log") --NOTE: use "log" as protocol code
			end
			printC(_log_colors[ty])(msg)
		end
	else
		return function(msg)
			rednet.broadcast(literal(ty, msg), "log") --NOTE: use "log" as protocol code
			printC(_log_colors[ty])(msg)
		end
	end
end

function _logPrintCo(levelFilter, senderFilter)
	levelFilter = defaultDict({verb = true, info = true, warn = true, bug = true, cry = true})(levelFilter)
	while true do
		local senderId, rawMsg = rednet.receive("log")
		if not senderFilter or senderId == senderFilter then
			local ok, res = safeEval(rawMsg)
			if ok then
				local ty, msg = unpack(res)
				if levelFilter[ty] then
					printM(_log_colors[ty])("" .. os.time() .. " [" .. senderId .. "]: " .. msg)
				end
			end
		end
	end
end

log = {
	verb = _log("verb"), -- turtle verbose
	info = _log("info"), -- information, like global state updation
	warn = _log("warn"), -- some weird things happend, like network error, but not need to process it at once
	bug = _log("bug"), -- bug, some weird things happend or some assertion failed, need to check the code
	cry = _log("cry"), -- there is some turtle needing help, such as refueling or unloading
}

------------------------------ string glob utils -------------------------------

-- | Usage: local isSimpleString, judgeFunction = _globCompile(patternString)
function _globCompile(pat)
	local regex, n = string.gsub(pat, "\*", "[^:]\*")
	if n == 0 then
		return true, function(s) return s == pat end
	else
		return false, function(s) return s and string.find(s, "^"..regex.."$") ~= nil end
	end
end

-- | Usage 1: local ok = glob(pat)(s)
-- | Usage 2: local ok = glob({pat1, pat2})(s)
function glob(pat)
	if type(pat) == "string" then
		local _, judge = _globCompile(pat)
		return judge
	elseif type(pat) == "table" then
		local simpleSet = {}
		local globList = {}
		for _, p in ipairs(pat) do
			local isSimple, judge = _globCompile(p)
			if isSimple then
				simpleSet[p] = true
			else
				table.insert(globList, judge)
			end
		end
		return function(s)
			local v0 = simpleSet[s]
			if v0 == true then return true end
			for _, g in ipairs(globList) do
				if g(s) then return true end
			end
			return false
		end
	else
		error("[glob] pat should be string or table")
	end
end

function globDict(patDict)
	assert(type(patDict) == "table", "[globDict] patDict should be table")

	local globPairs = {}
	for k, v in pairs(patDict) do
		local isSimple, judge = _globCompile(k)
		if not isSimple then
			table.insert(globPairs, {judge, v})
		end
	end
	return function(s)
		local v0 = patDict[s]
		if v0 ~= nil then return v0 end
		for _, x in ipairs(globPairs) do
			local judge, v = unpack(x)
			if judge(s) then return v end
		end
	end
end

