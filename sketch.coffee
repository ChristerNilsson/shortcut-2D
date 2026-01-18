import { button, createSignal, div, table, td, th, tr } from "https://cdn.jsdelivr.net/gh/sigmentjs/sigment-ng@1.3.4/dist/index.js"
import _ from "https://cdn.jsdelivr.net/npm/lodash-es@4.17.21/lodash.js"

echo = console.log 

normalizeComplex = (z) ->
	if Array.isArray(z) and z.length is 2
		re: z[0]
		im: z[1]
	else
		re: z.re
		im: z.im 

keyOf = (z) -> "#{z.re},#{z.im}"

reconstructPath = (prev, move, endKey) ->
	path = []
	k = endKey 
	while k? 
		entry = prev[k]
		if entry?
			path.push
				state: entry.state
				op: move[k]
			k = entry.prev
		else
			k = null
	path.reverse()

bfsComplex = (start, target, opts = {}) ->
	start = normalizeComplex(start)
	target = normalizeComplex(target)
	maxSteps = if opts.maxSteps? then opts.maxSteps else 50
	maxAbs = if opts.maxAbs? then opts.maxAbs else 50

	startKey = keyOf(start)
	targetKey = keyOf(target)
	return [ { state: start, op: null } ] if startKey is targetKey

	queue = [ start ]
	head = 0
	visited = new Set([ startKey ])
	prev = {}
	move = {}
	prev[startKey] = { prev: null, state: start }

	withinBounds = (z) ->
		z.re >= 1 and z.re <= 8 and z.im >= 1 and z.im <= 8

	neighbors = (z) ->
		ops.map (op) ->
			{ op: op.label, state: applyOp(z, op) }

	steps = 0
	while head < queue.length and steps <= maxSteps
		levelCount = queue.length - head
		for i in [0...levelCount]
			cur = queue[head++]
			curKey = keyOf(cur)

			for next in neighbors(cur)
				continue unless withinBounds(next.state)
				k = keyOf(next.state)
				continue if visited.has(k)
				visited.add(k)
				prev[k] = { prev: curKey, state: next.state }
				move[k] = next.op
				return reconstructPath(prev, move, k) if k is targetKey
				queue.push(next.state)

		steps += 1

	null

formatComplex = (z) ->
	if isOnBoard z
		file = String.fromCharCode 96 + z.re
		rank = z.im
		"#{file}#{rank}"
	else if z.im is 1
		"#{z.re}+i"
	else if z.im is -1
		"#{z.re}-i"
	else if z.im < 0
		"#{z.re}-#{Math.abs(z.im)}i"
	else
		"#{z.re}+#{z.im}i"

applyOp = (z, op) ->
	re: evalRpn(op.reExpr, z.re, z.im)
	im: evalRpn(op.imExpr, z.re, z.im)

OPS = "x1+:y2+ x2+:y1+ x2+:y1- x1+:y2- x1-:y2- x2-:y1- x2-:y1+ x1-:y2+"

parseOps = (spec) ->
	items = spec.trim().split /\s+/
	items.map (item) ->
		parts = item.split ":"
		{
			label: item
			reExpr: parts[0]
			imExpr: parts[1]
		}

evalRpn = (expr, x, y) ->
	stack = []
	i = 0
	while i < expr.length
		ch = expr[i]
		if ch >= "0" and ch <= "9"
			start = i
			while i < expr.length and expr[i] >= "0" and expr[i] <= "9"
				i += 1
			stack.push parseInt expr[start...i], 10
			continue
		if ch is "x"
			stack.push x
		else if ch is "y"
			stack.push y
		else if ch is "c"
			val = stack.pop()
			stack.push -val
		else if ch is "+" or ch is "-" or ch is "*" or ch is "/"
			b = stack.pop()
			a = stack.pop()
			switch ch
				when "+" then stack.push a + b
				when "-" then stack.push a - b
				when "*" then stack.push a * b
				when "/" then stack.push a / b
		i += 1
	stack[0]

