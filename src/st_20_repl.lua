----------------------------------- lua repl -----------------------------------

_replStyle = {
	helloText = "Welcome to Smart Turtle",
	helloColor = colors.lime,
	tipsText = "(This is a REPL, long press Ctrl+T to exit, press Ctrl+P to print call stack)",
	helpText = [[
	help -- print this help text
	Ctrl+D -- exit this REPL
	Ctrl+C -- abort running command
	Ctrl+P -- print current call stack
	Ctrl+L -- clean screen
	Ctrl+U -- clean current line
	]],
	tipsColor = colors.gray,
	promptText = "st> ",
	promptColor = colors.blue,
	commandColor = colors.lightBlue,
	resultColor = colors.white,
	errorStackColor = colors.gray,
	runCommandDefaultColor = colors.lightGray,
}

_repl = replTool.buildRepl({
	readOnlyEnv = _ST,
	inputHandler = eval,
	abortEventListener = function()
		local id = race_(delay(_waitForKeyCombination, keys.leftCtrl, keys.c), delay(os.pullEvent, "abort-repl-command"))()
		if id == 1 then return "by user keyboard shortcut"
		elseif id == 2 then return "by 'abort-repl-command' event"
		else error("[_repl.abortEventListener] id == "..show(id)) end
	end,
	abortHandler = function(msg, cmd, env)
		log.verb("repl command `"..cmd.."` aborted ("..msg..")")
		if turtle and workState.moveNotCommitted then
			if workState.gpsCorrected then
				log.verb("move aborted, now correcting gps pos again...")
				sleep(1) -- wait for pos stable
				workState.pos = gpsPos()
				log.verb("gps pos corrected, now at "..show(workState.pos))
			else
				log.cry("move aborted, now trying to approach beginPos and wait for user reboot...")
				move.to(O)()
				turn.to(F)()
			end
		end
	end,
	historyLimit = 100,
	historyFilePath = "/.st_repl_history",
	style = _replStyle,
})

abortReplCommand = mkIO(function()
	os.queueEvent("abort-repl-command")
	return retry(function() return not _repl.state.isRunningCommand end)()
end)

