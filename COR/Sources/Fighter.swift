public enum Pose: Sendable { case idle, walk, crouch, jump, dash, attack, hit, `guard`, frozen, down }

struct PendingCommand: Sendable {
	var move: MoveID = .none
	var predecessor: MoveID = .none
	var expires = -1
}

public struct Fighter: Sendable {
	public static let maxHealth = 1_000
	public internal(set) var character: Character
	public internal(set) var health = maxHealth
	public internal(set) var wins = 0
	public internal(set) var x: Int32
	public internal(set) var y: Int32 = 0
	public internal(set) var vx: Int32 = 0
	public internal(set) var vy: Int32 = 0
	public internal(set) var facing: Int32
	public internal(set) var pose: Pose = .idle
	public internal(set) var move: MoveID = .none
	public internal(set) var moveFrame = 0
	public internal(set) var stun = 0
	public internal(set) var caughtBy: MoveID = .none
	public internal(set) var comboHits = 0
	public internal(set) var comboDamage = 0
	public internal(set) var comboFrame = -100
	public var moveData: MoveData { character.data(for: move) }

	public var airborne: Bool {
		y > 0 || vy != 0
	}
	public var crouching: Bool {
		!airborne && (
			pose == .crouch || (pose == .guard && input.vertical < 0)
				|| move == .crouch1 || move == .uppercut || move == .lowKick
				|| move == .sweep || move == .slide || move == .takedown
		)
	}
	public var intangible: Bool {
		pose == .down || (move.isTeleport && moveFrame >= 4 && moveFrame < (move == .smokeTeleport ? 14 : 10))
	}

	var input: Input = []
	var history = CommandHistory()
	var queue: InlineArray<4, PendingCommand> = .init(repeating: .init())
	var queueCount = 0
	var connected = false
	var contacted = false
	var effectDone = false
	var dashFrames = 0
	var dashDirection: Int32 = 0
	var dashForward = false
	var pendingDash: Int32 = 0
	var pendingJump = false
	var falling = false
	var chainHits = 0
	var chainDamage = 0
	var launched = false
	var captured = false

	public init(character: Character, side: Int) {
		self.character = character
		x = side == 0 ? -384 : 384
		facing = side == 0 ? 1 : -1
	}

	mutating func ingest(_ frameInput: borrowing InputFrame, frame: Int) {
		var delivered: Input = []
		for i in 0 ..< frameInput.count {
			let state = frameInput.changes[i]
			let pressed = state.subtracting(input)
			delivered.formUnion(pressed)
			ingest(state, pressed: pressed, frame: frame)
		}
		let pressed = frameInput.held.subtracting(input).union(frameInput.pressed.subtracting(delivered))
		ingest(frameInput.held, pressed: pressed, frame: frame)
	}

	private mutating func ingest(_ state: Input, pressed: Input, frame: Int) {
		let dash = history.record(state, facing: facing, frame: frame)
		if dash != 0 { pendingDash = dash }
		if state.contains([.left, .right]) || state.contains([.up, .down]) { pendingDash = 0 }
		if pressed.contains(.up), state.vertical > 0 { pendingJump = true }
		input = state
		for button in 0 ..< 4 where pressed.contains(.attack(button)) {
			guard queueCount < queue.count else { continue }
			if let move = special(character: character, button: button, history: history, frame: frame) {
				let previous = queueCount > 0 ? queue[queueCount - 1].move : self.move
				let predecessor = previous.isSpecial ? MoveID.none : previous
				queue[queueCount] = .init(move: move, predecessor: predecessor, expires: frame + (predecessor == .none ? 14 : 30))
				history.consumedFrame = frame
			} else {
				var predecessor = move
				for i in 0 ..< queueCount { predecessor = queue[i].move }
				let string = character.stringOne
				let relativeHorizontal = state.horizontal * facing
				let direction = relativeHorizontal < 0 ? Input.left : relativeHorizontal > 0 ? .right : []
				let directional: MoveID? = !airborne && state.vertical == 0
					? (direction == .left && button == 0 ? .backPunch
						: direction == string.direction && button == string.firstButton ? string.starter : nil)
					: nil
				if predecessor.isUniqueStringStarter, let next = predecessor.continuation(button) {
					queue[queueCount] = .init(move: next, predecessor: predecessor, expires: frame + 60)
				} else if let directional {
					queue[queueCount] = .init(move: directional, expires: frame + 14)
				} else if let next = predecessor.continuation(button) {
					queue[queueCount] = .init(move: next, predecessor: predecessor, expires: frame + 60)
				} else {
					let base = airborne ? MoveID.air1.rawValue : state.vertical < 0 ? MoveID.crouch1.rawValue : MoveID.punch1.rawValue
					queue[queueCount] = .init(move: MoveID(rawValue: base + UInt8(button))!, expires: frame + 14)
				}
			}
			queueCount += 1
		}
	}

	mutating func removeCommand(at index: Int) {
		queueCount -= 1
		for i in index ..< queueCount { queue[i] = queue[i + 1] }
	}

	mutating func clearCommands() {
		queueCount = 0
		pendingDash = 0
		pendingJump = false
	}

	mutating func start(_ move: MoveID) {
		self.move = move
		moveFrame = 0
		connected = false
		contacted = false
		effectDone = false
		dashFrames = 0
		pose = .attack
		if !airborne { vx = 0 }
	}

	mutating func resetChain() {
		chainHits = 0
		chainDamage = 0
		launched = false
		captured = false
		caughtBy = .none
	}
}

struct Box {
	var left: Int32
	var bottom: Int32
	var right: Int32
	var top: Int32

	func overlaps(_ other: Box) -> Bool {
		left <= other.right && right >= other.left && bottom <= other.top && top >= other.bottom
	}
}

extension Fighter {
	var hurtbox: Box {
		.init(left: x - 65, bottom: y + 16, right: x + 65, top: y + (crouching ? 280 : 520))
	}

	var hitbox: Box {
		let data = moveData
		let reach = data.reach
		var bottom: Int32 = 205
		var top: Int32 = 600
		switch data.level {
		case .high: bottom = 340; top = 600
		case .mid: break
		case .low: bottom = 25; top = 145
		case .overhead: bottom = 180; top = 600
		}
		if data.effect == .launch, !move.isProjectile { bottom = 90; top = 660 }
		if move == .iceBurst { bottom = 90; top = 660 }
		if move == .smokeTeleport { bottom = 40; top = 360 }
		return .init(left: x + (facing > 0 ? 40 : -reach), bottom: y + bottom,
			right: x + (facing > 0 ? reach : -40), top: y + top)
	}

	func guards(_ level: HitLevel) -> Bool {
		guard !airborne, input.contains(.block), !intangible,
			pose != .hit, pose != .frozen, move == .none,
			dashFrames == 0 || dashForward else { return false }
		if crouching { return level == .mid || level == .low }
		return level != .low
	}
}
