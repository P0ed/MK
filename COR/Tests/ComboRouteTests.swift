import Testing
@testable import COR

private func comboDuel(_ character: Character, mirrored: Bool = false) -> Fight {
	var a = Fighter(character: character, side: mirrored ? 1 : 0)
	var b = Fighter(character: .scorpion, side: mirrored ? 0 : 1)
	a.x = mirrored ? 110 : -110
	b.x = -a.x
	return Fight(fighters: [a, b])
}

@discardableResult
private func comboTick(_ fight: inout Fight, _ input: Input = []) -> FrameEvents {
	fight.step([.init(held: input), .init()])
}

struct ComboRouteTests {
	@Test(arguments: Character.allCases, [false, true])
	func directionalLauncherConvertsIntoRosterStringAndSpecial(character: Character, mirrored: Bool) {
		var fight = comboDuel(character, mirrored: mirrored)
		let facing: Int32 = mirrored ? -1 : 1
		comboTick(&fight, [mirrored ? .right : .left, .one])
		// Buffer the string during launcher recovery, then enter its second hit.
		for _ in 0 ..< 100 {
			if fight.fighters[0].connected, fight.fighters[0].moveFrame >= fight.fighters[0].moveData.total - 6 { break }
			comboTick(&fight)
		}
		#expect(fight.fighters[0].move == .backPunch)
		for step in 0 ..< 3 { comboTick(&fight, character.stringOne.input(at: step, facing: facing)) }
		for _ in 0 ..< 100 {
			if fight.fighters[0].move == character.stringOne.finisher && fight.fighters[0].connected { break }
			comboTick(&fight)
		}
		let ender = character == .scorpion ? character.commandTwo : character.commandThree
		for step in 0 ..< 3 { comboTick(&fight, ender.input(at: step, facing: facing)) }
		for _ in 0 ..< 80 { comboTick(&fight) }
		#expect(fight.fighters[0].comboHits == 4, "\(character.name) follow-ups should connect")
		#expect((300 ... 400).contains(fight.fighters[0].comboDamage), "\(character.name) should have a 30–40% route")
		#expect(fight.fighters[1].health == Fighter.maxHealth - fight.fighters[0].comboDamage)
	}
}
