import Testing
@testable import COR

struct InputTests {
	@Test func timestampedInputsBelongToTheirOwnTicks() {
		var buffer = InputBuffer()
		buffer.append(.left, time: 0.01)
		buffer.append(.right, time: 0.02)
		buffer.append([], time: 0.04)
		#expect(buffer.frame(until: 1.0 / 60).held == .left)
		#expect(buffer.frame(until: 2.0 / 60).held == .right)
		#expect(buffer.frame(until: 3.0 / 60).held.isEmpty)
	}

	@Test func tapIsDeliveredOnceAcrossCatchUpTicks() {
		var buffer = InputBuffer()
		buffer.append(.one, time: 0.01)
		buffer.append([], time: 0.012)
		let first = buffer.frame(until: 1.0 / 60)
		#expect(first.held.isEmpty)
		#expect(first.pressed == .one)
		#expect(first.count == 2)
		#expect(buffer.frame(until: 2.0 / 60).pressed.isEmpty)
		#expect(buffer.frame(until: 3.0 / 60).pressed.isEmpty)
	}

	@Test func pauseRequiresReleaseBeforeAcceptingHeldButtons() {
		var buffer = InputBuffer()
		buffer.append(.one, time: 0)
		buffer.reset()
		buffer.append(.one, time: 1)
		#expect(buffer.frame(until: 1).held.isEmpty)
		buffer.append([], time: 2)
		buffer.append(.two, time: 3)
		#expect(buffer.frame(until: 3).pressed == .two)
	}

	@Test func boundedQueuePreservesFinalState() {
		var buffer = InputBuffer()
		for i in 0 ..< 200 { buffer.append(i % 2 == 0 ? .one : [], time: Double(i)) }
		let frame = buffer.frame(until: 200)
		#expect(frame.held.isEmpty)
		#expect(frame.pressed.contains(.one))
		#expect(frame.count <= 16)
	}

	@Test func newConnectionDoesNotTreatJoinAsAttack() {
		var buffer = InputBuffer(holding: .three)
		buffer.append(.three, time: 0)
		#expect(buffer.frame(until: 1).pressed.isEmpty)
		buffer.append([], time: 2)
		buffer.append(.three, time: 3)
		#expect(buffer.frame(until: 3).pressed == .three)
	}
}
