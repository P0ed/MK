import Testing
@testable import COR

private func uppercutDuel() -> Fight {
	var attacker = Fighter(character: .sektor, side: 0)
	var victim = Fighter(character: .scorpion, side: 1)
	attacker.x = -110
	victim.x = 110
	return Fight(fighters: [attacker, victim])
}

@discardableResult
private func uppercutTick(_ fight: inout Fight, _ input: Input = []) -> FrameEvents {
	fight.step([.init(held: input), .init()])
}

private func enterUppercut(_ move: MoveID, into fight: inout Fight) {
	if move == .uppercut { uppercutTick(&fight, [.down, .two]) }
	else {
		for step in 0 ..< 3 { uppercutTick(&fight, Character.sektor.commandTwo.input(at: step, facing: 1)) }
	}
}

struct UppercutHeightTests {
	@Test(arguments: [MoveID.uppercut, .teleportUppercut])
	func uppercutsLaunchIntoALowerArcAndStillKnockDown(_ move: MoveID) {
		var fight = uppercutDuel()
		enterUppercut(move, into: &fight)
		var peak: Int32 = 0
		var launched = false
		var knockedDown = false
		for _ in 0 ..< 140 {
			uppercutTick(&fight)
			peak = max(peak, fight.fighters[1].y)
			launched = launched || fight.fighters[1].launched
			knockedDown = knockedDown || fight.fighters[1].pose == .down
		}
		#expect(launched && knockedDown)
		#expect((300 ... 450).contains(peak))
		#expect(!fight.fighters[1].airborne)
	}

	@Test(arguments: [MoveID.uppercut, .teleportUppercut])
	func lowerUppercutsStillConnectIntoABufferedString(_ move: MoveID) {
		var fight = uppercutDuel()
		enterUppercut(move, into: &fight)
		for _ in 0 ..< 80 {
			if fight.fighters[0].connected, fight.fighters[0].moveFrame >= fight.fighters[0].moveData.total - 3 { break }
			uppercutTick(&fight)
		}
		for input: Input in [.one, [], .one, [], .two] { uppercutTick(&fight, input) }
		for _ in 0 ..< 80 { uppercutTick(&fight) }
		#expect(fight.fighters[0].comboHits == 4)
		#expect(fight.fighters[1].health == Fighter.maxHealth - fight.fighters[0].comboDamage)
	}
}
