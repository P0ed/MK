import RealityKit
import UIKit
import simd
import COR
import Combine

@MainActor
private final class ProjectileView {
	let root = Entity()
	private let spear: Entity
	private let ice: Entity
	private let rang: Entity
	private let rocket: Entity
	private let net: Entity
	private let netHalo: ModelEntity
	private let bomb: Entity
	private let blast: Entity
	private let bombRipples = Entity()
	private let ripples: InlineArray<3, ModelEntity>
	private let fan: Entity
	private let smokeCloud: Entity
	private let fireball: Entity
	private let fuse: ModelEntity
	private var cloudPuffs: [ModelEntity] = []
	private var fireTrail: [ModelEntity] = []
	private let smokeWisps: InlineArray<8, ModelEntity>
	private let cord: ModelEntity
	private let flame: ModelEntity
	private let chain = Entity()
	private let chainLinks: InlineArray<14, ModelEntity>
	private let trails = Entity()
	private let spearWake = Entity()
	private let iceWake = Entity()
	private let rangWake = Entity()
	private let rocketWake = Entity()
	private let netWake = Entity()
	private let fanWake = Entity()
	private let fireWake = Entity()
	private let spearSparks: InlineArray<8, ModelEntity>
	private let iceShards: InlineArray<8, ModelEntity>
	private let rangRibbons: InlineArray<12, ModelEntity>
	private let exhaustPuffs: InlineArray<8, ModelEntity>
	private let netSparks: InlineArray<8, ModelEntity>
	private let fanRibbons: InlineArray<8, ModelEntity>
	private let fireStreaks: InlineArray<8, ModelEntity>
	private var history: InlineArray<12, SIMD3<Float>> = .init(repeating: .zero)
	private var historyCount = 0
	private var historyIndex = 0
	private var historyFrame = -1
	private var lastMove: MoveID = .none
	private var lastAge = -1
	private var wasActive = false
	private var lastRenderTime: Float = -1
	private var lastRenderPosition = SIMD3<Float>.zero
	private var trailEndTime: Float = -100
	private var heading: Float = 1

