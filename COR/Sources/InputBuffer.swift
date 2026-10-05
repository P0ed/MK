private struct InputChange: Sendable {
	var time = 0.0
	var held: Input = []
}

/// Device-independent, bounded input queue. Events belong to a tick deadline.
public struct InputBuffer: Sendable {
	private var changes: InlineArray<64, InputChange> = .init(repeating: .init())
	private var head = 0
	private var count = 0
	private var held: Input = []
	private var physical: Input
	private var suppressed: Bool

	public init(holding: Input = []) {
		physical = holding
		suppressed = !holding.isEmpty
	}

	public mutating func append(_ state: Input, time: Double) {
		physical = state
		if suppressed {
			if state.isEmpty { suppressed = false }
			return
		}
		if count == changes.count { head = (head + 1) % changes.count; count -= 1 }
		changes[(head + count) % changes.count] = .init(time: time, held: state)
		count += 1
	}

	public mutating func frame(until time: Double) -> InputFrame {
		var frame = InputFrame(held: held)
		while count > 0, changes[head].time <= time {
			frame.append(changes[head].held)
			head = (head + 1) % changes.count
			count -= 1
		}
		held = frame.held
		return frame
	}

	public mutating func reset() {
		head = 0
		count = 0
		held = []
		suppressed = !physical.isEmpty
	}
}
