import Testing
@testable import COR

private func captureCommand(_ move: MoveID) -> (Character, SpecialCommand, Int) {
	switch move {
	case .spear: (.scorpion, Character.scorpion.commandOne, 80)
	case .ice: (.subZero, Character.subZero.commandOne, 92)
	case .iceBurst: (.subZero, Character.subZero.commandThree, 76)
	case .net: (.cyrax, Character.cyrax.commandOne, 104)
	default: preconditionFailure("Expected a capture move")
	}
}

private func captureDuel(_ character: Character) -> Fight {
	var attacker = Fighter(character: character, side: 0)
	var victim = Fighter(character: .sektor, side: 1)
	attacker.x = -110
	victim.x = 110
	return Fight(fighters: [attacker, victim])
}

struct CaptureDurationTests {
	@Test(arguments: [MoveID.spear, .ice, .iceBurst, .net])
	func capturesHoldForTwiceTheirPreviousDurationThenRelease(_ move: MoveID) throws {
		let (character, command, duration) = captureCommand(move)
		var fight = captureDuel(character)
		for step in 0 ..< 3 {
			_ = fight.step([.init(held: command.input(at: step, facing: 1)), .init()])
		}
		for _ in 0 ..< 80 {
			if fight.fighters[1].caughtBy == move { break }
			_ = fight.step([.init(), .init()])
		}
		try #require(fight.fighters[1].caughtBy == move)
		#expect(fight.fighters[1].stun == duration)
		let position = fight.fighters[1].x
		let health = fight.fighters[1].health
		for _ in 0 ..< duration + 4 {
			let remaining = fight.fighters[1].stun
			let stopped = fight.hitstop > 0
			#expect(fight.fighters[1].pose == .frozen && fight.fighters[1].caughtBy == move)
			_ = fight.step([.init(), .init(held: [.up, .right, .one])])
			#expect(fight.fighters[1].stun == remaining - (stopped ? 0 : 1))
			#expect(fight.fighters[1].x == position && !fight.fighters[1].airborne)
			#expect(fight.fighters[1].health == health)
		}
		#expect(fight.fighters[1].stun == 0)
		#expect(fight.fighters[1].pose == .idle && fight.fighters[1].caughtBy == .none)
	}

	@Test(arguments: [MoveID.spear, .ice, .iceBurst, .net])
	func extendedCapturesDoNotAllowAnotherCaptureInTheSameCombo(_ move: MoveID) {
		let (character, _, _) = captureCommand(move)
		var attacker = Fighter(character: character, side: 0)
		var victim = Fighter(character: .sektor, side: 1)
		attacker.x = -110
		victim.x = 110
		victim.pose = .hit
		victim.stun = 20
		victim.captured = true
		victim.chainHits = 1
		var projectile = Projectile()
		if move.isProjectile {
			projectile = Projectile(active: true, move: move, x: victim.x, y: 385, oldX: victim.x)
		} else {
			attacker.start(move)
			attacker.moveFrame = attacker.moveData.startup - 1
		}
		var fight = Fight(fighters: [attacker, victim], projectiles: [projectile, .init()])
		_ = fight.step([.init(), .init()])
		#expect(fight.fighters[1].chainHits == 2)
		#expect(fight.fighters[1].stun <= 12)
		#expect(fight.fighters[1].pose != .frozen && fight.fighters[1].caughtBy == .none)
	}
}
