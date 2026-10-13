import Testing
@testable import COR

private func rosterDuel(_ first: Character, _ second: Character = .scorpion, distance: Int32) -> Fight {
	var a = Fighter(character: first, side: 0)
	var b = Fighter(character: second, side: 1)
	a.x = -distance / 2
	b.x = distance / 2
	return Fight(fighters: [a, b])
}

@discardableResult
private func rosterTick(_ fight: inout Fight, _ first: Input = [], _ second: Input = []) -> FrameEvents {
	fight.step([.init(held: first), .init(held: second)])
}

private func perform(_ command: SpecialCommand, in fight: inout Fight) {
	for step in 0 ..< 3 { rosterTick(&fight, command.input(at: step, facing: 1)) }
}

private func ready(_ character: Character, move: MoveID, distance: Int32) -> Fight {
	var a = Fighter(character: character, side: 0)
	var b = Fighter(character: .scorpion, side: 1)
	a.x = -distance / 2
	b.x = distance / 2
	a.start(move)
	a.moveFrame = a.moveData.startup - 1
	return Fight(fighters: [a, b])
}

struct RosterTests {
	@Test func allSixteenCommandsMirrorAndUseTheirOwnMoves() {
		#expect(Character.allCases.count == 8)
		for character in Character.allCases {
			for command in [character.commandOne, character.commandTwo] {
				var fight = rosterDuel(character, character, distance: 1_800)
				for step in 0 ..< 3 {
					rosterTick(&fight, command.input(at: step, facing: 1), command.input(at: step, facing: -1))
				}
				#expect(fight.fighters[0].move == command.move)
				#expect(fight.fighters[1].move == command.move)
				#expect(command.hint.contains(String(command.button + 1)))
			}
		}
	}

	@Test func netImmobilizesWithoutPullingAndCannotRecapture() {
		var fight = rosterDuel(.cyrax, distance: 700)
		perform(Character.cyrax.commandOne, in: &fight)
		let targetX = fight.fighters[1].x
		for _ in 0 ..< 100 {
			rosterTick(&fight)
			if fight.fighters[1].caughtBy == .net { break }
		}
		#expect(fight.fighters[1].caughtBy == .net)
		#expect(fight.fighters[1].pose == .frozen)
		#expect(fight.fighters[1].x == targetX)
		#expect(fight.fighters[1].vx == 0 && fight.fighters[1].vy == 0)
		#expect(fight.fighters[1].stun == 104)
		var victim = fight.fighters[1]
		victim.caughtBy = .none
		let repeatedNet = Projectile(active: true, move: .net, x: victim.x, y: 385, oldX: victim.x)
		var repeated = Fight(fighters: [fight.fighters[0], victim], projectiles: [repeatedNet, .init()])
		rosterTick(&repeated)
		#expect(repeated.fighters[1].caughtBy == .none)
		#expect(repeated.fighters[1].stun <= 12)
	}

	@Test func bombLobsLandsAndOnlyHitsWhenItsFuseExpires() {
		var fight = ready(.cyrax, move: .bomb, distance: 650)
		rosterTick(&fight)
		#expect(fight.projectiles[0].y > 220)
		#expect(fight.projectiles[0].vy > 0)
		#expect(!fight.projectiles[0].detonating)
		for _ in 0 ..< 46 { rosterTick(&fight) }
		#expect(fight.projectiles[0].age == 47)
		#expect(fight.projectiles[0].y == 0)
		#expect(fight.fighters[1].health == Fighter.maxHealth)
		let events = rosterTick(&fight, [], .block)
		#expect(fight.projectiles[0].age == 48)
		#expect(fight.projectiles[0].detonating)
		#expect(fight.projectiles[0].active)
		#expect(fight.fighters[1].health == 875)
		#expect(fight.fighters[1].launched)
		#expect(events.count == 2 && events[0].kind == .detonate && events[1].move == .bomb && events[1].kind == .hit)
		for _ in 0 ..< 16 { rosterTick(&fight) }
		#expect(!fight.projectiles[0].active)
	}

	@Test func bombDetonationEventOccursOnceEvenWhenItMisses() {
		var fight = ready(.cyrax, move: .bomb, distance: 2_000)
		var detonations = 0
		for _ in 0 ..< 80 {
			let events = rosterTick(&fight)
			for index in 0 ..< events.count where events[index].kind == .detonate {
				detonations += 1
				#expect(events[index].move == .bomb)
			}
		}
		#expect(detonations == 1)
		#expect(fight.fighters[1].health == 1_000)
	}

	@Test func crouchingBlocksBombButEvadesFanAndFlyingKick() {
		for move in [MoveID.bomb, .fan, .flyingKick] {
			let character: Character = move == .bomb ? .cyrax : move == .fan ? .kitana : .liuKang
			var fight = ready(character, move: move, distance: move == .bomb ? 650 : 500)
			for _ in 0 ..< 100 { rosterTick(&fight, [], [.down, .block]) }
			#expect(fight.fighters[1].health == (move == .bomb ? 988 : 1_000))
		}
	}

	@Test func fanIsFasterWhileFireballHitsCrouchingFoes() {
		var fan = ready(.kitana, move: .fan, distance: 650)
		var fire = ready(.liuKang, move: .fireball, distance: 650)
		rosterTick(&fan, [], .down)
		rosterTick(&fire, [], .down)
		#expect(fan.projectiles[0].vx == 34)
		#expect(fire.projectiles[0].vx == 30)
		#expect(fan.projectiles[0].y > fire.projectiles[0].y)
		for _ in 0 ..< 70 { rosterTick(&fan, [], .down); rosterTick(&fire, [], .down) }
		#expect(fan.fighters[1].health == 1_000)
		#expect(fire.fighters[1].health == 930)
	}