isOnBoard = (z) ->
	z.re >= 1 and z.re <= 8 and z.im >= 1 and z.im <= 8

start = { re: 1, im: 1 }
target = { re: 2, im: 3 }
n = 1
expectedMoves = n + 2
playerCount = 2

histories = ([ start ] for [0...playerCount])
playerSolved = (false for [0...playerCount])
ops = parseOps OPS
opButtons = [] 
labels = "ABCDEFGH"
players = []
targetEl = null
solutionsEl = null
bfsSolutionEl = null
newGameBtn = null
opsTableEl = null

createPlayerSignals = ->
	[current, setCurrent] = createSignal ""
	[expected, setExpected] = createSignal ""
	[board, setBoard] = createSignal null
	{
		current
		setCurrent
		expected
		setExpected
		board
		setBoard
	}

Player = (playerId, currentSignal, boardSignal, expectedSignal, onUndo) ->
	# undoEl = button { onclick: onUndo }, "Undo"
	# controlsEl = div { class: "controls" },
	# 	div { class: "ops" }
	# 	button { onclick: onUndo }, "Undo"
	div { class: "player", id: playerId },
		div {}, currentSignal
		div {}, boardSignal
		div { class: "expected" }, div {}, expectedSignal
		div { class: "controls" },
			div { class: "ops" }
			button { onclick: onUndo }, "Undo"

disableControls = (isDisabled) ->
	for btn in opButtons
		btn.disabled = isDisabled

render = ->
	targetEl.textContent = formatComplex(target)
	for player, idx in players
		history = histories[idx]
		player.signals.setCurrent formatComplex(history[history.length - 1])
		player.signals.setExpected "#{expectedMoves - (history.length - 1) - 2}"
		player.signals.setBoard buildBoard history[history.length - 1]

buildBoard = (currentPos) ->
	rows = []

	labelsForOps = ops.map (op, idx) -> labels[idx] or op.label
	reachable = new Map()
	for op, idx in ops
		candidate = applyOp currentPos, op
		continue unless isOnBoard candidate
		reachable.set keyOf(candidate), labelsForOps[idx]

	for rank in [8..1]
		cells = []
		cells.push th { class: "rank edge" }, "#{rank}"
		for file in [1..8]
			classes = [ "cell" ]
			classes.push "dark" if (file + rank) % 2 is 0
			key = "#{file},#{rank}"
			isStart = start.re is file and start.im is rank
			isTarget = target.re is file and target.im is rank
			isCurrent = currentPos.re is file and currentPos.im is rank
			classes.push "start-cell" if isStart
			classes.push "target-cell" if isTarget
			classes.push "current-cell" if isCurrent

			symbol = "•"
			if isStart or isCurrent
				symbol = ""
			else if isTarget
				if reachable.has key
					classes.push "reachable-cell"
					symbol = reachable.get key
				else
					symbol = ""
			else if reachable.has key
				classes.push "reachable-cell"
				symbol = reachable.get key
			cells.push td { class: classes.join(" ") }, symbol
		rows.push tr {}, cells...

	footCells = []
	footCells.push th { class: "corner edge" }
	for file in [1..8]
		footCells.push th { class: "edge" }, String.fromCharCode 96 + file
	rows.push tr {}, footCells...

	table { class: "board" }, rows...

showSolutions = ->
	userSteps = []
	for player, idx in players
		playerSteps = histories[idx].map formatComplex
		player.solutionEl.textContent = playerSteps.join "\n"
		userSteps.push histories[idx].length - 1
	bfsPath = bfsComplex start, target
	bfsSolutionEl.textContent = ((bfsPath or []).map ({ state }) -> formatComplex(state)).join "\n"
	solutionsEl.hidden = false
	bfsSteps = Math.max 0, (bfsPath or []).length - 1
	bothCorrect = userSteps.every (steps) -> steps is bfsSteps
	bothWrong = userSteps.every (steps) -> steps isnt bfsSteps
	if bothCorrect
		n += 1 
	else if bothWrong
		n = Math.max 1, n - 1  