	init(meshes: Meshes) {
		let steel = SimpleMaterial(color: .lightGray, roughness: 0.5, isMetallic: true)
		let amber = UnlitMaterial(color: Colors.gold)
		spear = meshes.make([0.4, 0.08, 0.09], steel, shape: .diamond)
		ice = meshes.make([0.25, 0.17, 0.17], UnlitMaterial(color: .cyan), shape: .diamond)
		rang = Entity()
		for angle: Float in [-0.6, 0.6] {
			let blade = meshes.make([0.3, 0.045, 0.06], amber, at: [0.08, 0, 0])
			blade.orientation = simd_quatf(angle: angle, axis: [0, 0, 1])
			rang.addChild(blade)
		}
		rocket = Entity()
		rocket.addChild(meshes.make([0.32, 0.11, 0.11], steel, shape: .taper))
		rocket.addChild(meshes.make([0.16, 0.12, 0.12], UnlitMaterial(color: Colors.sektor), shape: .diamond, at: [0.2, 0, 0]))
		rocket.addChild(meshes.make([0.12, 0.20, 0.045], steel, at: [-0.13, 0, 0]))
		flame = meshes.make([0.24, 0.10, 0.10], UnlitMaterial(color: .orange), shape: .diamond, at: [-0.27, 0, 0])
		rocket.addChild(flame)
		net = meshes.makeNet(size: [0.68, 1.02])
		netHalo = meshes.make([0.80, 0.024, 1.12], UnlitMaterial(color: UIColor(red: 0.28, green: 1, blue: 0.46, alpha: 0.55)), shape: .ring)
		netHalo.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
		net.addChild(netHalo)
		bomb = Entity()
		bomb.addChild(meshes.make([0.28, 0.28, 0.28], steel, shape: .sphere))
		bomb.addChild(meshes.make([0.30, 0.09, 0.30], SimpleMaterial(color: Character.cyrax.color, roughness: 0.45, isMetallic: true), shape: .octagon))
		fuse = meshes.make([0.065, 0.065, 0.065], UnlitMaterial(color: .red), shape: .sphere, at: [0, 0.16, 0])
		bomb.addChild(fuse)
		blast = Entity()
		blast.addChild(meshes.make([1.3, 0.88, 0.80], UnlitMaterial(color: UIColor(red: 1, green: 0.29, blue: 0.05, alpha: 0.8)), shape: .sphere, at: [0, 0.28, 0]))
		blast.addChild(meshes.make([0.62, 0.65, 0.53], UnlitMaterial(color: .yellow), shape: .diamond, at: [0, 0.2, 0.15]))
		ripples = .init { i in
			meshes.make([1, 0.018, 1], UnlitMaterial(color: UIColor(red: 1, green: 0.70, blue: 0.20, alpha: 0.65)), shape: .ring, at: [0, 0.018 + Float(i) * 0.005, 0])
		}
		fan = meshes.makeFan(size: 0.95, color: Character.kitana.color)
		smokeCloud = Entity()
		for i in 0 ..< 7 {
			let puff = meshes.make([0.48, 0.55, 0.47], SimpleMaterial(color: UIColor(white: i % 2 == 0 ? 0.48 : 0.24, alpha: 0.58), roughness: 1, isMetallic: false), shape: .sphere)
			puff.position = [Float(i % 3 - 1) * 0.23, Float(i / 3 - 1) * 0.25, Float(i % 2) * 0.17]
			smokeCloud.addChild(puff)
			cloudPuffs.append(puff)
		}
		smokeWisps = .init { i in
			meshes.make([0.20, 0.34, 0.20], SimpleMaterial(color: UIColor(white: i % 2 == 0 ? 0.72 : 0.42, alpha: 0.4), roughness: 1, isMetallic: false), shape: .sphere)
		}
		fireball = Entity()
		fireball.addChild(meshes.make([0.37, 0.33, 0.33], UnlitMaterial(color: .orange), shape: .sphere))
		fireball.addChild(meshes.make([0.21, 0.19, 0.22], UnlitMaterial(color: UIColor(red: 1, green: 0.92, blue: 0.45, alpha: 1)), shape: .sphere, at: [0.07, 0, 0.07]))
		for i in 0 ..< 3 {
			let trail = meshes.make([0.34, 0.12, 0.12], UnlitMaterial(color: i == 0 ? .yellow : .orange), shape: .diamond, at: [-0.20 - Float(i) * 0.16, Float(i - 1) * 0.07, 0])
			fireball.addChild(trail)
			fireTrail.append(trail)
		}
		cord = meshes.make([1, 0.016, 0.016], SimpleMaterial(color: Colors.gold, isMetallic: false))
		chainLinks = .init { _ in meshes.make([0.13, 0.022, 0.065], steel, shape: .ring) }
		spearSparks = .init { _ in meshes.make([0.05, 0.022, 0.022], amber, shape: .diamond) }
		iceShards = .init { i in
			meshes.make([0.12, 0.035, 0.035], UnlitMaterial(color: i % 2 == 0 ? .cyan : UIColor(red: 0.76, green: 0.96, blue: 1, alpha: 0.70)), shape: .diamond)
		}
		rangRibbons = .init { i in
			meshes.make([0.1, 0.022, 0.022], UnlitMaterial(color: UIColor(red: i < 6 ? 0.32 : 0.74, green: 1, blue: 0.50, alpha: 0.65)))
		}
		exhaustPuffs = .init { i in
			let progress = Float(i) / 7
			let color = UIColor(red: CGFloat(1 - progress * 0.58), green: CGFloat(0.55 - progress * 0.19), blue: CGFloat(0.16 + progress * 0.20), alpha: 0.65)
			return meshes.make([0.18, 0.11, 0.11], UnlitMaterial(color: color), shape: .sphere)
		}
		netSparks = .init { _ in meshes.make([0.07, 0.018, 0.018], UnlitMaterial(color: UIColor(red: 0.48, green: 1, blue: 0.56, alpha: 0.72)), shape: .diamond) }
		fanRibbons = .init { i in
			meshes.make([0.14, 0.05, 0.016], UnlitMaterial(color: UIColor(red: 0.41, green: 0.62, blue: 1, alpha: i % 2 == 0 ? 0.62 : 0.34)), shape: .diamond)
		}
		fireStreaks = .init { i in
			meshes.make([0.18, 0.09, 0.08], UnlitMaterial(color: i < 3 ? .yellow : .orange), shape: .diamond)
		}
		for entity in [spear, ice, rang, rocket, net, bomb, blast, bombRipples, fan, smokeCloud, fireball] { root.addChild(entity); entity.isEnabled = false }
		for i in ripples.indices { bombRipples.addChild(ripples[i]); Self.opacity(ripples[i], 0) }
		for i in smokeWisps.indices { smokeCloud.addChild(smokeWisps[i]); Self.opacity(smokeWisps[i], 1) }
		for i in chainLinks.indices { chain.addChild(chainLinks[i]) }
		for i in spearSparks.indices {
			spearWake.addChild(spearSparks[i]); iceWake.addChild(iceShards[i])
			rocketWake.addChild(exhaustPuffs[i]); netWake.addChild(netSparks[i])
			fanWake.addChild(fanRibbons[i]); fireWake.addChild(fireStreaks[i])
			for entity in [spearSparks[i], iceShards[i], exhaustPuffs[i], netSparks[i], fanRibbons[i], fireStreaks[i]] { Self.opacity(entity, 1) }
		}
		for i in rangRibbons.indices { rangWake.addChild(rangRibbons[i]); Self.opacity(rangRibbons[i], 1) }
		for entity in [spearWake, iceWake, rangWake, rocketWake, netWake, fanWake, fireWake] { trails.addChild(entity); entity.isEnabled = false }
		for entity in [trails, blast, smokeCloud, netHalo] { Self.opacity(entity, 1) }
		reset()
	}

