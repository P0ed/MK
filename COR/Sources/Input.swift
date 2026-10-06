public struct Input: OptionSet, Equatable, Sendable {
	public let rawValue: UInt16

	public init(rawValue: UInt16) { self.rawValue = rawValue }

	public static let left = Input(rawValue: 1 << 0)
	public static let right = Input(rawValue: 1 << 1)
	public static let down = Input(rawValue: 1 << 2)
	public static let up = Input(rawValue: 1 << 3)
	public static let one = Input(rawValue: 1 << 4)
	public static let two = Input(rawValue: 1 << 5)
	public static let three = Input(rawValue: 1 << 6)
	public static let four = Input(rawValue: 1 << 7)
	public static let block = Input(rawValue: 1 << 8)

	public static let directions: Input = [.left, .right, .down, .up]
	public static let attacks: Input = [.one, .two, .three, .four]

	public var horizontal: Int32 {
		(contains(.right) ? 1 : 0) - (contains(.left) ? 1 : 0)
	}

	public var vertical: Int32 {
		(contains(.up) ? 1 : 0) - (contains(.down) ? 1 : 0)
	}

	public var direction: Input {
		var result: Input = []
		if horizontal < 0 { result.insert(.left) }
		if horizontal > 0 { result.insert(.right) }
		if vertical < 0 { result.insert(.down) }
		if vertical > 0 { result.insert(.up) }
		return result
	}

	public static func attack(_ index: Int) -> Input {
		Input(rawValue: UInt16(1) << (4 + index))
	}
}

/// Ordered device states preserve a press and release between two game frames.
public struct InputFrame: Sendable {
	public var held: Input
	public var pressed: Input
	public private(set) var count = 0
	public private(set) var changes: InlineArray<16, Input> = .init(repeating: [])

	public init(held: Input = [], pressed: Input = []) {
		self.held = held
		self.pressed = pressed
	}

	public mutating func append(_ state: Input) {
		pressed.formUnion(state.subtracting(held))
		held = state
		if count < changes.count {
			changes[count] = state
			count += 1
		} else {
			changes[count - 1] = state
		}
	}
}

struct CommandSample: Sendable {
	var frame = -100
	var direction: Input = []
}

struct CommandHistory: Sendable {
	var samples: InlineArray<64, CommandSample> = .init(repeating: .init())
	var cursor = 0
	var count = 0
	var direction: Input = []
	var consumedFrame = -100

	mutating func record(_ input: Input, facing: Int32, frame: Int) -> Int32 {
		var relative = input.direction
		if facing < 0 {
			relative.remove([.left, .right])
			if input.horizontal < 0 { relative.insert(.right) }
			if input.horizontal > 0 { relative.insert(.left) }
		}
		guard relative != direction else { return 0 }
		direction = relative
		samples[cursor] = .init(frame: frame, direction: relative)
		cursor = (cursor + 1) % samples.count
		count = min(count + 1, samples.count)

		// A neutral release is required between two taps. Diagonals don't dash.
		guard relative == .right || relative == .left, count >= 3 else { return 0 }
		let neutral = samples[(cursor + samples.count - 2) % samples.count]
		let previous = samples[(cursor + samples.count - 3) % samples.count]
		guard neutral.direction.isEmpty, previous.direction == relative,
			frame - previous.frame <= 10 else { return 0 }
		return relative == .right ? facing : -facing
	}

	func matches(_ first: Input, _ second: Input, frame: Int) -> Bool {
		guard count >= 2 else { return false }
		var foundSecond = false
		for offset in 1 ... count {
			let sample = samples[(cursor + samples.count - offset) % samples.count]
			if frame - sample.frame > 20 || sample.frame <= consumedFrame { break }
			if sample.direction.isEmpty { continue }
			if !foundSecond {
				guard sample.direction.contains(second) else { return false }
				foundSecond = true
			} else if sample.direction.contains(first) {
				return true
			}
		}
		return false
	}
}

/// Rendering may run at a different rate; game time always advances in 1/60 s.
public struct FrameClock {
	public static let duration = 1.0 / 60.0
	public private(set) var remainder = 0.0

	public init() {}

	public mutating func advance(_ seconds: Double) -> Int {
		guard seconds.isFinite, seconds >= 0, seconds <= 0.25 else {
			reset()
			return 0
		}
		remainder += seconds
		let available = Int((remainder + 1e-9) / Self.duration)
		let steps = min(available, 4)
		remainder -= Double(available) * Self.duration
		remainder = max(0, remainder)
		return steps
	}

	public mutating func reset() { remainder = 0 }
}
