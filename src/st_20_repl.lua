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
	inputHandler = eval,
	readOnlyEnv = _ST,
	abortHander = nil,
	historyLimit = 100,
	historyFilePath = "/.st_repl_history",
	style = _replStyle,
})

_replMainCo = _repl.start

