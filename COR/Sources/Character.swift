/// Directions are relative to the fighter: left is back and right is forward.
public struct SpecialCommand: Sendable {
	public let move: MoveID
	public let first: Input
	public let second: Input
	public let button: Int
	public let name: String

	/// The same three input states drive human commands, CPU commands and move hints.
	public func input(at step: Int, facing: Int32) -> Input {
		func absolute(_ direction: Input) -> Input {
			guard facing < 0 else { return direction }
			if direction == .left { return .right }
			if direction == .right { return .left }
			return direction
		}
		switch step {
		case 0: return absolute(first)
		case 1: return absolute(second)
		case 2: return [absolute(second), .attack(button)]
		default: return []
		}
	}

	public var hint: String {
		func letter(_ direction: Input) -> String {
			direction == .left ? "B" : direction == .right ? "F" : "D"
		}
		return "\(name)  \(letter(first)), \(letter(second)) + \(button + 1)"
	}
}

public enum Character: UInt8, CaseIterable, Sendable {
	case scorpion, subZero, jade, sektor, cyrax, kitana, smoke, liuKang

	public var name: String {
		switch self {
		case .scorpion: "SCORPION"
		case .subZero: "SUB-ZERO"
		case .jade: "JADE"
		case .sektor: "SEKTOR"
		case .cyrax: "CYRAX"
		case .kitana: "KITANA"
		case .smoke: "SMOKE"
		case .liuKang: "LIU KANG"
		}
	}

	public var commandOne: SpecialCommand {
		switch self {
		case .scorpion: .init(move: .spear, first: .left, second: .right, button: 0, name: "Spear")
		case .subZero: .init(move: .ice, first: .down, second: .right, button: 0, name: "Ice")
		case .jade: .init(move: .rang, first: .down, second: .right, button: 0, name: "Razor-rang")
		case .sektor: .init(move: .rocket, first: .left, second: .right, button: 0, name: "Rocket")
		case .cyrax: .init(move: .net, first: .left, second: .right, button: 0, name: "Net")
		case .kitana: .init(move: .fan, first: .down, second: .right, button: 0, name: "Fan")
		case .smoke: .init(move: .smokeCloud, first: .down, second: .left, button: 0, name: "Smoke cloud")
		case .liuKang: .init(move: .fireball, first: .down, second: .right, button: 0, name: "Fireball")
		}
	}

	public var commandTwo: SpecialCommand {
		switch self {
		case .scorpion: .init(move: .teleport, first: .down, second: .left, button: 2, name: "Teleport")
		case .subZero: .init(move: .slide, first: .left, second: .right, button: 3, name: "Slide")
		case .jade: .init(move: .shadowKick, first: .left, second: .right, button: 3, name: "Shadow kick")
		case .sektor: .init(move: .teleportUppercut, first: .down, second: .right, button: 3, name: "Teleport uppercut")
		case .cyrax: .init(move: .bomb, first: .down, second: .left, button: 3, name: "Bomb")
		case .kitana: .init(move: .fanLift, first: .left, second: .right, button: 1, name: "Fan lift")
		case .smoke: .init(move: .smokeTeleport, first: .down, second: .right, button: 2, name: "Smoke teleport")
		case .liuKang: .init(move: .flyingKick, first: .left, second: .right, button: 3, name: "Flying kick")
		}
	}

	public var specialOne: MoveID { commandOne.move }
	public var specialTwo: MoveID { commandTwo.move }
	public var moves: String { "\(commandOne.hint)\n\(commandTwo.hint)" }

	/// Overall effectiveness includes movement, recovery and ease of converting special hits.
	public var strength: String {
		switch self {
		case .scorpion, .sektor, .liuKang: "STRONG"
		case .jade, .kitana: "STANDARD"
		case .subZero, .cyrax, .smoke: "CHALLENGE"
		}
	}

	public var playstyle: String {
		switch self {
		case .scorpion: "Pull foes close. Cross them up with teleport."
		case .subZero: "Heavy hits and long freezes. Slow; follow up captures."
		case .jade: "Long staff reach and returning blades. Lighter hits."
		case .sektor: "Hard-hitting rockets and a teleport launcher."
		case .cyrax: "Heavy hits and timed traps. Slow; plan capture follow-ups."
		case .kitana: "Fast footwork, fans and lifts. Lower damage."
		case .smoke: "Delayed cloud traps and overhead ambushes. Risky recovery."
		case .liuKang: "Strong fast kicks and crouch-catching fireballs."
		}
	}

	public var walkSpeed: Int32 {
		switch self {
		case .scorpion: 9
		case .subZero, .sektor: 8
		case .jade, .liuKang: 10
		case .cyrax: 7
		case .kitana: 12
		case .smoke: 11
		}
	}

	public var dashSpeed: Int32 { walkSpeed * 2 + 7 }

	/// Base move definitions remain public; actual normal attacks depend on the fighter.
	public func data(for move: MoveID) -> MoveData {
		var result = move.data
		guard move != .none, !move.isSpecial else { return result }
		switch self {
		case .scorpion, .sektor: break
		case .subZero:
			result.damage = result.damage * 108 / 100
			result.startup += 1
		case .jade:
			result.damage = result.damage * 92 / 100
			if !move.isKick { result.reach += 75 }
		case .cyrax:
			result.damage = result.damage * 112 / 100
			result.startup += 1
			result.recovery += 2
		case .kitana:
			result.damage = result.damage * 88 / 100
			result.startup = max(1, result.startup - 1)
			result.recovery = max(1, result.recovery - 2)
		case .smoke:
			result.damage = result.damage * 92 / 100
			result.startup = max(1, result.startup - 1)
			result.recovery += 2
		case .liuKang:
			result.damage = result.damage * (move.isKick ? 115 : 105) / 100
			if move.isKick { result.startup = max(1, result.startup - 1); result.reach += 20 }
		}
		return result
	}
}
