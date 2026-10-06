import Testing
import Foundation
@testable import COR

private func duel(_ first: Character = .scorpion, _ second: Character = .sektor, distance: Int32 = 220) -> Fight {
	var a = Fighter(character: first, side: 0)
	var b = Fighter(character: second, side: 1)
	a.x = -distance / 2
	b.x = distance / 2
	return Fight(fighters: [a, b])
}

@discardableResult
private func tick(_ fight: inout Fight, _ a: Input = [], _ b: Input = []) -> FrameEvents {
	fight.step([.init(held: a), .init(held: b)])
}

private func advance(_ fight: inout Fight, _ count: Int, _ a: Input = [], _ b: Input = []) {
	for _ in 0 ..< count { tick(&fight, a, b) }
}

struct CombatTests {
	@Test func startupActiveAndRecovery() {
		var fight = duel()
		tick(&fight, .one)
		#expect(fight.fighters[0].moveFrame == 0)
		advance(&fight, 5)
		#expect(fight.fighters[1].health == Fighter.maxHealth)
		let events = tick(&fight)
		#expect(fight.fighters[1].health == 950)
		#expect(events.count == 1)
		advance(&fight, 4)
		#expect(fight.fighters[0].moveFrame == 6)
		advance(&fight, 14)
		#expect(fight.fighters[0].move == .none)
		#expect(fight.fighters[1].health == 950)
	}

	@Test func heldAttackDoesNotRepeat() {
		var fight = duel()
		advance(&fight, 120, .one)
		#expect(fight.fighters[1].health == 950)
	}

	@Test func briefTapSurvivesBetweenFrames() {
		var fight = duel()
		var input = InputFrame()
		input.append(.one)
		input.append([])
		_ = fight.step([input, .init()])
		#expect(fight.fighters[0].move == .punch1)
		advance(&fight, 6)
		#expect(fight.fighters[1].health == 950)
	}

	@Test func bufferedStringAndLauncher() {
		var fight = duel()
		tick(&fight, .two)
		tick(&fight)
		tick(&fight, .one)
		tick(&fight)
		tick(&fight, .two)
		advance(&fight, 45)
		#expect(fight.fighters[0].comboHits == 3)
		#expect(fight.fighters[1].health < 850)
		#expect(fight.fighters[1].airborne || fight.fighters[1].falling)
		#expect(fight.fighters[1].launched)
	}

	@Test func invalidStringDoesNotBecomeAutomaticCombo() {
		var fight = duel()
		tick(&fight, .one)
		tick(&fight)
		tick(&fight, .four)
		advance(&fight, 50)
		#expect(fight.fighters[0].comboHits == 1)
		#expect(fight.fighters[1].health == 950)
	}

	@Test func guardLevelsAndCrouching() {
		var high = duel()
		advance(&high, 15, .one, .down)
		#expect(high.fighters[1].health == 1_000)
		var standing = duel()
		advance(&standing, 15, .one, .block)
		#expect(standing.fighters[1].health == 995)
		var low = duel()
		advance(&low, 20, [.down, .three], .block)
		#expect(low.fighters[1].health == 955)
		var lowGuard = duel()
		advance(&lowGuard, 20, [.down, .three], [.down, .block])
		#expect(lowGuard.fighters[1].health == 996)
		var overhead = duel()
		advance(&overhead, 20, .four, [.down, .block])
		#expect(overhead.fighters[1].health == 910)
	}

	@Test func blockReleaseAllowsMovement() {
		var fight = duel(distance: 700)
		tick(&fight, .block)
		let x = fight.fighters[0].x
		tick(&fight, .right)
		#expect(fight.fighters[0].x == x + 9)
		#expect(fight.fighters[0].pose == .walk)
	}

	@Test func simultaneousHitsTrade() {
		var fight = duel()
		advance(&fight, 7, .one, .one)
		#expect(fight.fighters[0].health == 950)
		#expect(fight.fighters[1].health == 950)
	}

	@Test func mirroredSpecialCommandsAndConsumption() {
		var fight = duel(.sektor, .sektor, distance: 900)
		tick(&fight, .left, .right)
		tick(&fight, .right, .left)
		tick(&fight, [.right, .one], [.left, .one])
		#expect(fight.fighters[0].move == .rocket)
		#expect(fight.fighters[1].move == .rocket)
		advance(&fight, 18)
		#expect(fight.projectiles[0].active)
		#expect(fight.projectiles[1].active)
		#expect(fight.projectiles[0].vx > 0)
		#expect(fight.projectiles[1].vx < 0)
	}

	@Test func expiredMotionDoesNotTriggerSpecial() {
		var fight = duel(.subZero, distance: 900)
		tick(&fight, .down)
		tick(&fight, .right)
		advance(&fight, 21)
		tick(&fight, .one)
		#expect(fight.fighters[0].move == .punch1)
	}