	func attach(to anchor: AnchorEntity) {
		anchor.addChild(root); anchor.addChild(cord); anchor.addChild(chain); anchor.addChild(trails)
	}

	func reset() {
		root.isEnabled = false; cord.isEnabled = false; chain.isEnabled = false; trails.isEnabled = false
		historyCount = 0; historyIndex = 0; historyFrame = -1
		lastMove = .none; lastAge = -1; wasActive = false
		lastRenderTime = -1; trailEndTime = -100
		lastRenderPosition = .zero; heading = 1
		root.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
	}

	func update(_ projectile: borrowing Projectile, fighter: borrowing Fighter, frame: Int, fraction: Float = 0) {
		if frame < historyFrame { reset() }
		let active = projectile.active, move = projectile.move
		let detonating = projectile.detonating, age = projectile.age
		let fraction = min(1, max(0, fraction))
		let time = Float(frame) + fraction
		let elapsed = lastRenderTime < 0 ? 0 : max(0, min(3, time - lastRenderTime))
		root.isEnabled = active
		let isSpear = move == .spear
		cord.isEnabled = active && isSpear
		chain.isEnabled = active && isSpear
		guard active else {
			if wasActive { trailEndTime = time; wasActive = false }
			let fade = max(0, 1 - (time - trailEndTime) / 9)
			trails.isEnabled = historyCount > 0 && fade > 0
			if trails.isEnabled {
				Self.opacity(trails, fade)
				updateTrails(lastMove, time: time, fraction: 0, head: lastRenderPosition)
			} else { historyCount = 0; lastMove = .none }
			lastRenderTime = time
			return
		}
		let simulationPosition = SIMD3<Float>(Float(projectile.x) / 256, Float(projectile.y) / 256, 0)
		let position = SIMD3<Float>((Float(projectile.x) + Float(projectile.vx) * fraction) / 256,
			max(0, Float(projectile.y) + Float(projectile.vy) * fraction) / 256, 0)
		let spawned = !wasActive || move != lastMove || age < lastAge || frame < historyFrame
		if spawned {
			historyCount = 0; historyIndex = 0; historyFrame = frame - 1
			heading = projectile.vx == 0 ? Float(fighter.facing) : projectile.vx < 0 ? -1 : 1
			root.orientation = simd_quatf(angle: heading < 0 ? .pi : 0, axis: [0, 1, 0])
		}
		record(simulationPosition, frame: frame)
		wasActive = true; lastMove = move; lastAge = age
		lastRenderTime = time; lastRenderPosition = position
		trails.isEnabled = true
		Self.opacity(trails, 1)
		spear.isEnabled = move == .spear
		ice.isEnabled = move == .ice
		rang.isEnabled = move == .rang
		rocket.isEnabled = move == .rocket
		net.isEnabled = move == .net
		bomb.isEnabled = move == .bomb && !detonating
		blast.isEnabled = move == .bomb && detonating
		bombRipples.isEnabled = move == .bomb && detonating
		fan.isEnabled = move == .fan
		smokeCloud.isEnabled = move == .smokeCloud
		fireball.isEnabled = move == .fireball
		root.position = position
		if projectile.vx != 0 { heading = projectile.vx < 0 ? -1 : 1 }
		let facing = simd_quatf(angle: heading < 0 ? .pi : 0, axis: [0, 1, 0])
		root.orientation = simd_slerp(root.orientation, facing, 1 - exp(-elapsed * 0.65))
		let ageTime = Float(age) + fraction
		switch move {
		case .rang: rang.orientation = simd_quatf(angle: time * 0.5, axis: [0, 0, 1])
		case .fan: fan.orientation = simd_quatf(angle: ageTime * 0.55, axis: [0, 0, 1])
		case .ice: ice.orientation = simd_quatf(angle: sin(ageTime * 0.13) * 0.2, axis: [1, 0, 0])
		case .net:
			net.orientation = simd_quatf(angle: sin(ageTime * 0.24) * 0.10, axis: [0, 0, 1])
			let netOpen = Self.smooth(ageTime / 3)
			net.scale = [netOpen * (1 + sin(ageTime * 0.23) * 0.045), netOpen * (1 + cos(ageTime * 0.27) * 0.055), 1]
			Self.opacity(netHalo, 0.6 + sin(ageTime * 0.7) * 0.25)
		case .bomb:
			bomb.orientation = simd_quatf(angle: ageTime * 0.16, axis: [0, 0, 1])
			let blink: Float = 1 + sin(min(ageTime, 36) * 0.7 + max(0, ageTime - 36) * 1.9) * 0.4
			fuse.scale = .init(repeating: 0.065 * blink)
			let explosionAge = max(0, ageTime - 48)
			let explosion = 0.5 + explosionAge * 0.11
			blast.scale = .init(repeating: explosion)
			Self.opacity(blast, 1 - Self.smooth(explosionAge / 8))
			for i in ripples.indices {
				let progress = max(0, min(1, (explosionAge - Float(i) * 1.2) / 6))
				let size = 0.30 + progress * (1.35 + Float(i) * 0.15)
				ripples[i].scale = [size, 0.018, size]
				Self.opacity(ripples[i], progress > 0 ? 1 - Self.smooth(progress) : 0)
			}
		case .smokeCloud:
			let cloudSize = Self.smooth(ageTime / 7) * (1 - Self.smooth((ageTime - 31) / 11))
			smokeCloud.scale = .init(repeating: cloudSize)
			Self.opacity(smokeCloud, 1 - Self.smooth((ageTime - 32) / 10))
			for i in cloudPuffs.indices {
				let phase = time * 0.09 + Float(i)
				let pulse = 1 + sin(phase) * 0.12
				cloudPuffs[i].scale = [0.48 * pulse, 0.55 * pulse, 0.47 * pulse]
				cloudPuffs[i].position = [Float(i % 3 - 1) * 0.23 + cos(phase) * 0.055,
					Float(i / 3 - 1) * 0.25 + sin(phase * 0.7) * 0.08, Float(i % 2) * 0.17]
			}
			for i in smokeWisps.indices {
				let phase = ageTime * 0.095 + Float(i) * 0.85
				let rise = (ageTime * 0.018 + Float(i) * 0.13).truncatingRemainder(dividingBy: 1.2)
				smokeWisps[i].position = [cos(phase) * (0.24 + rise * 0.18), rise - 0.5, sin(phase) * 0.22]
				smokeWisps[i].scale = [0.14 + rise * 0.11, 0.30 + rise * 0.18, 0.14 + rise * 0.11]
				Self.opacity(smokeWisps[i], sin(rise / 1.2 * .pi) * 0.65)
			}
		case .fireball:
			for i in fireTrail.indices {
				let flicker = 1 + sin(time * 1.7 + Float(i) * 2) * 0.25
				fireTrail[i].scale = [0.34 * flicker, 0.12 / flicker, 0.12 / flicker]
			}
		case .rocket: flame.scale.x = 0.24 * (1 + sin(time * 2) * 0.25)
		default: break
		}
		updateTrails(move, time: time, fraction: fraction, head: position)
		guard isSpear else { return }
		let start = SIMD3<Float>((Float(fighter.x) + Float(fighter.vx) * fraction) / 256,
			max(0, Float(fighter.y) + Float(fighter.vy) * fraction) / 256 + 1.35, 0)
		let delta = root.position - start
		cord.position = (root.position + start) / 2
		cord.scale.x = simd_length(delta)
		let orientation = Self.along(delta)
		cord.orientation = orientation
		let spacing = simd_length(delta) / Float(chainLinks.count + 1)
		for i in chainLinks.indices {
			let progress = Float(i + 1) / Float(chainLinks.count + 1)
			chainLinks[i].position = start + delta * progress + SIMD3<Float>(0, -sin(progress * .pi) * min(0.06, spacing), 0)
			chainLinks[i].scale = [min(0.17, spacing * 1.1), 0.022, 0.065]
			chainLinks[i].orientation = orientation * simd_quatf(angle: Float(i % 2) * .pi / 2, axis: [1, 0, 0])
		}
	}

