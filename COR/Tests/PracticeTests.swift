import Testing
@testable import COR

struct PracticeTests {
	@Test func practiceStartsImmediatelyAndNeverScoresAfterLethalDamage() {
		var attacker = Fighter(character: .sektor, side: 0)
		var dummy = Fighter(character: .scorpion, side: 1)
		attacker.x = Fight.edge - 200
		dummy.x = Fight.edge
		var fight = Fight(fighters: [attacker, dummy], practice: true)
		var damage = 0
		for tick in 0 ..< 6_000 {
			let events = fight.step([.init(held: tick % 40 == 0 ? .one : []), .init()])
			for i in 0 ..< events.count {
				if events[i].kind == .hit { damage += events[i].damage }
				#expect(events[i].kind != .knockout && events[i].kind != .roundWin && events[i].kind != .matchWin)
			}
			#expect(fight.fighters[0].health == Fighter.maxHealth)
			#expect(fight.fighters[1].health == Fighter.maxHealth)
		}
		#expect(damage > Fighter.maxHealth * 3)
		#expect(fight.phase == .fighting && fight.round == 1 && fight.winner == nil)
		#expect(fight.fighters[0].wins == 0 && fight.fighters[1].wins == 0)
		#expect(fight.fighters[0].comboDamage > 0)
	}

	@Test func bothPracticeFightersHaveInfiniteHealthIncludingChip() {
		for blocking in [false, true] {
			var a = Fighter(character: .sektor, side: 0)
			var b = Fighter(character: .scorpion, side: 1)
			a.x = -100
			b.x = 100
			var fight = Fight(fighters: [a, b], practice: true)
			var contacts = 0
			for tick in 0 ..< 20 {
				let events = fight.step([
					.init(held: blocking ? .block : tick == 0 ? .one : []),
					.init(held: tick == 0 ? .one : [])
				])
				for i in 0 ..< events.count where events[i].kind == (blocking ? .block : .hit) { contacts += 1 }
			}
			#expect(contacts == (blocking ? 1 : 2))
			#expect(fight.fighters[0].health == Fighter.maxHealth && fight.fighters[1].health == Fighter.maxHealth)
		}
	}

	@Test func resetPracticeClearsTheEntireDrillAndKeepsTheMatchup() {
		var a = Fighter(character: .kitana, side: 0)
		var b = Fighter(character: .cyrax, side: 1)
		a.x = 900
		a.comboHits = 5
		a.comboDamage = 350
		a.start(.fan)
		b.y = 200
		b.vy = 40
		b.stun = 20
		let projectile = Projectile(active: true, move: .fan, x: 1_000, y: 385, vx: 34)
		var fight = Fight(fighters: [a, b], projectiles: [projectile, .init()], practice: true)
		_ = fight.step([.init(held: .one), .init()])
		fight.resetPractice()
		#expect(fight.practice && fight.phase == .fighting && fight.frame == 0 && fight.hitstop == 0)
		#expect(fight.fighters[0].character == .kitana && fight.fighters[1].character == .cyrax)
		#expect(fight.fighters[0].x == -384 && fight.fighters[1].x == 384)
		for i in 0 ..< 2 {
			#expect(fight.fighters[i].health == Fighter.maxHealth)
			#expect(fight.fighters[i].move == .none && fight.fighters[i].stun == 0)
			#expect(!fight.fighters[i].airborne && fight.fighters[i].pose == .idle)
			#expect(fight.fighters[i].comboHits == 0 && fight.fighters[i].comboDamage == 0)
			#expect(fight.fighters[i].queueCount == 0 && fight.fighters[i].input.isEmpty)
			#expect(!fight.projectiles[i].active)
		}
	}

	@Test func practiceAPILeavesScoredMatchesAlone() {
		var practice = Fight(.smoke, .jade, practice: true)
		#expect(practice.phase == .fighting)
		var scored = Fight(.liuKang, .subZero)
		_ = scored.step([.init(), .init()])
		scored.resetPractice()
		#expect(!scored.practice && scored.phase == .intro && scored.frame == 1)
		practice.resetPractice()
		#expect(practice.phase == .fighting)
	}
}
