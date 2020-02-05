----------------------------------- IO Monad -----------------------------------

-- | mkIO : (a... -> b, a...) -> IO b
mkIO, mkIOfn = (function()
	local _ioMetatable = {}
	local _mkIO = function(f, ...)
		local args = {...}
		local io = {
			run = function() return f(unpack(args)) end,
			['then'] = function(io1, f2) return _mkIO(function() return f2(io1.run()).run() end) end, --  `>>=` in haskell
		}
		setmetatable(io, _ioMetatable)
		return io
	end
	local _mkIOfn = function(f)
		return function(...) return _mkIO(f, ...) end
	end
	_ioMetatable.__len = function(io) return _mkIO(function() local r; repeat r = io.run() until(r); return r end) end -- use `#io` as `rep(io)`, only works on lua5.2+
	_ioMetatable.__call = function(io, ...) return io.run(...) end
	_ioMetatable.__mod = function(io, s) return retry(s)(io) end -- retry for a few seconds
	_ioMetatable.__pow = function(io, n) return replicate(n)(io) end -- replicate a few times
	_ioMetatable.__add = function(io1, io2) return _mkIO(function() return io1.run() or io2.run() end) end -- if io1 fail then io2
	_ioMetatable.__mul = function(io1, io2) return _mkIO(function() return io1.run() and io2.run() end) end -- if io1 succ then io2
	_ioMetatable.__div = function(io1, io2) return _mkIO(function() r = io1.run(); io2.run(); return r end) end -- `<*` in haskell
	_ioMetatable.__unm = function(io) return _mkIO(function() return not io.run() end) end -- use `-io` as `fmap not io` in haskell
	return _mkIO, _mkIOfn
end)()

-- | pure : a -> IO a
pure = function(x) return mkIO(function() return x end) end

-- | try : IO a -> IO Bool
try = function(io) return mkIO(function() io(); return true end) end

-- | retry : Int -> IO Bool -> IO Bool
-- , retry an io which might fail for several seconds before finally fail
retry = function(retrySeconds)
	return function(io)
		return mkIO(function()
			local r = io()
			if r then return r end
			local maxInterval = 0.5
			local waitedSeconds = 0.0
			while waitedSeconds < retrySeconds do -- state: {waitedSeconds, maxInterval}
				local interval = math.min(retrySeconds - waitedSeconds, math.random() * maxInterval)
				sleep (interval)
				r = io()
				if r then return r end
				waitedSeconds = waitedSeconds + interval
				maxInterval = maxInterval * 2
			end
			return r
		end)
	end
end

-- | replicate : Int -> IO a -> IO Int
replicate = function(n)
	return function(io)
		return mkIO(function()
			local c = 0
			for i = 1, n do
				local r = io()
				if r then c = c + 1 end
			end
			return c
		end)
	end
end

-- | repeatUntil : (a -> Bool) -> IO a -> IO a
repeatUntil = function(stopCond)
	return function(io)
		return mkIO(function() local c = 0; while not stopCond(io()) do c = c + 1 end; return c end)
	end
end

-- | repeat until fail,  (use `rep(-io)` as repeat until success)
-- , return successfully repeated times
rep = function(io)
	return mkIO(function() local c = 0; while io() do c = c + 1 end; return c end)
end