	private func record(_ position: SIMD3<Float>, frame: Int) {
		guard frame != historyFrame else { return }
		let old = historyCount == 0 ? position : history[(historyIndex + history.count - 1) % history.count]
		let steps = min(history.count, max(1, frame - historyFrame))
		for step in 1 ... steps {
			history[historyIndex] = old + (position - old) * (Float(step) / Float(steps))
			historyIndex = (historyIndex + 1) % history.count
			historyCount = min(history.count, historyCount + 1)
		}
		historyFrame = frame
	}

	private func trailPoint(_ delay: Float, fraction: Float, head: SIMD3<Float>) -> SIMD3<Float> {
		guard historyCount > 0 else { return head }
		let newest = (historyIndex + history.count - 1) % history.count
		if delay < fraction {
			return history[newest] + (head - history[newest]) * ((fraction - delay) / max(0.001, fraction))
		}
		let lag = min(Float(historyCount - 1), max(0, delay - fraction))
		let first = Int(lag), next = min(historyCount - 1, first + 1)
		let a = history[(newest + history.count - first) % history.count]
		let b = history[(newest + history.count - next) % history.count]
		return a + (b - a) * (lag - Float(first))
	}

	private func updateTrails(_ move: MoveID, time: Float, fraction: Float, head: SIMD3<Float>) {
		spearWake.isEnabled = move == .spear; iceWake.isEnabled = move == .ice
		rangWake.isEnabled = move == .rang; rocketWake.isEnabled = move == .rocket
		netWake.isEnabled = move == .net; fanWake.isEnabled = move == .fan
		fireWake.isEnabled = move == .fireball
		let growth = Self.smooth((Float(historyCount - 1) + fraction) / 3)
		switch move {
		case .spear:
			for i in spearSparks.indices {
				let progress = Float(i) / 8, phase = time * 0.4 + Float(i) * 1.3
				spearSparks[i].position = trailPoint(Float(i) * 0.65 + 0.5, fraction: fraction, head: head)
					+ SIMD3<Float>(0, sin(phase) * 0.055 * progress, 0.035)
				spearSparks[i].scale = [0.06 * (1 - progress * 0.7), 0.018, 0.018]
				spearSparks[i].orientation = simd_quatf(angle: phase, axis: [0, 0, 1])
				Self.opacity(spearSparks[i], growth * (1 - progress) * 0.8)
			}
		case .ice:
			for i in iceShards.indices {
				let progress = Float(i) / 8, phase = time * 0.17 + Float(i) * 1.4
				iceShards[i].position = trailPoint(Float(i) * 0.8 + 0.6, fraction: fraction, head: head)
					+ SIMD3<Float>(0, sin(phase) * (0.03 + progress * 0.07), Float(i % 2) * 0.045)
				iceShards[i].scale = [0.13 * (1 - progress * 0.6), 0.03, 0.03]
				iceShards[i].orientation = simd_quatf(angle: phase * 1.2, axis: [0, 0, 1])
				Self.opacity(iceShards[i], growth * (1 - progress * 0.8))
			}
		case .rang:
			for i in rangRibbons.indices {
				let strand = Float(i / 6), segment = Float(i % 6), delay = segment * 0.9 + 0.4
				var a = trailPoint(delay, fraction: fraction, head: head)
				var b = trailPoint(delay + 0.9, fraction: fraction, head: head)
				a.y += sin((time - delay) * 0.28 + strand * .pi) * 0.07
				b.y += sin((time - delay - 0.9) * 0.28 + strand * .pi) * 0.07
				a.z = 0.03 + strand * 0.03; b.z = a.z
				Self.segment(rangRibbons[i], from: a, to: b, width: 0.027 - segment * 0.003)
				Self.opacity(rangRibbons[i], growth * (0.85 - segment * 0.12))
			}
		case .rocket:
			for i in exhaustPuffs.indices {
				let progress = Float(i) / 8, phase = time * 0.37 + Float(i) * 2.1
				exhaustPuffs[i].position = trailPoint(Float(i) * 0.8 + 1.6, fraction: fraction, head: head)
					+ SIMD3<Float>(-heading * 0.15, sin(phase) * progress * 0.06, cos(phase) * progress * 0.045)
				let width = 0.075 + progress * 0.18
				exhaustPuffs[i].scale = [0.19 + progress * 0.07, width, width]
				Self.opacity(exhaustPuffs[i], growth * (1 - progress) * 0.72)
			}
		case .net:
			for i in netSparks.indices {
				let progress = Float(i) / 8, phase = time * 0.21 + Float(i) * .pi / 4
				netSparks[i].position = trailPoint(Float(i) * 0.55, fraction: fraction, head: head)
					+ SIMD3<Float>(cos(phase) * 0.32, sin(phase) * 0.43, 0.04)
				netSparks[i].orientation = simd_quatf(angle: phase + .pi / 2, axis: [0, 0, 1])
				Self.opacity(netSparks[i], growth * (0.8 - progress * 0.5))
			}
		case .fan:
			for i in fanRibbons.indices {
				let progress = Float(i) / 8, phase = (time - Float(i)) * 0.55
				fanRibbons[i].position = trailPoint(Float(i) * 0.7 + 0.6, fraction: fraction, head: head)
					+ SIMD3<Float>(cos(phase) * 0.12, sin(phase) * 0.19, 0.02)
				fanRibbons[i].scale = [0.19 * (1 - progress * 0.5), 0.055, 0.018]
				fanRibbons[i].orientation = simd_quatf(angle: phase + .pi / 2, axis: [0, 0, 1])
				Self.opacity(fanRibbons[i], growth * (0.82 - progress * 0.7))
			}
		case .fireball:
			for i in fireStreaks.indices {
				let progress = Float(i) / 8, phase = time * 0.62 + Float(i) * 1.7
				fireStreaks[i].position = trailPoint(Float(i) * 0.8 + 0.5, fraction: fraction, head: head)
					+ SIMD3<Float>(-heading * 0.04, sin(phase) * progress * 0.11, cos(phase) * 0.045)
				fireStreaks[i].scale = [0.23 * (1 - progress * 0.65), 0.105 * (1 - progress * 0.6), 0.08]
				fireStreaks[i].orientation = simd_quatf(angle: sin(phase) * 0.22, axis: [0, 0, 1])
				Self.opacity(fireStreaks[i], growth * (1 - progress * 0.95))
			}
		default: break
		}
	}