	@Test func specialCancelRequiresContact() {
		var hit = duel(.sektor)
		tick(&hit, .one)
		advance(&hit, 6)
		tick(&hit, .left)
		tick(&hit, .right)
		tick(&hit, [.right, .one])
		advance(&hit, 2)
		#expect(hit.fighters[0].move == .rocket)
		var miss = duel(.sektor, distance: 900)
		tick(&miss, .one)
		advance(&miss, 6)
		tick(&miss, .left)
		tick(&miss, .right)
		tick(&miss, [.right, .one])
		advance(&miss, 2)
		#expect(miss.fighters[0].move == .punch1)
	}

	@Test func doubleTapDashAndOppositeDirections() {
		var fight = duel(distance: 900)
		tick(&fight, .right)
		tick(&fight)
		tick(&fight, .right)
		#expect(fight.fighters[0].pose == .dash)
		let x = fight.fighters[0].x
		tick(&fight, .block)
		#expect(fight.fighters[0].dashFrames == 0)
		#expect(fight.fighters[0].x == x)
		#expect(Input([.left, .right]).horizontal == 0)
		#expect(Input([.up, .down]).vertical == 0)
	}

	@Test func jumpAndStageBoundaries() {
		var fight = duel(distance: 900)
		tick(&fight, [.up, .right])
		#expect(fight.fighters[0].airborne)
		advance(&fight, 60)
		#expect(!fight.fighters[0].airborne)
		advance(&fight, 500, .left, .right)
		#expect(fight.fighters[0].x == -Fight.edge)
		#expect(fight.fighters[1].x == Fight.edge)
	}

	@Test func razorRangHitsOncePerLeg() {
		var fight = duel(.jade, distance: 600)
		tick(&fight, .down)
		tick(&fight, .right)
		tick(&fight, [.right, .one])
		var hits = 0
		for _ in 0 ..< 120 {
			let events = tick(&fight)
			for i in 0 ..< events.count where events[i].kind == .hit { hits += 1 }
		}
		#expect(hits == 2)
		#expect(!fight.projectiles[0].active)
	}

	@Test func captureAndLauncherCannotRepeatInCombo() {
		var victim = Fighter(character: .subZero, side: 1)
		victim.x = 100
		victim.pose = .hit
		victim.stun = 20
		victim.captured = true
		victim.launched = true
		victim.chainHits = 2
		var attacker = Fighter(character: .scorpion, side: 0)
		attacker.x = -110
		attacker.start(.uppercut)
		attacker.moveFrame = 9
		var fight = Fight(fighters: [attacker, victim])
		tick(&fight)
		#expect(fight.fighters[1].vy == 0)
		#expect(fight.fighters[1].chainHits == 3)
		let ice = Projectile(active: true, move: .ice, x: 100, y: 385, vx: 0, oldX: 100)
		var repeated = Fight(fighters: [attacker, victim], projectiles: [ice, .init()])
		_ = tick(&repeated)
		#expect(repeated.fighters[1].pose != .frozen)
		#expect(repeated.fighters[1].caughtBy == .none)
	}

