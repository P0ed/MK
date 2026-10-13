import Testing
@testable import COR

private func expandedDuel(_ first: Character, _ second: Character = .scorpion, distance: Int32 = 220) -> Fight {
	var a = Fighter(character: first, side: 0)
	var b = Fighter(character: second, side: 1)
	a.x = -distance / 2
	b.x = distance / 2
	return Fight(fighters: [a, b])
}

@discardableResult
private func expandedTick(_ fight: inout Fight, _ a: Input = [], _ b: Input = []) -> FrameEvents {
	fight.step([.init(held: a), .init(held: b)])
}

struct ExpandedMovesTests {
	@Test func everyFighterHasADistinctStringAndThirdSpecial() {
		var starters: Set<UInt8> = []
		var finishers: Set<UInt8> = []
		var specials: Set<UInt8> = []
		for character in Character.allCases {
			let string = character.stringOne
			#expect(starters.insert(string.starter.rawValue).inserted)
			#expect(finishers.insert(string.finisher.rawValue).inserted)
			#expect(specials.insert(character.specialThree.rawValue).inserted)
			#expect(string.starter.continuation(string.secondButton) == string.finisher)
			#expect(string.finisher.data.effect == .launch)
			#expect(!string.starter.isSpecial && !string.finisher.isSpecial)
			#expect(character.specialThree.isSpecial && !character.specialThree.isProjectile)
			#expect(character.specialThree != character.specialOne && character.specialThree != character.specialTwo)
			#expect(character.moves.contains(character.commandThree.hint))
		}
		#expect(Character.sektor.stringOne.hint.contains("F + 4, 4"))
	}

	@Test func directionalStringsMirrorAndBufferTheirSecondHits() {
		for character in Character.allCases {
			let command = character.stringOne
			var fight = expandedDuel(character, character, distance: 1_800)
			expandedTick(&fight, command.input(at: 0, facing: 1), command.input(at: 0, facing: -1))
			#expect(fight.fighters[0].move == command.starter)
			#expect(fight.fighters[1].move == command.starter)
			expandedTick(&fight, command.input(at: 1, facing: 1), command.input(at: 1, facing: -1))
			expandedTick(&fight, command.input(at: 2, facing: 1), command.input(at: 2, facing: -1))
			for _ in 0 ..< 15 { expandedTick(&fight) }
			#expect(fight.fighters[0].move == command.finisher, "\(character.name)")
			#expect(fight.fighters[1].move == command.finisher, "\(character.name)")
		}
	}

	@Test func stringsEnterInOneDeviceFrameAndConnectAtCloseRange() {
		for character in Character.allCases {
			var fight = expandedDuel(character)
			var frame = InputFrame()
			for step in 0 ..< 4 { frame.append(character.stringOne.input(at: step, facing: 1)) }
			_ = fight.step([frame, .init()])
			#expect(fight.fighters[0].move == character.stringOne.starter)
			#expect(fight.fighters[0].queueCount == 1)
			for _ in 0 ..< 45 { expandedTick(&fight) }
			#expect(fight.fighters[0].comboHits == 2, "\(character.name)")
			#expect(fight.fighters[1].health < 850, "\(character.name)")
			#expect(fight.fighters[1].launched, "\(character.name)")
		}
	}

	@Test func backPunchIsAStandingLauncherInEitherDirection() {
		for character in Character.allCases {
			var fight = expandedDuel(character, character, distance: 1_800)
			expandedTick(&fight, [.left, .one], [.right, .one])
			#expect(fight.fighters[0].move == .backPunch)
			#expect(fight.fighters[1].move == .backPunch)
			#expect(!fight.fighters[0].crouching && !fight.fighters[1].crouching)
			var contact = expandedDuel(character)
			expandedTick(&contact, [.left, .one])
			for _ in 0 ..< 14 { expandedTick(&contact) }
			#expect(contact.fighters[1].launched, "\(character.name)")
		}
	}

	@Test func thirdSpecialsMirrorAndTakePriorityOverDirectionalStarters() {
		for character in Character.allCases {
			var fight = expandedDuel(character, character, distance: 1_800)
			for step in 0 ..< 3 {
				expandedTick(&fight, character.commandThree.input(at: step, facing: 1), character.commandThree.input(at: step, facing: -1))
			}
			#expect(fight.fighters[0].move == character.specialThree, "\(character.name)")
			#expect(fight.fighters[1].move == character.specialThree, "\(character.name)")
		}
		var sektor = expandedDuel(.sektor, distance: 1_800)
		for step in 0 ..< 3 { expandedTick(&sektor, Character.sektor.commandTwo.input(at: step, facing: 1)) }
		#expect(sektor.fighters[0].move == .teleportUppercut)
	}

	@Test func thirdSpecialsConnectAndApplyTheirAdvertisedEffects() {
		for character in Character.allCases {
			var fight = expandedDuel(character)
			for step in 0 ..< 3 { expandedTick(&fight, character.commandThree.input(at: step, facing: 1)) }
			var hit: FrameEvent?
			for _ in 0 ..< 40 {
				let events = expandedTick(&fight)
				for index in 0 ..< events.count where events[index].kind == .hit && events[index].player == 0 { hit = events[index] }
				if hit != nil { break }
			}
			#expect(hit?.move == character.specialThree, "\(character.name)")
			#expect(hit?.damage == character.specialThree.data.damage, "\(character.name)")
			switch character.specialThree.data.effect {
			case .freeze:
				#expect(fight.fighters[1].pose == .frozen && fight.fighters[1].caughtBy == .iceBurst)
			case .launch:
				#expect(fight.fighters[1].launched)
			case .knockdown:
				#expect(fight.fighters[1].falling)
			default: break
			}
		}
	}

	@Test func bufferedSpecialNeverAppearsAfterAWhiffedStarterRecovers() {
		var fight = expandedDuel(.sektor, distance: 1_800)
		expandedTick(&fight, .one)
		for _ in 0 ..< 6 { expandedTick(&fight) }
		for step in 0 ..< 3 { expandedTick(&fight, Character.sektor.commandThree.input(at: step, facing: 1)) }
		var specials = 0
		for _ in 0 ..< 45 {
			let events = expandedTick(&fight)
			for index in 0 ..< events.count where events[index].kind == .special { specials += 1 }
		}
		#expect(specials == 0)
		#expect(fight.fighters[0].move == .none)
	}

	@Test func cpuUsesNewSpecialsAndUniqueStringsThroughOrdinaryInputs() {
		for character in Character.allCases {
			var fight = Fight(character, .sektor)
			var a = AI(seed: 41)
			var b = AI(seed: 73)
			var special = false
			var string = false
			for _ in 0 ..< 18_000 {
				if fight.phase == .matchEnd { fight = Fight(character, .sektor) }
				let inputs: InlineArray<2, InputFrame> = [a.input(fight, player: 0), b.input(fight, player: 1)]
				let events = fight.step(inputs)
				for index in 0 ..< events.count where events[index].player == 0 {
					special = special || (events[index].kind == .special && events[index].move == character.specialThree)
					string = string || (events[index].kind == .attack && events[index].move == character.stringOne.finisher)
				}
				if special && string { break }
			}
			#expect(special && string, "\(character.name)")
		}
	}
}