	private static func opacity(_ entity: Entity, _ value: Float) {
		entity.components.set(OpacityComponent(opacity: min(1, max(0, value))))
	}

	private static func smooth(_ value: Float) -> Float {
		let t = min(1, max(0, value))
		return t * t * (3 - 2 * t)
	}

	private static func segment(_ entity: Entity, from a: SIMD3<Float>, to b: SIMD3<Float>, width: Float) {
		let delta = b - a
		entity.position = (a + b) / 2
		entity.scale = [max(0.001, simd_length(delta)), width, width]
		entity.orientation = along(delta)
	}

	private static func along(_ delta: SIMD3<Float>) -> simd_quatf {
		let length = simd_length(delta)
		return simd_quatf(from: [1, 0, 0], to: length > 0.00001 ? delta / length : [1, 0, 0])
	}
}

@MainActor
final class Arena {
	let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
	private let anchor = AnchorEntity(world: .zero)
	private let meshes = Meshes()
	private let rigs: InlineArray<8, InlineArray<2, FighterRig>>
	private var selected: InlineArray<2, Character> = [.scorpion, .sektor]
	private let projectiles: InlineArray<2, ProjectileView>
	private let shadows: InlineArray<2, ModelEntity>
	private let sparks: InlineArray<12, ModelEntity>
	private var sparkFrames: InlineArray<12, Int> = .init(repeating: -100)
	private var sparkOrigins: InlineArray<12, SIMD3<Float>> = .init(repeating: .zero)
	private var sparkVelocities: InlineArray<12, SIMD3<Float>> = .init(repeating: .zero)
	private var sparkIndex = 0
	private var lastRound = 0
	private var lastPhase: Phase?
	private var lastFrame = -1
	private var wasPreview: Bool?
	private var subscription: (any Cancellable)?
	var update: (Double) -> Void = { _ in }

