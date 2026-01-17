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

histories = [ [ start ], [ start ] ]
playerSolved = [ false, false ]
ops = parseOps OPS
opButtons = []
labels = [ "A", "B", "C", "D", "E", "F", "G", "H" ]
currentPlayer = 0

player1CurrentEl = document.getElementById "player1-current"
player2CurrentEl = document.getElementById "player2-current"
targetEl = document.getElementById "target"
player1BoardEl = document.getElementById "player1-board"
player2BoardEl = document.getElementById "player2-board"
solutionsEl = document.getElementById "solutions"
player1SolutionEl = document.getElementById "player1-solution"
player2SolutionEl = document.getElementById "player2-solution"
bfsSolutionEl = document.getElementById "bfs-solution"
newGameBtn = document.getElementById "new-game"
opsEl = document.getElementById "ops"
opsEl2 = document.getElementById "ops-2"
opsTableEl = document.getElementById "ops-table"

disableControls = (isDisabled) ->
	for btn in opButtons
		btn.disabled = isDisabled

render = ->
	player1CurrentEl.textContent = formatComplex(histories[0][histories[0].length - 1])
	player2CurrentEl.textContent = formatComplex(histories[1][histories[1].length - 1])
	targetEl.textContent = formatComplex(target)
	renderBoard player1BoardEl, histories[0][histories[0].length - 1]
	renderBoard player2BoardEl, histories[1][histories[1].length - 1]

renderBoard = (containerEl, currentPos) ->
	containerEl.textContent = ""
	table = document.createElement "table"
	table.className = "board"

	labelsForOps = ops.map (op, idx) -> labels[idx] or op.label
	reachable = new Map()
	for op, idx in ops
		candidate = applyOp currentPos, op
		continue unless isOnBoard candidate
		reachable.set keyOf(candidate), labelsForOps[idx]

	for rank in [8..1]
		row = document.createElement "tr"
		rankCell = document.createElement "th"
		rankCell.className = "rank edge"
		rankCell.textContent = rank
		row.appendChild rankCell
		for file in [1..8]
			cell = document.createElement "td"
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
			if isStart
				symbol = ""
			else if isTarget and reachable.has key
				classes.push "reachable-cell"
				symbol = reachable.get key
			else if isCurrent
				symbol = formatComplex currentPos
			else if reachable.has key
				classes.push "reachable-cell"
				symbol = reachable.get key
			cell.className = classes.join " "
			cell.textContent = symbol
			row.appendChild cell
		table.appendChild row

	footRow = document.createElement "tr"
	footCorner = document.createElement "th"
	footCorner.className = "corner edge"
	footRow.appendChild footCorner
	for file in [1..8]
		th = document.createElement "th"
		th.className = "edge"
		th.textContent = String.fromCharCode 96 + file
		footRow.appendChild th
	table.appendChild footRow

	containerEl.appendChild table

showSolutions = ->
	playerOne = histories[0].map formatComplex
	playerTwo = histories[1].map formatComplex
	player1SolutionEl.textContent = playerOne.join "\n"
	player2SolutionEl.textContent = playerTwo.join "\n"
	bfsPath = bfsComplex start, target
	bfsSolutionEl.textContent = ((bfsPath or []).map ({ state }) -> formatComplex(state)).join "\n"
	solutionsEl.hidden = false
	bfsSteps = Math.max 0, (bfsPath or []).length - 1
	userSteps1 = histories[0].length - 1
	userSteps2 = histories[1].length - 1
	bothCorrect = userSteps1 is bfsSteps and userSteps2 is bfsSteps
	bothWrong = userSteps1 isnt bfsSteps and userSteps2 isnt bfsSteps
	if bothCorrect
		n += 1 
	else if bothWrong
		n = Math.max 1, n - 1  

hideSolutions = -> 
	solutionsEl.hidden = true
	player1SolutionEl.textContent = ""
	player2SolutionEl.textContent = ""
	bfsSolutionEl.textContent = ""

applyMove = (playerIndex, op) ->
	return if playerSolved[playerIndex]
	history = histories[playerIndex]
	next = applyOp history[history.length - 1], op
	return unless isOnBoard next
	history.push next
	playerSolved[playerIndex] = next.re is target.re and next.im is target.im
	if playerSolved[0] and playerSolved[1]
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
	[ state for [ , state ] from current ]

generateTarget = (from, steps) ->
	reachable = reachableInSteps from, steps
	return from if reachable.length is 0
	randomChoice reachable[0]  

newGame = ->
	echo 'newGame' 
	start = randomSquare()
	target = generateTarget start, n
	echo 'target',target
	histories = [ [ start ], [ start ] ]
	playerSolved = [ false, false ]
	disableControls false
	hideSolutions()
	render()

document.getElementById("undo").addEventListener "click", -> undoMove 0
document.getElementById("undo-2").addEventListener "click", -> undoMove 1
newGameBtn.addEventListener "click", -> newGame()

for op, index in ops
	label = labels[index] or op.label
	btn = document.createElement "button"
	btn.textContent = label
	btn.addEventListener "click", do (op) -> -> applyMove 0, op
	opsEl.appendChild btn
	opButtons.push btn

	row = document.createElement "tr"
	cellLabel = document.createElement "td"
	cellLabel.textContent = label
	cellOp = document.createElement "td"
	cellOp.textContent = op.reExpr
	cellOpY = document.createElement "td"
	cellOpY.textContent = op.imExpr
	row.appendChild cellLabel
	row.appendChild cellOp
	row.appendChild cellOpY
	opsTableEl.appendChild row

	btn2 = document.createElement "button"
	btn2.textContent = label
	btn2.addEventListener "click", do (op) -> -> applyMove 1, op
	opsEl2.appendChild btn2
	opButtons.push btn2

newGame()
