public enum Character: UInt8, CaseIterable, Sendable {
	case scorpion, subZero, jade, sektor

	public var name: String {
		switch self {
		case .scorpion: "SCORPION"
		case .subZero: "SUB-ZERO"
		case .jade: "JADE"
		case .sektor: "SEKTOR"
		}
	}

	public var specialOne: MoveID {
		switch self {
		case .scorpion: .spear
		case .subZero: .ice
		case .jade: .rang
		case .sektor: .rocket
		}
	}

	public var specialTwo: MoveID {
		switch self {
		case .scorpion: .teleport
		case .subZero: .slide
		case .jade: .shadowKick
		case .sektor: .teleportUppercut
		}
	}

	public var moves: String {
		switch self {
		case .scorpion: "Spear  B, F + 1\nTeleport  D, B + 3"
		case .subZero: "Ice  D, F + 1\nSlide  B, F + 4"
		case .jade: "Razor-rang  D, F + 1\nShadow kick  B, F + 4"
		case .sektor: "Rocket  B, F + 1\nTeleport uppercut  D, F + 4"
		}
	}
}

public enum HitLevel: Sendable { case high, mid, low, overhead }
public enum HitEffect: Sendable { case strike, knockdown, launch, pull, freeze }

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

	public var data: MoveData { moveTable[Int(rawValue)] }
	public var isSpecial: Bool { rawValue >= MoveID.spear.rawValue }
	public var isProjectile: Bool { self == .spear || self == .ice || self == .rang || self == .rocket }
	public var isTeleport: Bool { self == .teleport || self == .teleportUppercut }
	public var isKick: Bool {
		switch self {
		case .kick1, .kick2, .lowKick, .sweep, .air3, .air4, .string34, .slide, .shadowKick: true
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
private let moveTable: InlineArray<26, MoveData> = [
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
]

func special(character: Character, button: Int, history: borrowing CommandHistory, frame: Int) -> MoveID? {
	if button == 0 {
		let first: Input = character == .scorpion || character == .sektor ? .left : .down
		if history.matches(first, .right, frame: frame) { return character.specialOne }
	}
	if character == .scorpion, button == 2, history.matches(.down, .left, frame: frame) { return .teleport }
	if button == 3 {
		let first: Input = character == .sektor ? .down : .left
		if character != .scorpion, history.matches(first, .right, frame: frame) { return character.specialTwo }
	}
	return nil
}