	init() {
		let meshes = self.meshes
		view.renderOptions = [.disableMotionBlur, .disableDepthOfField, .disableCameraGrain, .disableGroundingShadows, .disableAREnvironmentLighting]
		view.environment.background = .color(Colors.background)
		rigs = .init { index in .init { _ in FighterRig(Character(rawValue: UInt8(index))!, meshes: meshes) } }
		projectiles = .init { _ in ProjectileView(meshes: meshes) }
		shadows = .init { _ in meshes.make([0.9, 0.012, 0.55], UnlitMaterial(color: UIColor(white: 0, alpha: 0.48)), shape: .octagon, at: [0, 0.004, 0]) }
		sparks = .init { _ in meshes.make([0.2, 0.025, 0.025], UnlitMaterial(color: Colors.gold)) }
		view.scene.addAnchor(anchor)
		for i in rigs.indices {
			for j in 0 ..< 2 { anchor.addChild(rigs[i][j].root); rigs[i][j].root.isEnabled = false }
		}
		for i in 0 ..< 2 { projectiles[i].attach(to: anchor); anchor.addChild(shadows[i]) }
		for i in sparks.indices { anchor.addChild(sparks[i]); sparks[i].isEnabled = false }
		makeStage()
		subscription = view.scene.subscribe(to: SceneEvents.Update.self) { [weak self] event in
			let delta = event.deltaTime
			MainActor.assumeIsolated { self?.update(delta) }
		}
	}