	@Test func spearPullsAndIceFreezes() {
		for character in [Character.scorpion, .subZero] {
			var fight = duel(character, distance: 600)
			tick(&fight, character == .scorpion ? .left : .down)
			tick(&fight, .right)
			tick(&fight, [.right, .one])
			var connected = false
			for _ in 0 ..< 90 {
				let events = tick(&fight)
				for i in 0 ..< events.count where events[i].kind == .hit { connected = true }
				if connected { break }
			}
			#expect(connected)
			#expect(fight.fighters[1].caughtBy == character.specialOne)
			#expect(fight.fighters[1].pose == .frozen)
			#expect(fight.fighters[1].vx == 0 && fight.fighters[1].vy == 0)
			if character == .scorpion { #expect(fight.fighters[1].x - fight.fighters[0].x == 175) }
		}
	}

	@Test func teleportsCrossAndStrikeTheOpponent() {
		for character in [Character.scorpion, .sektor] {
			var fight = duel(character, distance: 900)
			let direction: Input = character == .scorpion ? .left : .right
			let button: Input = character == .scorpion ? .three : .four
			tick(&fight, .down)
			tick(&fight, direction)
			tick(&fight, [direction, button])
			#expect(fight.fighters[0].move == character.specialTwo)
			advance(&fight, 10)
			#expect(fight.fighters[0].x > fight.fighters[1].x)
			#expect(fight.fighters[0].facing == -1)
			advance(&fight, 12)
			#expect(fight.fighters[1].health < Fighter.maxHealth)
			#expect(fight.fighters[1].falling)
		}
	}

	@Test func travelingSpecialsCloseDistanceAndKnockDown() {
		for character in [Character.subZero, .jade] {
			var fight = duel(character, distance: 450)
			tick(&fight, .left)
			tick(&fight, .right)
			tick(&fight, [.right, .four])
			let start = fight.fighters[0].x
			#expect(fight.fighters[0].move == character.specialTwo)
			advance(&fight, 18)
			#expect(fight.fighters[0].x > start)
			#expect(fight.fighters[1].health < Fighter.maxHealth)
			#expect(fight.fighters[1].falling)
		}
	}

	@Test func bufferedAttackSurvivesLastFramesOfHitstun() {
		var a = Fighter(character: .jade, side: 0)
		a.pose = .hit
		a.stun = 4
		var fight = Fight(fighters: [a, .init(character: .sektor, side: 1)])
		tick(&fight, .one)
		#expect(fight.fighters[0].move == .none)
		advance(&fight, 4)
		#expect(fight.fighters[0].move == .punch1)
	}

	@Test func specialCancelAlsoWorksOnBlock() {
		var fight = duel(.sektor)
		tick(&fight, .one, .block)
		advance(&fight, 6, [], .block)
		tick(&fight, .left, .block)
		tick(&fight, .right, .block)
		tick(&fight, [.right, .one], .block)
		advance(&fight, 2, [], .block)
		#expect(fight.fighters[1].health == 995)
		#expect(fight.fighters[0].move == .rocket)
	}

	@Test func scoringAndDrawRetry() {
		var a = Fighter(character: .jade, side: 0)
		var b = Fighter(character: .sektor, side: 1)
		a.health = 0
		b.health = 0
		var draw = Fight(fighters: [a, b])
		tick(&draw)
		#expect(draw.winner == nil)
		advance(&draw, 90)
		#expect(draw.round == 1)
		#expect(draw.fighters[0].health == 1_000)
		#expect(draw.fighters[0].wins == 0)
		a.health = 1_000
		a.wins = 1
		b.wins = 1
		var final = Fight(fighters: [a, b], round: 3)
		tick(&final)
		#expect(final.phase == .matchEnd)
		#expect(final.winner == 0)
		#expect(final.fighters[0].wins == 2)
	}

	@Test func pauseClearsBufferedAttacks() {
		var fight = duel()
		tick(&fight, .one)
		tick(&fight)
		tick(&fight, .one)
		#expect(fight.fighters[0].queueCount == 1)
		fight.clearInputs()
		#expect(fight.fighters[0].queueCount == 0)
		#expect(fight.fighters[0].move == .punch1)
		advance(&fight, 60)
		#expect(fight.fighters[1].health == 950)
	}

	@Test func renderingCadenceDoesNotChangeCombat() {
		func outcome(hz: Int, character: Character) -> (Int, Int, Int32, Int32, Int) {
			var clock = FrameClock()
			var fight = duel(character, .sektor, distance: 900)
			var ai = AI(seed: 123)
			for _ in 0 ..< hz * 10 {
				for _ in 0 ..< clock.advance(1.0 / Double(hz)) {
					let period = fight.frame % 240
					let input: Input = period < 3 ? character.commandOne.input(at: period, facing: fight.fighters[0].facing)
						: (120 ..< 123).contains(period) ? character.commandTwo.input(at: period - 120, facing: fight.fighters[0].facing)
						: fight.frame % 100 < 25 ? .right : fight.frame % 100 == 26 ? .two : []
					let cpu = ai.input(fight)
					_ = fight.step([.init(held: input), cpu])
				}
			}
			return (fight.fighters[0].health, fight.fighters[1].health, fight.fighters[0].x, fight.fighters[1].x, fight.frame)
		}
		for character in Character.allCases {
			let a = outcome(hz: 30, character: character)
			let b = outcome(hz: 60, character: character)
			let c = outcome(hz: 120, character: character)
			#expect(a.0 == b.0 && b.0 == c.0)
			#expect(a.1 == b.1 && b.1 == c.1)
			#expect(a.2 == b.2 && b.2 == c.2)
			#expect(a.3 == b.3 && b.3 == c.3)
			#expect(a.4 == 600 && b.4 == 600 && c.4 == 600)
		}
	}

	@Test func cpuUsesAllCharactersAndFinishesMatches() {
		for character in Character.allCases {
			var fight = Fight(character, .sektor)
			var a = AI(seed: 1)
			var b = AI(seed: 2)
			for _ in 0 ..< 36_000 {
				let first = a.input(fight, player: 0)
				let second = b.input(fight, player: 1)
				_ = fight.step([first, second])
				if fight.phase == .matchEnd { break }
			}
			#expect(fight.phase == .matchEnd)
			#expect(fight.round <= 3)
		}
	}

	@Test func frameClockRejectsLongSuspension() {
		var clock = FrameClock()
		#expect(clock.advance(1.0 / 120.0) == 0)
		#expect(clock.advance(1.0 / 120.0) == 1)
		#expect(clock.advance(2) == 0)
		#expect(clock.remainder == 0)
		#expect(clock.advance(.infinity) == 0)
	}
}
