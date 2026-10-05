struct Observation {
	var distance: Int32 = 768
	var attacking = false
	var level: HitLevel = .mid
	var projectile = false
}

/// Delayed observations and ordinary button sequences, with no privileged moves.
public struct AI {
	private var observations: InlineArray<12, Observation> = .init(repeating: .init())
	private var cursor = 0
	private var sequence: InlineArray<32, Input> = .init(repeating: [])
	private var length = 0
	private var position = 0
	private var wait = 0
	private var random: UInt64

	public init(seed: UInt64 = 0x4D4B_394A_4144_45) { random = seed == 0 ? 1 : seed }

	public mutating func reset() {
		length = 0
		position = 0
		wait = 0
		cursor = 0
		observations = .init(repeating: .init())
	}

	public mutating func input(_ fight: borrowing Fight, player: Int = 1) -> InputFrame {
		guard fight.phase == .fighting else { reset(); return .init() }
		let fighter = fight.fighters[player]
		let opponent = fight.fighters[1 - player]
		let seen = observations[cursor]
		observations[cursor] = .init(distance: abs(fighter.x - opponent.x), attacking: opponent.move != .none,
			level: opponent.move.data.level, projectile: fight.projectiles[1 - player].active)
		cursor = (cursor + 1) % observations.count
		if fighter.stun > 0 { length = 0; position = 0; return .init(held: .block) }
		if position < length {
			let held = sequence[position]
			position += 1
			return .init(held: held)
		}
		if wait > 0 { wait -= 1; return .init() }

		random ^= random << 13
		random ^= random >> 7
		random ^= random << 17
		let roll = Int(random % 100)
		let forward: Input = fighter.facing > 0 ? .right : .left
		let back: Input = fighter.facing > 0 ? .left : .right
		sequence = .init(repeating: [])
		position = 1
		length = 0
		if (seen.attacking && seen.distance < 440) || seen.projectile, roll < 75 {
			length = 12
			let guardInput: Input = seen.level == .low ? [.block, .down] : .block
			for i in 0 ..< length { sequence[i] = guardInput }
		} else if seen.distance > 580, roll < 40, !fight.projectiles[player].active {
			let first: Input = fighter.character == .scorpion || fighter.character == .sektor ? back : .down
			sequence[0] = first
			sequence[1] = forward
			sequence[2] = [forward, .one]
			length = 4
			wait = 32
		} else if seen.distance > 245 {
			if roll < 45 {
				sequence[0] = forward
				sequence[2] = forward
				length = 12
			} else {
				length = 10
				for i in 0 ..< length { sequence[i] = forward }
			}
		} else if roll < 12 {
			sequence[0] = fighter.character == .scorpion || fighter.character == .sektor ? .down : back
			sequence[1] = fighter.character == .scorpion ? back : forward
			sequence[2] = [sequence[1], fighter.character == .scorpion ? .three : .four]
			length = 4
			wait = 34
		} else if roll < 23 {
			sequence[0] = [.up, forward]
			sequence[9] = .four
			length = 11
		} else if roll < 30 {
			sequence[0] = [.down, .three]
			length = 2
			wait = 22
		} else {
			sequence[0] = roll < 65 ? .one : .two
			sequence[2] = .one
			sequence[4] = .two
			length = 6
			wait = 28
		}
		return .init(held: sequence[0])
	}
}