hideSolutions = -> 
	solutionsEl.hidden = true
	for player in players
		player.solutionEl.textContent = ""
	bfsSolutionEl.textContent = ""

applyMove = (playerIndex, op) ->
	return if playerSolved[playerIndex]
	history = histories[playerIndex]
	next = applyOp history[history.length - 1], op
	return unless isOnBoard next
	history.push next
	playerSolved[playerIndex] = next.re is target.re and next.im is target.im
	if playerSolved.every (solved) -> solved
		disableControls true
		showSolutions()
	else
		hideSolutions()
	render()

undoMove = (playerIndex) ->
	history = histories[playerIndex]
	return if history.length <= 1
	history.pop()
	playerSolved[playerIndex] = false
	disableControls false
	hideSolutions()
	render()  

randomChoice = (arr) -> _.sample arr

randomSquare = ->
	re: 1 + Math.floor Math.random() * 8
	im: 1 + Math.floor Math.random() * 8
 
reachableInSteps = (from, steps) ->
	current = new Map()
	current.set keyOf(from), from
	for i in [0...steps]
		next = new Map() 
		for [ , state ] from current
			for op in ops
				candidate = applyOp state, op
				continue unless isOnBoard candidate
				next.set keyOf(candidate), candidate
		current = next
		break if current.size is 0
	state for [ , state ] from current

generateTarget = (from, steps) ->
	reachable = reachableInSteps from, steps
	return from if reachable.length is 0
	candidates = reachable.filter (pos) -> pos.re isnt from.re or pos.im isnt from.im
	return from if candidates.length is 0
	randomChoice candidates

newGame = ->
	echo 'newGame' 
	attempts = 0
	start = randomSquare()
	target = generateTarget start, n
	while n > 0 and target.re is start.re and target.im is start.im and attempts < 50
		start = randomSquare()
		target = generateTarget start, n
		attempts += 1
	expectedMoves = n + 2
	echo 'target',target
	histories = ([ start ] for [0...playerCount])
	playerSolved = (false for [0...playerCount])
	disableControls false
	hideSolutions()
	render()

initDom = ->
	playerConfigs = [
		{
			slotId: "player1-slot"
			playerId: "player1"
			solutionId: "player1-solution"
		}
		{
			slotId: "player2-slot"
			playerId: "player2"
			solutionId: "player2-solution"
		}
	]

	players = playerConfigs.map (cfg, idx) ->
		signals = createPlayerSignals()
		container = Player cfg.playerId, signals.current, signals.board, signals.expected, (-> undoMove idx)
		slotEl = document.getElementById cfg.slotId
		slotEl.replaceChildren container
		{
			index: idx
			signals
			ui: container
			solutionEl: document.getElementById cfg.solutionId
		}

	targetEl = document.getElementById "target"
	solutionsEl = document.getElementById "solutions"
	bfsSolutionEl = document.getElementById "bfs-solution"
	newGameBtn = document.getElementById "new-game"
	opsTableEl = document.getElementById "ops-table"
	newGameBtn.addEventListener "click", -> newGame()

	opButtons = []
	opRows = []
	playerButtons = players.map -> []
	for op, index in ops
		label = labels[index] or op.label
		row = tr {},
			td({}, label),
			td({}, op.reExpr),
			td({}, op.imExpr)
		opRows.push row

		for player, idx in players
			btn = button {}, label
			btn.addEventListener "click", do (op, player) -> -> applyMove player.index, op
			playerButtons[idx].push btn
			opButtons.push btn

	for player, idx in players
		opsContainer = player.ui.querySelector ".ops"
		opsContainer.replaceChildren playerButtons[idx]...

	opsTableEl.replaceChildren opRows...
	newGame()

if document.readyState is "loading"
	document.addEventListener "DOMContentLoaded", -> initDom()
else
	initDom()
