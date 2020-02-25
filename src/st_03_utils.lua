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

