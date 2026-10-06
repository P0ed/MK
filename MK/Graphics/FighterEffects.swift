import RealityKit
import UIKit
import simd
import COR

/// Render samples and effect meshes are bounded and created with the fighter rig.
struct RigSample {
	var position: SIMD3<Float> = .zero
	var orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
	var bodyPosition: SIMD3<Float> = .zero
	var tilt: Float = 0
	var joints: InlineArray<8, Float> = .init(repeating: 0)
	var time: Float = -100
}

@MainActor
private final class MotionEcho {
	let root = Entity()
	private let body: Entity
	private let joints: InlineArray<8, Entity>

	init(body source: Entity, color: UIColor) {
		let body = source.clone(recursive: true)
		self.body = body
		let names = ["nearArm", "farArm", "nearElbow", "farElbow", "nearLeg", "farLeg", "nearKnee", "farKnee"]
		joints = .init { body.findEntity(named: names[$0])! }
		root.addChild(body)
		Self.tint(body, material: UnlitMaterial(color: color))
		root.components.set(OpacityComponent(opacity: 0))
		root.isEnabled = false
	}

	private static func tint(_ entity: Entity, material: UnlitMaterial) {
		if let model = entity as? ModelEntity { model.model?.materials = [material] }
		for child in entity.children { tint(child, material: material) }
	}

	func draw(_ sample: RigSample, parent: Entity, opacity: Float) {
		let inverse = simd_inverse(parent.orientation)
		root.position = inverse.act(sample.position - parent.position)
		root.orientation = inverse * sample.orientation
		body.position = sample.bodyPosition
		body.orientation = simd_quatf(angle: sample.tilt, axis: [0, 0, 1])
		for i in joints.indices { joints[i].orientation = simd_quatf(angle: sample.joints[i], axis: [0, 0, 1]) }
		root.components[OpacityComponent.self] = .init(opacity: opacity)
		root.isEnabled = opacity > 0.002
	}
}

@MainActor
final class FighterEffects {
	private let root = Entity()
	private let charge = Entity()
	private let motion = Entity()
	private let shards = Entity()
	private let landing = Entity()
	private let departure = Entity()
	private let arrival = Entity()
	private let travel = Entity()
	private let sourceRing: ModelEntity
	private let particles: InlineArray<8, ModelEntity>
	private let ribbons: InlineArray<8, ModelEntity>
	private let crystals: InlineArray<8, ModelEntity>
	private let dust: InlineArray<8, ModelEntity>
	private let departurePuffs: InlineArray<6, ModelEntity>
	private let arrivalPuffs: InlineArray<6, ModelEntity>
	private let travelBars: InlineArray<3, ModelEntity>
	private var echoes: [MotionEcho] = []
	private var samples: InlineArray<3, RigSample> = .init(repeating: .init())
	private var lastSample: Float = -100
	private var lastMove: MoveID = .none
	private let character: Character

