class_name MazeLogic
extends RefCounted

## Grafo do labirinto em arvore + gerador (recursive backtracker com filtros
## de dificuldade) + trilha da crianca. Celula = Vector2i(coluna, linha);
## linha 0 e' a base.

const MIN_PATH := 24
const MAX_PATH := 42
const MIN_JUNCTIONS := 3
const MAX_JUNCTIONS := 4
const MAX_ATTEMPTS := 200
const MAX_STEPS_PER_ADVANCE := 4

var width := 0
var height := 0
var entrance := Vector2i.ZERO
var exit := Vector2i.ZERO

var _open_east := {}
var _open_north := {}
var _solution: Array = []

# trilha
var trail: Array[Vector2i] = []
var _visited := {}

static func generate(maze_width: int, maze_height: int) -> MazeLogic:
	var last: MazeLogic = null
	for attempt in MAX_ATTEMPTS:
		var grid := _carve(maze_width, maze_height)
		if grid._accepts():
			grid._reset_trail()
			return grid
		last = grid
	last._reset_trail()
	return last

static func _carve(maze_width: int, maze_height: int) -> MazeLogic:
	var grid := MazeLogic.new()
	grid.width = maze_width
	grid.height = maze_height
	grid.entrance = Vector2i(0, randi() % maze_height)
	grid.exit = Vector2i(maze_width - 1, randi() % maze_height)
	var visited := {grid.entrance: true}
	var stack: Array[Vector2i] = [grid.entrance]
	while stack.size() > 0:
		var current: Vector2i = stack.back()
		var candidates: Array[Vector2i] = []
		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next: Vector2i = current + offset
			if next.x < 0 or next.x >= maze_width or next.y < 0 or next.y >= maze_height:
				continue
			if visited.has(next):
				continue
			candidates.append(next)
		if candidates.is_empty():
			stack.pop_back()
			continue
		var chosen: Vector2i = candidates[randi() % candidates.size()]
		grid._set_edge(current, chosen, true)
		visited[chosen] = true
		stack.append(chosen)
	return grid

func _accepts() -> bool:
	var length := solution().size()
	if length < MIN_PATH or length > MAX_PATH:
		return false
	var junctions := _junctions_on_solution()
	return junctions >= MIN_JUNCTIONS and junctions <= MAX_JUNCTIONS

func _reset_trail() -> void:
	trail = [entrance]
	_visited = {entrance: true}

# ----- arestas -----

func _set_edge(a: Vector2i, b: Vector2i, value: bool) -> void:
	if a.y == b.y and absi(a.x - b.x) == 1:
		_open_east[Vector2i(mini(a.x, b.x), a.y)] = value
		return
	if a.x == b.x and absi(a.y - b.y) == 1:
		_open_north[Vector2i(a.x, mini(a.y, b.y))] = value

## Selar um galho errado NAO muda o caminho certo (solucao segue em cache).
func seal_edge(a: Vector2i, b: Vector2i) -> void:
	_set_edge(a, b, false)

func is_open(a: Vector2i, b: Vector2i) -> bool:
	if a.y == b.y and absi(a.x - b.x) == 1:
		return _open_east.get(Vector2i(mini(a.x, b.x), a.y), false)
	if a.x == b.x and absi(a.y - b.y) == 1:
		return _open_north.get(Vector2i(a.x, mini(a.y, b.y)), false)
	return false

func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var candidate: Vector2i = cell + offset
		if is_open(cell, candidate):
			result.append(candidate)
	return result

func is_dead_end(cell: Vector2i) -> bool:
	return neighbors(cell).size() == 1 and cell != entrance and cell != exit

## BFS de from ate to (arvore: caminho unico), incluindo os dois.
func path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var queue: Array[Vector2i] = [from]
	var came_from := {}
	var seen := {from: true}
	var index := 0
	while index < queue.size():
		var cell: Vector2i = queue[index]
		index += 1
		if cell == to:
			break
		for neighbor in neighbors(cell):
			if seen.has(neighbor):
				continue
			seen[neighbor] = true
			came_from[neighbor] = cell
			queue.append(neighbor)
	if not seen.has(to):
		return []
	var result: Array[Vector2i] = [to]
	var current := to
	while current != from:
		current = came_from[current]
		result.append(current)
	result.reverse()
	return result

func solution() -> Array:
	if _solution.is_empty():
		_solution = path(entrance, exit)
	return _solution

func _junctions_on_solution() -> int:
	var sol := solution()
	var count := 0
	for i in range(sol.size() - 1):
		var from: Variant = sol[i - 1] if i > 0 else null
		var options := 0
		for neighbor in neighbors(sol[i]):
			if from == null or neighbor != from:
				options += 1
		if options > 1:
			count += 1
	return count

# ----- trilha -----

func head() -> Vector2i:
	return trail.back()

func is_at_dead_end() -> bool:
	return is_dead_end(head())

func is_on_trail(cell: Vector2i) -> bool:
	return _visited.has(cell)

## Quantas celulas da trilha ja estao fora da solucao.
func off_solution_count() -> int:
	var sol := {}
	for cell in solution():
		sol[cell] = true
	var count := 0
	for i in range(trail.size() - 1, -1, -1):
		if sol.has(trail[i]):
			break
		count += 1
	return count

## Estende a trilha ate target pelo caminho da arvore. Recusa pulo de muro
## (>4 passos), para no primeiro passo ja visitado e trunca na saida.
func advance(target: Vector2i) -> Array[Vector2i]:
	var added: Array[Vector2i] = []
	if target == head() or head() == exit:
		return added
	var route := path(head(), target)
	if route.size() - 1 > MAX_STEPS_PER_ADVANCE:
		return added
	for i in range(1, route.size()):
		var cell := route[i]
		if _visited.has(cell):
			break
		trail.append(cell)
		_visited[cell] = true
		added.append(cell)
		if cell == exit:
			break
	return added

## Ultima celula da trilha ainda na solucao (ate onde o beco rebobina).
func last_divergence() -> Vector2i:
	var sol := {}
	for cell in solution():
		sol[cell] = true
	for i in range(trail.size() - 1, -1, -1):
		if sol.has(trail[i]):
			return trail[i]
	return entrance

## Remove tudo depois de to_cell; devolve as removidas em ordem.
func rewind(to_cell: Vector2i) -> Array[Vector2i]:
	var index := trail.find(to_cell)
	var removed: Array[Vector2i] = []
	if index < 0:
		return removed
	for i in range(index + 1, trail.size()):
		removed.append(trail[i])
		_visited.erase(trail[i])
	trail.resize(index + 1)
	return removed