	private func makeStage() {
		let stone = SimpleMaterial(color: UIColor(red: 0.16, green: 0.19, blue: 0.20, alpha: 1), roughness: 1, isMetallic: false)
		let paleStone = SimpleMaterial(color: UIColor(red: 0.27, green: 0.30, blue: 0.30, alpha: 1), roughness: 1, isMetallic: false)
		let trim = SimpleMaterial(color: UIColor(red: 0.43, green: 0.34, blue: 0.22, alpha: 1), roughness: 0.9, isMetallic: false)
		anchor.addChild(meshes.make([13, 0.22, 4], stone, at: [0, -0.12, -0.2]))
		for x: Float in [-5.5, -3.3, -1.1, 1.1, 3.3, 5.5] {
			anchor.addChild(meshes.make([2.15, 0.025, 1.8], paleStone, at: [x, 0.008, 0]))
		}
		anchor.addChild(meshes.make([13, 0.10, 0.15], trim, at: [0, 0.03, 1.65]))
		anchor.addChild(meshes.make([13, 0.10, 0.15], trim, at: [0, 0.03, -1.65]))
		for x: Float in [-5, -2.7, 2.7, 5] {
			anchor.addChild(meshes.make([0.55, 0.20, 0.7], stone, at: [x, 0.05, -2]))
			anchor.addChild(meshes.make([0.30, 2.8, 0.35], paleStone, shape: .taper, at: [x, 1.5, -2]))
			anchor.addChild(meshes.make([0.55, 0.18, 0.6], trim, at: [x, 2.9, -2]))
		}
		anchor.addChild(meshes.make([11, 0.2, 0.45], stone, at: [0, 3.05, -2]))
		anchor.addChild(meshes.make([1.7, 1.5, 0.12], stone, at: [0, 1.8, -2.8]))
		anchor.addChild(meshes.make([0.045, 1.2, 0.05], trim, at: [0, 1.8, -2.7]))
		let camera = PerspectiveCamera()
		camera.camera.fieldOfViewInDegrees = 40
		camera.look(at: [0, 1.8, 0], from: [0, 3.1, 9.7], relativeTo: nil)
		anchor.addChild(camera)
		let key = DirectionalLight()
		key.light.intensity = 2_000
		key.light.color = UIColor(red: 1, green: 0.88, blue: 0.70, alpha: 1)
		key.look(at: .zero, from: [3, 6, 4], relativeTo: nil)
		anchor.addChild(key)
		let fill = DirectionalLight()
		fill.light.intensity = 700
		fill.light.color = UIColor(red: 0.40, green: 0.65, blue: 1, alpha: 1)
		fill.look(at: .zero, from: [-4, 3, 2], relativeTo: nil)
		anchor.addChild(fill)
	}

