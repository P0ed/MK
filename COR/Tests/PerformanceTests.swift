import Testing
import Foundation
import COR

struct PerformanceTests {
	@Test func sustainedCombatFitsSimulationBudget() {
		var fight = Fight(.jade, .sektor)
		var first = AI(seed: 301)
		var second = AI(seed: 302)
		let clock = ContinuousClock()
		let start = clock.now
		let frames = 60_000
		var checksum = 0
		for _ in 0 ..< frames {
			if fight.phase == .matchEnd { fight = Fight(.jade, .sektor) }
			let a = first.input(fight, player: 0)
			let b = second.input(fight, player: 1)
			let events = fight.step([a, b])
			checksum &+= fight.fighters[0].health + fight.fighters[1].health + events.count
		}
		let elapsed = start.duration(to: clock.now).components
		let seconds = Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
		let microseconds = seconds * 1e6 / Double(frames)
		print("Combat + two CPUs: \(microseconds) µs / tick (\(frames) ticks)")
		#expect(checksum > frames)
		#expect(microseconds < 1_000, "Simulation should consume less than 1 ms of the 16.7 ms frame budget")
	}
}
