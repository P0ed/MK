public enum HitLevel: Sendable { case high, mid, low, overhead }
public enum HitEffect: Sendable { case strike, knockdown, launch, pull, freeze, bind }

public struct MoveData: Sendable {
	public var startup: Int
	public var active: Int
	public var recovery: Int
	public var damage: Int
	public var reach: Int32
	public var level: HitLevel
	public var effect: HitEffect = .strike
	public var hitstun = 15
	public var blockstun = 8
	public var total: Int { startup + active + recovery }
	public var cancelStart: Int { startup }
	public var cancelEnd: Int { startup + active + 5 }
	public var linkFrame: Int { startup + active + 1 }
}

public enum MoveID: UInt8, CaseIterable, Sendable {
	case none
	case punch1, punch2, kick1, kick2
	case crouch1, uppercut, lowKick, sweep
	case air1, air2, air3, air4
	case string11, string112, string21, string212, string34
	case spear, teleport, ice, slide, rang, shadowKick, rocket, teleportUppercut
	case net, bomb, fan, fanLift, smokeCloud, smokeTeleport, fireball, flyingKick

	public var data: MoveData { moveTable[Int(rawValue)] }
	public var isSpecial: Bool { rawValue >= MoveID.spear.rawValue }
	public var isProjectile: Bool {
		switch self {
		case .spear, .ice, .rang, .rocket, .net, .bomb, .fan, .smokeCloud, .fireball: true
		default: false
		}
	}
	public var isTeleport: Bool { self == .teleport || self == .teleportUppercut || self == .smokeTeleport }
	public var isKick: Bool {
		switch self {
		case .kick1, .kick2, .lowKick, .sweep, .air3, .air4, .string34, .slide, .shadowKick, .flyingKick: true
		default: false
		}
	}

	func continuation(_ button: Int) -> MoveID? {
		switch (self, button) {
		case (.punch1, 0): .string11
		case (.string11, 1): .string112
		case (.punch2, 0): .string21
		case (.string21, 1): .string212
		case (.kick1, 3): .string34
		default: nil
		}
	}
}

/// All timings are simulation frames. An attack begins at elapsed frame zero.
private let moveTable: InlineArray<34, MoveData> = [
	.init(startup: 0, active: 0, recovery: 0, damage: 0, reach: 0, level: .mid),
	.init(startup: 6, active: 2, recovery: 12, damage: 50, reach: 210, level: .high),
	.init(startup: 9, active: 3, recovery: 16, damage: 70, reach: 235, level: .mid),
	.init(startup: 8, active: 3, recovery: 15, damage: 65, reach: 280, level: .mid),
	.init(startup: 12, active: 3, recovery: 20, damage: 90, reach: 310, level: .overhead),
	.init(startup: 6, active: 2, recovery: 13, damage: 35, reach: 190, level: .mid),
	.init(startup: 10, active: 3, recovery: 24, damage: 110, reach: 220, level: .mid, effect: .launch, hitstun: 26),
	.init(startup: 8, active: 3, recovery: 15, damage: 45, reach: 250, level: .low),
	.init(startup: 14, active: 3, recovery: 24, damage: 75, reach: 300, level: .low, effect: .knockdown),
	.init(startup: 6, active: 3, recovery: 12, damage: 45, reach: 210, level: .overhead),
	.init(startup: 8, active: 3, recovery: 14, damage: 60, reach: 240, level: .overhead),
	.init(startup: 8, active: 4, recovery: 16, damage: 65, reach: 285, level: .overhead),
	.init(startup: 10, active: 4, recovery: 18, damage: 80, reach: 315, level: .overhead),
	.init(startup: 5, active: 2, recovery: 10, damage: 45, reach: 230, level: .mid),
	.init(startup: 8, active: 3, recovery: 17, damage: 80, reach: 280, level: .mid, effect: .knockdown),
	.init(startup: 5, active: 2, recovery: 10, damage: 45, reach: 230, level: .mid),
	.init(startup: 9, active: 3, recovery: 22, damage: 85, reach: 250, level: .mid, effect: .launch, hitstun: 26),
	.init(startup: 9, active: 3, recovery: 18, damage: 70, reach: 310, level: .low, effect: .knockdown),
	.init(startup: 16, active: 1, recovery: 24, damage: 55, reach: 0, level: .high, effect: .pull, hitstun: 40),
	.init(startup: 14, active: 3, recovery: 23, damage: 90, reach: 255, level: .mid, effect: .knockdown),
	.init(startup: 18, active: 1, recovery: 24, damage: 20, reach: 0, level: .high, effect: .freeze, hitstun: 46),
	.init(startup: 10, active: 10, recovery: 24, damage: 85, reach: 235, level: .low, effect: .knockdown),
	.init(startup: 14, active: 1, recovery: 20, damage: 55, reach: 0, level: .high),
	.init(startup: 11, active: 8, recovery: 23, damage: 90, reach: 280, level: .mid, effect: .knockdown),
	.init(startup: 17, active: 1, recovery: 24, damage: 90, reach: 0, level: .high, hitstun: 20),
	.init(startup: 17, active: 3, recovery: 26, damage: 100, reach: 250, level: .mid, effect: .launch, hitstun: 26),
	.init(startup: 19, active: 1, recovery: 26, damage: 35, reach: 0, level: .high, effect: .bind, hitstun: 52),
	.init(startup: 18, active: 1, recovery: 24, damage: 125, reach: 0, level: .low, effect: .launch, hitstun: 28),
	.init(startup: 11, active: 1, recovery: 17, damage: 48, reach: 0, level: .high, hitstun: 18),
	.init(startup: 12, active: 5, recovery: 28, damage: 40, reach: 340, level: .mid, effect: .launch, hitstun: 30),
	.init(startup: 21, active: 1, recovery: 30, damage: 60, reach: 0, level: .mid, effect: .launch, hitstun: 28),
	.init(startup: 16, active: 4, recovery: 30, damage: 80, reach: 250, level: .overhead, hitstun: 20),
	.init(startup: 12, active: 1, recovery: 20, damage: 70, reach: 0, level: .mid, hitstun: 18),
	.init(startup: 7, active: 12, recovery: 25, damage: 110, reach: 300, level: .high, effect: .knockdown),
]

func special(character: Character, button: Int, history: borrowing CommandHistory, frame: Int) -> MoveID? {
	let first = character.commandOne
	if button == first.button, history.matches(first.first, first.second, frame: frame) { return first.move }
	let second = character.commandTwo
	if button == second.button, history.matches(second.first, second.second, frame: frame) { return second.move }
	return nil
}
