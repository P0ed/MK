import Testing
@testable import COR

private func lethalLauncher(finalRound: Bool) -> Fight {
	var attacker = Fighter(character: .scorpion, side: 0)
	var victim = Fighter(character: .smoke, side: 1)
	attacker.x = -110
	victim.x = 100
	attacker.wins = finalRound ? 1 : 0
	victim.wins = finalRound ? 1 : 0
	victim.health = 1
	attacker.start(.uppercut)
	attacker.moveFrame = attacker.moveData.startup - 1
	return Fight(fighters: [attacker, victim], round: finalRound ? 3 : 1)
}

private func endingTick(_ fight: inout Fight, pressed: Bool = false) -> FrameEvents {
	let input: Input = pressed ? [.up, .right, .one, .two, .three, .four] : []
	return fight.step([.init(held: input), .init(held: input)])
}

struct KnockoutTests {
	@Test func finalLethalLauncherFinishesItsArcWithoutMoreHitsOrWins() {
		var fight = lethalLauncher(finalRound: true)
		let knockout = endingTick(&fight)
		#expect(fight.phase == .matchEnd)
		#expect(fight.phaseFrame == 0)
		#expect(fight.fighters[1].health == 0)
		#expect(fight.fighters[1].vy == 78)
		#expect(fight.defeatedSettled == false)
		#expect(fight.fighters[0].move == .none)
		#expect(fight.fighters[0].wins == 2)
		#expect(knockout.count == 4)
		let firstLandingFrame = endingTick(&fight, pressed: true)
		#expect(firstLandingFrame.count == 0)
		#expect(fight.phaseFrame == 1)
		#expect(fight.fighters[1].y == 78)
		#expect(fight.fighters[1].vy < 78)
		let winnerHealth = fight.fighters[0].health
		for _ in 0 ..< 89 {
			let events = endingTick(&fight, pressed: fight.frame % 2 == 0)
			#expect(events.count == 0)
			#expect(fight.fighters[0].health == winnerHealth)
			#expect(fight.fighters[1].health == 0)
			#expect(fight.fighters[0].wins == 2)
			#expect(fight.fighters[1].wins == 1)
		}
		#expect(fight.phase == .matchEnd && fight.phaseFrame == 90)
		#expect(fight.defeatedSettled == true)
		#expect(fight.fighters[1].y == 0 && fight.fighters[1].vy == 0)
		#expect(fight.fighters[1].pose == .down)
		#expect(fight.fighters[0].move == .none && fight.fighters[1].move == .none)
	}

	@Test func roundKnockoutSettlesBeforeItsExistingRestartTimer() {
		var fight = lethalLauncher(finalRound: false)
		_ = endingTick(&fight)
		#expect(fight.phase == .roundEnd)
		for _ in 0 ..< 60 { _ = endingTick(&fight, pressed: true) }
		#expect(fight.phase == .roundEnd && fight.phaseFrame == 60)
		#expect(fight.defeatedSettled == true)
		#expect(fight.fighters[1].pose == .down)
		#expect(fight.fighters[0].wins == 1)
		for _ in 0 ..< 30 { _ = endingTick(&fight) }
		#expect(fight.phase == .intro && fight.round == 2)
		#expect(fight.fighters[1].health == Fighter.maxHealth)
		#expect(fight.fighters[0].wins == 1)
		#expect(fight.defeatedSettled == false)
	}

	@Test func endingSettlementThawsAirborneCapturesAndHasABoundedDuration() {
		var winner = Fighter(character: .cyrax, side: 0)
		winner.wins = 1
		var victim = Fighter(character: .kitana, side: 1)
		victim.health = 1
		victim.y = 400
		victim.pose = .frozen
		victim.caughtBy = .net
		victim.captured = true
		let net = Projectile(active: true, move: .net, x: victim.x, y: victim.y + 385, oldX: victim.x)
		var fight = Fight(fighters: [winner, victim], projectiles: [net, .init()])
		_ = endingTick(&fight)
		#expect(fight.phase == .matchEnd)
		#expect(fight.fighters[1].pose == .hit)
		#expect(fight.fighters[1].caughtBy == .none)
		#expect(!fight.projectiles[0].active)
		for _ in 0 ..< 60 { _ = endingTick(&fight) }
		#expect(fight.defeatedSettled == true)
		#expect(fight.fighters[1].pose == .down)

		victim.health = 0
		victim.y = 100_000
		victim.vy = 10_000
		var bounded = Fight(fighters: [winner, victim], phase: .matchEnd)
		for _ in 0 ..< 90 { _ = endingTick(&bounded) }
		#expect(bounded.defeatedSettled == true)
	}
}
