import Testing
@testable import COR

private func dashDuel(facing: Int32 = 1) -> Fight {
	var a = Fighter(character: .scorpion, side: facing > 0 ? 0 : 1)
	var b = Fighter(character: .sektor, side: facing > 0 ? 1 : 0)
	a.x = -600 * facing
	b.x = 600 * facing
	return Fight(fighters: [a, b])
}

@discardableResult
private func dashTick(_ fight: inout Fight, _ input: Input = []) -> FrameEvents {
	fight.step([.init(held: input), .init()])
}

struct DashInputTests {
	@Test(arguments: [Int32(1), Int32(-1)])
	func slowForwardAndBackDoubleTapsDashInEitherFacing(_ facing: Int32) {
		for forward in [true, false] {
			var fight = dashDuel(facing: facing)
			let direction = forward ? facing : -facing
			let input: Input = direction < 0 ? .left : .right
			dashTick(&fight, input)
			for _ in 0 ..< 19 { dashTick(&fight) }
			dashTick(&fight, input)
			#expect(fight.fighters[0].pose == .dash)
			#expect(fight.fighters[0].dashDirection == direction)
			#expect(fight.fighters[0].dashForward == forward)
			#expect(fight.fighters[0].vx == direction * Character.scorpion.dashSpeed)

			// Continuing to hold the second tap returns to walking after the dash.
			for _ in 0 ..< 20 { dashTick(&fight, input) }
			#expect(fight.fighters[0].pose == .walk && fight.fighters[0].dashFrames == 0)
			#expect(fight.fighters[0].vx == direction * Character.scorpion.walkSpeed)
		}
	}

	@Test(arguments: [11, 19, 20, 21, 30])
	func doubleTapWindowIncludesTwentyFramesAndRejectsOlderTaps(_ gap: Int) {
		for facing in [Int32(1), Int32(-1)] {
			for input in [Input.left, Input.right] {
				var history = CommandHistory()
				#expect(history.record(input, facing: facing, frame: 1) == 0)
				#expect(history.record([], facing: facing, frame: 2) == 0)
				let dash = history.record(input, facing: facing, frame: gap + 1)
				#expect(dash == (gap <= 20 ? input.horizontal : 0))
			}
		}
	}

	@Test(arguments: [Int32(1), Int32(-1)])
	func aSingleHeldDirectionKeepsWalkingWithoutRepeatingADash(_ facing: Int32) {
		for input in [Input.left, Input.right] {
			var fight = dashDuel(facing: facing)
			for _ in 0 ..< 80 {
				dashTick(&fight, input)
				#expect(fight.fighters[0].pose == .walk && fight.fighters[0].dashFrames == 0)
				#expect(fight.fighters[0].vx == input.horizontal * Character.scorpion.walkSpeed)
			}
		}
	}

	@Test func alternatingAndOpposedDirectionsCannotImitateAReleasedDoubleTap() {
		let sequences: [[Input]] = [
			[.left, .right, .left],
			[.left, [], .right, [], .left],
			[.left, [.left, .right], .left],
			[.right, [.left, .right], .right]
		]
		for sequence in sequences {
			var history = CommandHistory()
			for (index, input) in sequence.enumerated() {
				#expect(history.record(input, facing: 1, frame: index + 1) == 0)
			}
		}
		// Releasing an opposing key must not make a long-held direction a new tap.
		var held = CommandHistory()
		#expect(held.record(.left, facing: 1, frame: 1) == 0)
		#expect(held.record([.left, .right], facing: 1, frame: 100) == 0)
		#expect(held.record(.left, facing: 1, frame: 101) == 0)
		#expect(held.record([], facing: 1, frame: 102) == 0)
		#expect(held.record(.left, facing: 1, frame: 103) == 0)
	}

	@Test func diagonalsJumpsAndBlocksDoNotPrimeOrCompleteADash() {
		let disruptive: [Input] = [[.left, .down], [.left, .up], .down, .up, .block, [.left, .block], [.up, .down]]
		for input in disruptive {
			var history = CommandHistory()
			#expect(history.record(.left, facing: 1, frame: 1) == 0)
			#expect(history.record([], facing: 1, frame: 2) == 0)
			#expect(history.record(input, facing: 1, frame: 3) == 0)
			#expect(history.record([], facing: 1, frame: 4) == 0)
			#expect(history.record(.left, facing: 1, frame: 5) == 0)
		}
		var fight = dashDuel()
		dashTick(&fight, .left)
		dashTick(&fight)
		dashTick(&fight, [.left, .block])
		#expect(fight.fighters[0].pose == .guard && fight.fighters[0].dashFrames == 0)
		dashTick(&fight, .left)
		#expect(fight.fighters[0].pose == .walk && fight.fighters[0].dashFrames == 0)
	}

	@Test(arguments: [Input.left, Input.right])
	func twoCompleteTapsBetweenSimulationFramesStillDash(_ direction: Input) {
		var fight = dashDuel()
		var input = InputFrame()
		let states: [Input] = [direction, [], direction, []]
		for state in states { input.append(state) }
		_ = fight.step([input, .init()])
		#expect(fight.fighters[0].pose == .dash)
		#expect(fight.fighters[0].dashDirection == direction.horizontal)
	}

	@Test func aSameFrameGestureEndingInOpposedDirectionsCannotDash() {
		let conflicts: [Input] = [[.left, .right], [.up, .down]]
		for conflict in conflicts {
			var fight = dashDuel()
			var input = InputFrame()
			let states: [Input] = [.left, [], .left, conflict]
			for state in states { input.append(state) }
			_ = fight.step([input, .init()])
			#expect(fight.fighters[0].pose == .idle)
			#expect(fight.fighters[0].dashFrames == 0 && fight.fighters[0].vx == 0)
		}
	}
}