	func select(_ first: Character, _ second: Character) {
		for i in rigs.indices {
			for j in 0 ..< 2 { rigs[i][j].root.isEnabled = false }
		}
		selected = [first, second]
		resetAnimations()
	}

	func resetAnimations() {
		for i in rigs.indices {
			for j in 0 ..< 2 { rigs[i][j].resetAnimation() }
		}
		for i in projectiles.indices { projectiles[i].reset() }
		for i in sparks.indices { sparkFrames[i] = -100; sparks[i].isEnabled = false }
		sparkIndex = 0
		lastRound = 0; lastPhase = nil; lastFrame = -1; wasPreview = nil
	}

	func draw(_ fight: borrowing Fight, fraction: Float = 0, previewFrame: Int? = nil) {
		let phase = fight.phase, round = fight.round, frame = fight.frame
		let preview = previewFrame != nil
		let fraction = fight.hitstop == 0 ? min(1, max(0, fraction)) : 0
		if lastRound != 0, lastRound != round || frame < lastFrame || (phase == .intro && lastPhase != .intro) || wasPreview != preview {
			resetAnimations()
		}
		lastRound = round; lastPhase = phase; lastFrame = frame; wasPreview = preview
		for i in 0 ..< 2 {
			let fighter = fight.fighters[i]
			let rig = rigs[Int(selected[i].rawValue)][i]
			rig.update(fighter, frame: previewFrame ?? frame, fraction: fraction)
			projectiles[i].update(fight.projectiles[i], fighter: fighter, frame: frame, fraction: fraction)
			shadows[i].position.x = rig.root.position.x
			let scale = max(0.5, 1 - rig.root.position.y * 0.128)
			shadows[i].scale = [0.9 * scale, 0.012, 0.55 * scale]
		}
		for i in sparks.indices {
			let age = Float(frame - sparkFrames[i]) + fraction
			sparks[i].isEnabled = age >= 0 && age < 12
			if age >= 0, age < 12 {
				sparks[i].position = sparkOrigins[i] + sparkVelocities[i] * age + SIMD3<Float>(0, -age * age * 0.0008, 0)
				sparks[i].scale.x = 0.16 - age * 0.01
				sparks[i].components[OpacityComponent.self] = .init(opacity: 1 - age / 12)
			}
		}
	}

	func process(_ event: FrameEvent, frame: Int) {
		guard event.kind == .hit || event.kind == .block else { return }
		for i in 0 ..< 3 {
			let index = sparkIndex
			sparkIndex = (sparkIndex + 1) % sparks.count
			sparkFrames[index] = frame
			let angle = Float(i) * .pi / 3
			sparkOrigins[index] = [Float(event.x) / 256 + Float(i - 1) * 0.06, Float(event.y) / 256, 0.45]
			sparkVelocities[index] = [cos(angle) * 0.023, sin(angle) * 0.025, 0]
			sparks[index].position = sparkOrigins[index]
			sparks[index].orientation = simd_quatf(angle: angle, axis: [0, 0, 1])
			sparks[index].isEnabled = true
		}
	}
}
