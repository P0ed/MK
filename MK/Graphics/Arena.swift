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
	private let cord: ModelEntity
	private let flame: ModelEntity

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
		cord = meshes.make([1, 0.016, 0.016], SimpleMaterial(color: Colors.gold, isMetallic: false))
		for entity in [spear, ice, rang, rocket] { root.addChild(entity); entity.isEnabled = false }
	}

	func attach(to anchor: AnchorEntity) { anchor.addChild(root); anchor.addChild(cord) }

	func update(_ projectile: borrowing Projectile, fighter: borrowing Fighter, frame: Int) {
		root.isEnabled = projectile.active
		let isSpear = projectile.move == .spear
		cord.isEnabled = projectile.active && isSpear
		guard projectile.active else { return }
		spear.isEnabled = projectile.move == .spear
		ice.isEnabled = projectile.move == .ice
		rang.isEnabled = projectile.move == .rang
		rocket.isEnabled = projectile.move == .rocket
		root.position = [Float(projectile.x) / 256, Float(projectile.y) / 256, 0]
		root.orientation = simd_quatf(angle: projectile.vx < 0 ? .pi : 0, axis: [0, 1, 0])
		rang.orientation = simd_quatf(angle: Float(frame) * 0.5, axis: [0, 0, 1])
		flame.scale.x = 0.24 * (1 + sin(Float(frame) * 2) * 0.25)
		let start = SIMD3<Float>(Float(fighter.x) / 256, Float(fighter.y) / 256 + 1.35, 0)
		let delta = root.position - start
		cord.position = (root.position + start) / 2
		cord.scale.x = simd_length(delta)
		cord.orientation = simd_quatf(from: [1, 0, 0], to: simd_normalize(delta + SIMD3<Float>(0.0001, 0, 0)))
	}
}

@MainActor
final class Arena {
	let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
	private let anchor = AnchorEntity(world: .zero)
	private let meshes = Meshes()
	private let rigs: InlineArray<4, InlineArray<2, FighterRig>>
	private var selected: InlineArray<2, Character> = [.scorpion, .sektor]
	private let projectiles: InlineArray<2, ProjectileView>
	private let shadows: InlineArray<2, ModelEntity>
	private let sparks: InlineArray<12, ModelEntity>
	private var sparkFrames: InlineArray<12, Int> = .init(repeating: -100)
	private var sparkIndex = 0
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
		for i in 0 ..< 4 {
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
		for i in 0 ..< 4 {
			for j in 0 ..< 2 { rigs[i][j].root.isEnabled = false }
		}
		selected = [first, second]
		for i in sparks.indices { sparkFrames[i] = -100; sparks[i].isEnabled = false }
	}

	func draw(_ fight: borrowing Fight, fraction: Float = 0, previewFrame: Int? = nil) {
		let fraction = fight.phase == .fighting && fight.hitstop == 0 ? fraction : 0
		for i in 0 ..< 2 {
			let fighter = fight.fighters[i]
			rigs[Int(selected[i].rawValue)][i].update(fighter, frame: previewFrame ?? fight.frame, fraction: fraction)
			projectiles[i].update(fight.projectiles[i], fighter: fighter, frame: fight.frame)
			shadows[i].position.x = Float(fighter.x) / 256
			let scale = max(0.5, 1 - Float(fighter.y) / 2_000)
			shadows[i].scale = [0.9 * scale, 0.012, 0.55 * scale]
		}
		for i in sparks.indices {
			let age = fight.frame - sparkFrames[i]
			sparks[i].isEnabled = age >= 0 && age < 12
			if age >= 0, age < 12 { sparks[i].scale.x = 0.1 + Float(age) * 0.015 }
		}
	}

	func process(_ event: FrameEvent, frame: Int) {
		guard event.kind == .hit || event.kind == .block else { return }
		for i in 0 ..< 3 {
			let index = sparkIndex
			sparkIndex = (sparkIndex + 1) % sparks.count
			sparkFrames[index] = frame
			sparks[index].position = [Float(event.x) / 256 + Float(i - 1) * 0.06, Float(event.y) / 256, 0.45]
			sparks[index].orientation = simd_quatf(angle: Float(i) * .pi / 3, axis: [0, 0, 1])
			sparks[index].isEnabled = true
		}
	}
}