	init(character: Character, meshes: Meshes, owner: Entity, body: Entity) {
		self.character = character
		let color: UIColor = character == .liuKang || character == .sektor || character == .scorpion ? .orange : character.color
		let light = UnlitMaterial(color: color)
		let frost = UnlitMaterial(color: UIColor(red: 0.65, green: 0.9, blue: 1, alpha: 1))
		let dirt = SimpleMaterial(color: UIColor(red: 0.45, green: 0.40, blue: 0.32, alpha: 0.7), roughness: 1, isMetallic: false)
		let haze = SimpleMaterial(color: character == .smoke ? UIColor(white: 0.5, alpha: 0.6) : color.withAlphaComponent(0.55), roughness: 1, isMetallic: false)
		sourceRing = meshes.make([0.25, 0.25, 0.25], light, shape: .ring)
		particles = .init { _ in meshes.make([0.08, 0.03, 0.03], light, shape: .diamond) }
		ribbons = .init { _ in meshes.make([0.4, 0.04, 0.04], light, shape: .diamond) }
		crystals = .init { _ in meshes.make([0.07, 0.18, 0.07], frost, shape: .diamond) }
		dust = .init { _ in meshes.make([0.15, 0.10, 0.15], dirt, shape: .sphere) }
		departurePuffs = .init { _ in meshes.make([0.35, 0.45, 0.35], haze, shape: character == .smoke ? .sphere : .diamond) }
		arrivalPuffs = .init { _ in meshes.make([0.35, 0.45, 0.35], haze, shape: character == .smoke ? .sphere : .diamond) }
		travelBars = .init { _ in meshes.make([1, 0.03, 0.03], light, shape: .diamond) }
		owner.addChild(root)
		for entity in [charge, motion, shards, landing, departure, arrival, travel] {
			root.addChild(entity)
			entity.components.set(OpacityComponent(opacity: 0))
			entity.isEnabled = false
		}
		charge.addChild(sourceRing)
		for i in particles.indices { charge.addChild(particles[i]); motion.addChild(ribbons[i]); shards.addChild(crystals[i]); landing.addChild(dust[i]) }
		for i in departurePuffs.indices { departure.addChild(departurePuffs[i]); arrival.addChild(arrivalPuffs[i]) }
		for i in travelBars.indices { travel.addChild(travelBars[i]) }
		if character == .jade || character == .subZero || character == .liuKang {
			for _ in 0 ..< 3 {
				let echo = MotionEcho(body: body, color: color)
				owner.addChild(echo.root)
				echoes.append(echo)
			}
		}
	}

	func reset() {
		lastSample = -100; lastMove = .none
		for i in samples.indices { samples[i].time = -100 }
		for entity in [charge, motion, shards, landing, departure, arrival, travel] { entity.isEnabled = false }
		for echo in echoes { echo.root.isEnabled = false }
	}

