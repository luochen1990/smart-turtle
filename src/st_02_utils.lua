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

-- | eval an expr or a peice of code
eval = function(code, env, readOnlyEnv)
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

-------------------------------- string utils ----------------------------------

-- | convert a value to string for printing
function show(value)
	local metatable = getmetatable( value )
	if type(metatable) == "table" and type(metatable.__tostring) == "function" then
		return tostring( value )
	else
		local ok, serialised = pcall( textutils.serialise, value )
		if ok then
			return serialised
		else
			return tostring( value )
		end
	end
end

-- | convert a list to string for printing
-- , NOTE: `showList({1, nil, 2}, ",")` will print as "1" instead of "1,nil,2"
function showList(ls, spliter, placeholder)
	local s = placeholder or ""
	for i, x in ipairs(ls) do
		if i == 1 then s = show(x) else s = s..(spliter or "\n")..show(x) end
	end
	return s
end

showFields = function(...) return showList({...}, ", ", "nil") end
showWords = function(...) return showList({...}, " ", "") end
showLines = function(...) return showList({...}, "\n", "") end

------------------------------ coroutine utils ---------------------------------

function race(...)
	local res
	local cos = {}
	for i, io in ipairs({...}) do
		cos[i] = function() res = { io() } end
	end
	local id = parallel.waitForAny(unpack(cos))
	return id, unpack(res)
end

---------------------------------- fs utils ------------------------------------

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

