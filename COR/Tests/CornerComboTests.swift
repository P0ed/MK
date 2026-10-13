import Testing
@testable import COR

private enum Pressure: CaseIterable {
	case jab, crouchingJab, string11, string21, uniqueStarter
}

struct CornerComboTests {
	@Test(arguments: Character.allCases, Pressure.allCases)
	fileprivate func groundPressureLeavesAChanceToBlock(character: Character, pressure: Pressure) {
		var attacker = Fighter(character: character, side: 0)
		var defender = Fighter(character: .scorpion, side: 1)
		attacker.x = Fight.edge - 200
		defender.x = Fight.edge
		var fight = Fight(fighters: [attacker, defender], practice: true)
		var hit = false
		var blocked = false
		var followUpFrame = -1
		for _ in 0 ..< 360 {
			var input: Input = pressure == .crouchingJab ? .down : []
			if fight.fighters[0].move == .none {
				switch pressure {
				case .jab, .crouchingJab, .string11: input.insert(.one)
				case .string21: input.insert(.two)
				case .uniqueStarter: input = character.stringOne.input(at: 0, facing: 1)
				}
				if pressure == .string11 || pressure == .string21 { followUpFrame = fight.frame + 3 }
			} else if fight.frame == followUpFrame {
				input.insert(.one)
			}
			let events = fight.step([.init(held: input), .init(held: hit ? .block : [])])
			for i in 0 ..< events.count {
				if events[i].kind == .hit { hit = true }
				if events[i].kind == .block { blocked = true }
			}
			if blocked { break }
		}
		#expect(hit)
		#expect(blocked, "\(character.name) \(pressure) must not loop forever against a cornered defender")
	}
}