	func update(owner: Entity, sample: RigSample, move: MoveID, elapsed: Float, data: MoveData,
		pose: Pose, caughtBy: MoveID, landingAge: Float, teleportOrigin: SIMD3<Float>, alive: Bool) {
		let time = sample.time
		if move != lastMove {
			lastSample = -100
			for i in samples.indices { samples[i].time = -100 }
			lastMove = move
		}
		let startup = Float(max(1, data.startup))
		let activeEnd = Float(data.startup + data.active)
		let launching = alive && move.isProjectile
		let build = launching ? sin(min(1, elapsed / startup) * .pi) * 0.8 + max(0, 1 - abs(elapsed - startup) / 5) * 0.5 : 0
		var source = SIMD3<Float>(0.70, 1.30, 0.10)
		if move == .net { source = [0.30, 1.25, 0] }
		if move == .rocket { source = [0.23, 1.60, -0.29] }
		if move == .bomb { source = [0.40, 0.78, 0.15] }
		if move == .fireball { source.y = 1.05 }
		charge.position = source
		fade(charge, build)
		sourceRing.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])
		sourceRing.scale = .init(repeating: 0.22 + build * 0.25)
		for i in particles.indices {
			let angle = time * 0.21 + Float(i) * .pi / 4
			particles[i].position = [cos(angle) * 0.14, sin(angle) * 0.16, Float(i % 3 - 1) * 0.07]
			particles[i].orientation = simd_quatf(angle: angle, axis: [0, 0, 1])
		}

		let rushing = move == .slide || move == .shadowKick || move == .flyingKick || move == .teleportUppercut
		let rush = alive && rushing ? smooth((elapsed - startup + 3) / 3) * (1 - smooth((elapsed - activeEnd) / 8)) : 0
		fade(motion, rush * 0.75)
		for i in ribbons.indices {
			let phase = time * 0.16 + Float(i) * 0.8
			let height: Float = move == .slide ? 0.13 : move == .teleportUppercut ? 0.2 + Float(i) * 0.12 : 0.72
			ribbons[i].position = [-0.18 - Float(i) * 0.09, height + sin(phase) * 0.09, Float(i % 3 - 1) * 0.16]
			ribbons[i].scale = [0.35 + rush * 0.20, 0.03 + rush * 0.025, 0.035]
			ribbons[i].orientation = simd_quatf(angle: move == .teleportUppercut ? .pi / 2 : sin(phase) * 0.15, axis: [0, 0, 1])
		}

		let frozen = pose == .frozen && caughtBy == .ice
		let cold = frozen ? 0.85 : move == .ice ? build : move == .slide ? rush * 0.65 : 0
		fade(shards, cold)
		for i in crystals.indices {
			let angle = Float(i) * .pi / 4 + time * 0.025
			crystals[i].position = frozen ? [cos(angle) * 0.32, 0.3 + Float(i) * 0.19, sin(angle) * 0.35]
				: move == .ice ? source + SIMD3<Float>(sin(angle) * 0.25, cos(angle) * 0.24, 0)
				: [-0.2 - Float(i) * 0.15, 0.12 + Float(i % 2) * 0.06, sin(angle) * 0.25]
			crystals[i].orientation = simd_quatf(angle: angle, axis: [0, 0, 1])
		}

		let landingPhase = min(1, max(0, landingAge / 14))
		fade(landing, landingAge >= 0 && landingAge < 14 ? (1 - landingPhase) * 0.7 : 0)
		for i in dust.indices {
			let angle = Float(i) * .pi / 4
			dust[i].position = [cos(angle) * (0.15 + landingPhase * 0.5), 0.035 + sin(landingPhase * .pi) * 0.12, sin(angle) * (0.12 + landingPhase * 0.30)]
			dust[i].scale = .init(repeating: 0.10 + landingPhase * 0.12)
		}

		if rushing, rush > 0.05, time - lastSample >= 2 {
			for i in stride(from: samples.count - 1, through: 1, by: -1) { samples[i] = samples[i - 1] }
			samples[0] = sample; lastSample = time
		}
		for i in echoes.indices {
			let age = time - samples[i].time
			let opacity = rushing && age > 0.5 && age < 9 ? rush * max(0, 1 - age / 9) * 0.28 : 0
			echoes[i].draw(samples[i], parent: owner, opacity: opacity)
		}

		let teleporting = move.isTeleport && alive
		let relocation: Float = move == .smokeTeleport ? 12 : 8
		let depart = teleporting ? smooth(elapsed / 3) * (1 - smooth((elapsed - relocation - 2) / 8)) : 0
		let appear = teleporting ? smooth((elapsed - relocation + 1) / 3) * (1 - smooth((elapsed - relocation - 5) / 7)) : 0
		let inverse = simd_inverse(owner.orientation)
		departure.position = inverse.act(teleportOrigin - owner.position)
		fade(departure, depart * 0.75); fade(arrival, appear * 0.7)
		for i in departurePuffs.indices {
			let phase = time * 0.15 + Float(i)
			let y = 0.16 + Float(i) * 0.27
			departurePuffs[i].position = [sin(phase) * 0.24, y + depart * 0.12, cos(phase) * 0.22]
			arrivalPuffs[i].position = [cos(phase) * 0.23, y, sin(phase) * 0.24]
			departurePuffs[i].scale = [0.20 + depart * 0.35, 0.30 + depart * 0.35, 0.20 + depart * 0.35]
			arrivalPuffs[i].scale = [0.22 + appear * 0.30, 0.25 + appear * 0.4, 0.22 + appear * 0.30]
		}
		let distance = simd_length(owner.position - teleportOrigin)
		let trailOpacity = teleporting && distance > 0.05 ? smooth((elapsed - relocation) / 2) * (1 - smooth((elapsed - relocation - 3) / 6)) : 0
		fade(travel, trailOpacity * 0.7)
		let delta = inverse.act(owner.position - teleportOrigin)
		for i in travelBars.indices {
			travelBars[i].position = -delta / 2 + SIMD3<Float>(0, 0.55 + Float(i) * 0.3, Float(i - 1) * 0.13)
			travelBars[i].scale = [distance, 0.025, 0.03]
			travelBars[i].orientation = simd_quatf(from: [1, 0, 0], to: simd_normalize(delta + SIMD3<Float>(0.0001, 0, 0)))
		}
	}

	private func fade(_ entity: Entity, _ opacity: Float) {
		entity.isEnabled = opacity > 0.002
		entity.components[OpacityComponent.self] = .init(opacity: min(1, max(0, opacity)))
	}

	private func smooth(_ value: Float) -> Float {
		let t = min(1, max(0, value)); return t * t * (3 - 2 * t)
	}
}
