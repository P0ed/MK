import Testing
@testable import COR

private func safetyDuel(_ first: Character = .scorpion, distance: Int32 = 220) -> Fight {
	var a = Fighter(character: first, side: 0)
	var b = Fighter(character: .scorpion, side: 1)
	a.x = -distance / 2
	b.x = distance / 2
	return Fight(fighters: [a, b])
}

@discardableResult
private func safetyTick(_ fight: inout Fight, _ input: Input = []) -> FrameEvents {
	fight.step([.init(held: input), .init()])
}

private func safetyContact(_ events: FrameEvents, kind: EventKind, move: MoveID? = nil) -> Bool {
	for index in 0 ..< events.count where events[index].kind == kind && events[index].player == 0 {
		if move == nil || events[index].move == move { return true }
	}
	return false
}

struct ComboSafetyTests {
	@Test(arguments: Character.allCases)
	func whiffedSpecialCancelExpiresWithoutPreventingAFreshNeutralCommand(_ character: Character) {
		var fight = safetyDuel(character, distance: 1_800)
		safetyTick(&fight, .one)
		for _ in 0 ..< fight.fighters[0].moveData.startup { safetyTick(&fight) }
		var specialStarted = false
		for step in 0 ..< 3 {
			let events = safetyTick(&fight, character.commandThree.input(at: step, facing: 1))
			specialStarted = specialStarted || safetyContact(events, kind: .special)
		}
		// This outlasts both normal recovery and the enlarged special input buffer.
		for _ in 0 ..< 80 {
			specialStarted = safetyContact(safetyTick(&fight), kind: .special) || specialStarted
		}
		#expect(!specialStarted)
		#expect(fight.fighters[0].move == .none && fight.fighters[0].queueCount == 0)
		#expect(fight.fighters[1].health == Fighter.maxHealth)

		var freshSpecialStarted = false
		for step in 0 ..< 3 {
			let events = safetyTick(&fight, character.commandThree.input(at: step, facing: 1))
			freshSpecialStarted = freshSpecialStarted || safetyContact(events, kind: .special, move: character.specialThree)
		}
		#expect(freshSpecialStarted)
	}

	@Test func aSecondLauncherConnectsWithoutStartingAnotherFullLaunchArc() throws {
		var fight = safetyDuel(.sektor)
		safetyTick(&fight, [.left, .one])
		var firstLauncherHit = false
		for _ in 0 ..< 40 {
			if safetyContact(safetyTick(&fight), kind: .hit, move: .backPunch) {
				firstLauncherHit = true
				break
			}
		}
		try #require(firstLauncherHit && fight.fighters[1].launched)
		for step in 0 ..< 3 { safetyTick(&fight, Character.sektor.commandTwo.input(at: step, facing: 1)) }

		var secondLauncherHit = false
		for _ in 0 ..< 80 {
			let wasLaunched = fight.fighters[1].launched
			let events = safetyTick(&fight)
			if safetyContact(events, kind: .hit, move: .teleportUppercut) {
				secondLauncherHit = true
				#expect(wasLaunched && fight.fighters[1].launched)
				#expect(fight.fighters[0].comboHits == 2)
				#expect(fight.fighters[1].vy <= 20)
				#expect(fight.fighters[1].vy < Character.sektor.data(for: .teleportUppercut).launchSpeed)
				break
			}
		}
		#expect(secondLauncherHit)
	}

	@Test func aGroundedKnockdownCannotBeHitOrStartAFreshComboBeforeWakeup() throws {
		var fight = safetyDuel()
		let string: [Input] = [.one, [], .one, [], .two]
		for input in string { safetyTick(&fight, input) }
		let attack = Character.scorpion.data(for: .punch1)
		var readyWhileDummyIsDown = false
		for _ in 0 ..< 140 {
			if fight.fighters[0].move == .none, fight.fighters[1].pose == .down,
				fight.fighters[1].stun >= attack.startup + attack.active + 1 {
				readyWhileDummyIsDown = true
				break
			}
			safetyTick(&fight)
		}
		try #require(readyWhileDummyIsDown)
		let health = fight.fighters[1].health
		let chainHits = fight.fighters[1].chainHits
		#expect(chainHits == 3)
		safetyTick(&fight, .one)
		for _ in 0 ..< attack.startup + attack.active {
			#expect(fight.fighters[1].pose == .down)
			#expect(!safetyContact(safetyTick(&fight), kind: .hit))
		}
		#expect(fight.fighters[1].health == health)
		#expect(fight.fighters[0].comboHits == chainHits)

		for _ in 0 ..< 60 {
			if fight.fighters[0].move == .none && fight.fighters[1].stun == 0 { break }
			safetyTick(&fight)
		}
		safetyTick(&fight, .two)
		var freshHit = false
		for _ in 0 ..< 30 {
			if safetyContact(safetyTick(&fight), kind: .hit, move: .punch2) {
				freshHit = true
				break
			}
		}
		#expect(freshHit && fight.fighters[0].comboHits == 1)
	}

	@Test(arguments: [0, 1])
	func practiceSilencesAnAIWithAnInputSequenceAlreadyInProgress(_ player: Int) throws {
		var scored = safetyDuel(.sektor, distance: 900)
		var cpu = AI(seed: 17)
		var primed = false
		for _ in 0 ..< 120 {
			let current = cpu.input(scored, player: player)
			var inputs: InlineArray<2, InputFrame> = [.init(), .init()]
			inputs[player] = current
			_ = scored.step(inputs)
			var probe = cpu
			let next = probe.input(scored, player: player)
			if !current.held.isEmpty && !next.held.isEmpty {
				primed = true
				break
			}
		}
		try #require(primed)
		var practice = Fight(.sektor, .scorpion, practice: true)
		for _ in 0 ..< 120 {
			let input = cpu.input(practice, player: player)
			#expect(input.held.isEmpty && input.pressed.isEmpty && input.count == 0)
			var inputs: InlineArray<2, InputFrame> = [.init(), .init()]
			inputs[player] = input
			let events = practice.step(inputs)
			#expect(events.count == 0)
		}
		#expect(practice.fighters[0].x == -384 && practice.fighters[1].x == 384)
		#expect(practice.fighters[0].health == Fighter.maxHealth && practice.fighters[1].health == Fighter.maxHealth)
	}
}