	@Test func fanLiftLaunchesBeyondUppercutReach() {
		var lift = ready(.kitana, move: .fanLift, distance: 380)
		var uppercut = ready(.kitana, move: .uppercut, distance: 380)
		rosterTick(&lift)
		rosterTick(&uppercut)
		#expect(lift.fighters[1].launched && lift.fighters[1].vy == 78)
		#expect(lift.fighters[1].health == 960)
		#expect(uppercut.fighters[1].health == 1_000)
	}

	@Test func smokeCloudArmsAtRangeThenLaunchesAndLingers() {
		var fight = ready(.smoke, move: .smokeCloud, distance: 650)
		for _ in 0 ..< 9 { rosterTick(&fight) }
		#expect(fight.projectiles[0].age == 9)
		#expect(fight.projectiles[0].x == 325)
		#expect(fight.projectiles[0].vx == 0)
		#expect(fight.fighters[1].health == 1_000)
		rosterTick(&fight)
		#expect(fight.fighters[1].health == 940)
		#expect(fight.fighters[1].launched)
		#expect(fight.fighters[1].caughtBy == .none)
		#expect(fight.projectiles[0].active)
		for _ in 0 ..< 50 { rosterTick(&fight) }
		#expect(!fight.projectiles[0].active)
	}

	@Test func smokeTeleportAmbushesOverheadFromTheSameSide() {
		var fight = rosterDuel(.smoke, distance: 900)
		perform(Character.smoke.commandTwo, in: &fight)
		for _ in 0 ..< 12 { rosterTick(&fight, [], [.down, .block]) }
		#expect(fight.fighters[0].x < fight.fighters[1].x)
		#expect(fight.fighters[0].y > 0)
		#expect(fight.fighters[0].intangible)
		for _ in 0 ..< 8 { rosterTick(&fight, [], [.down, .block]) }
		#expect(fight.fighters[1].health == 920)
		#expect(!fight.fighters[1].falling)
		for _ in 0 ..< 12 { rosterTick(&fight, [], [.down, .block]) }
		#expect(fight.fighters[0].y == 0)
		#expect(fight.fighters[0].move == .smokeTeleport)
		#expect(fight.fighters[0].pose == .attack)
		for _ in 0 ..< 40 { rosterTick(&fight) }
		#expect(fight.fighters[0].move == .none)
	}

	@Test func flyingKickStartsAndTravelsFasterThanShadowKick() {
		#expect(MoveID.flyingKick.data.startup < MoveID.shadowKick.data.startup)
		var kick = ready(.liuKang, move: .flyingKick, distance: 650)
		let before = kick.fighters[0].x
		rosterTick(&kick)
		#expect(kick.fighters[0].x == before + 48)
		for _ in 0 ..< 20 { rosterTick(&kick) }
		#expect(kick.fighters[1].health == 890)
		#expect(kick.fighters[1].falling || kick.fighters[1].pose == .down)
	}

	@Test func characterStrengthChangesActualDamageTimingAndMovement() {
		var strong = rosterDuel(.cyrax, distance: 220)
		var light = rosterDuel(.kitana, distance: 220)
		rosterTick(&strong, .one)
		rosterTick(&light, .one)
		for _ in 0 ..< 5 { rosterTick(&strong); rosterTick(&light) }
		#expect(strong.fighters[1].health == 1_000)
		#expect(light.fighters[1].health == 956)
		for _ in 0 ..< 10 { rosterTick(&strong); rosterTick(&light) }
		#expect(strong.fighters[1].health == 944)
		#expect(strong.fighters[0].moveData.recovery > light.fighters[0].moveData.recovery)
		var slow = rosterDuel(.cyrax, distance: 1_000)
		var fast = rosterDuel(.kitana, distance: 1_000)
		rosterTick(&slow, .right)
		rosterTick(&fast, .right)
		#expect(slow.fighters[0].x == -493)
		#expect(fast.fighters[0].x == -488)
		#expect(Character.liuKang.data(for: .kick1).damage > MoveID.kick1.data.damage)
		#expect(Character.jade.data(for: .punch1).reach > MoveID.punch1.data.reach)
	}

	@Test func allNewMatchupsCompleteWithOrdinaryCPUInputs() {
		let characters: [Character] = [.cyrax, .kitana, .smoke, .liuKang]
		for first in characters {
			for second in characters {
				var fight = Fight(first, second)
				var a = AI(seed: 41)
				var b = AI(seed: 73)
				for _ in 0 ..< 36_000 {
					let firstInput = a.input(fight, player: 0)
					let secondInput = b.input(fight, player: 1)
					_ = fight.step([firstInput, secondInput])
					if fight.phase == .matchEnd { break }
				}
				#expect(fight.phase == .matchEnd, "\(first.name) versus \(second.name)")
				#expect(fight.round <= 3)
			}
		}
	}

	@Test func cpuExecutesBothCharacterSpecificCommands() {
		for character in Character.allCases {
			var fight = Fight(character, .sektor)
			var first = AI(seed: 41)
			var second = AI(seed: 73)
			var usedFirst = false
			var usedSecond = false
			for _ in 0 ..< 18_000 {
				if fight.phase == .matchEnd { fight = Fight(character, .sektor) }
				let a = first.input(fight, player: 0)
				let b = second.input(fight, player: 1)
				let events = fight.step([a, b])
				for index in 0 ..< events.count where events[index].kind == .special && events[index].player == 0 {
					usedFirst = usedFirst || events[index].move == character.specialOne
					usedSecond = usedSecond || events[index].move == character.specialTwo
				}
				if usedFirst && usedSecond { break }
			}
			#expect(usedFirst && usedSecond, "CPU must use both \(character.name) specials")
		}
	}
}
