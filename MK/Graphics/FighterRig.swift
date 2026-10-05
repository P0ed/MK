import RealityKit
import UIKit
import simd
import COR

@MainActor
final class FighterRig {
	let root = Entity()
	let body = Entity()
	private let head = Entity()
	private let nearArm = Entity()
	private let nearElbow = Entity()
	private let farArm = Entity()
	private let farElbow = Entity()
	private let nearLeg = Entity()
	private let nearKnee = Entity()
	private let farLeg = Entity()
	private let farKnee = Entity()
	private let frost: ModelEntity
	private var staff: Entity?
	private let character: Character

	init(_ character: Character, meshes: Meshes) {
		self.character = character
		let cloth = SimpleMaterial(color: character.color, roughness: 0.8, isMetallic: character == .sektor)
		let dark = SimpleMaterial(color: UIColor(white: 0.07, alpha: 1), roughness: 0.9, isMetallic: false)
		let skin = SimpleMaterial(color: UIColor(red: 0.68, green: 0.48, blue: 0.34, alpha: 1), roughness: 0.9, isMetallic: false)
		let steel = SimpleMaterial(color: UIColor(white: 0.38, alpha: 1), roughness: 0.65, isMetallic: true)
		let eye = UnlitMaterial(color: character == .sektor ? .yellow : UIColor(white: 0.95, alpha: 1))
		frost = meshes.make([0.62, 1.72, 0.76], UnlitMaterial(color: UIColor(red: 0.3, green: 0.8, blue: 1, alpha: 0.22)), shape: .diamond, at: [0, 0.95, 0])
		frost.isEnabled = false
		root.addChild(body)
		root.addChild(frost)
		let width: Float = character == .jade ? 0.86 : 1
		body.addChild(meshes.make([0.37 * width, 0.55, 0.60 * width], dark, shape: .taper, at: [0, 1.2, 0]))
		body.addChild(meshes.make([0.41 * width, 0.44, 0.62 * width], cloth, shape: .taper, at: [0.015, 1.25, 0]))
		body.addChild(meshes.make([0.39 * width, 0.12, 0.54 * width], dark, at: [0, 0.96, 0]))
		body.addChild(meshes.make([0.025, 0.09, 0.12], steel, at: [0.21, 0.96, 0]))
		body.addChild(meshes.make([0.30, 0.28, 0.43 * width], dark, shape: .taper, at: [0, 0.78, 0]))
		body.addChild(meshes.make([0.07, 0.24, 0.28], cloth, at: [0.17, 0.78, 0]))
		head.position = [0, 1.55, 0]
		body.addChild(head)
		head.addChild(meshes.make([0.34, 0.37, 0.35], character == .sektor ? cloth : dark, shape: .taper, at: [0, 0.16, 0]))
		head.addChild(meshes.make([0.03, 0.12, 0.29], skin, at: [0.177, 0.22, 0]))
		head.addChild(meshes.make([0.09, 0.18, 0.33], cloth, shape: .taper, at: [0.2, 0.09, 0]))
		for z: Float in [-0.09, 0.09] {
			head.addChild(meshes.make([0.014, 0.033, 0.068], eye, at: [0.201, 0.235, z]))
		}
		for (arm, elbow, z) in [(nearArm, nearElbow, Float(0.29)), (farArm, farElbow, Float(-0.29))] {
			arm.position = [0, 1.42, z]
			body.addChild(arm)
			arm.addChild(meshes.make([0.18, 0.38, 0.19], character == .sektor ? steel : skin, shape: .taper, at: [0, -0.19, 0]))
			arm.addChild(meshes.make([0.25, 0.16, 0.25], cloth, shape: .taper, at: [0, -0.04, 0]))
			elbow.position = [0, -0.38, 0]
			arm.addChild(elbow)
			elbow.addChild(meshes.make([0.17, 0.33, 0.20], cloth, shape: .taper, at: [0, -0.165, 0]))
			elbow.addChild(meshes.make([0.19, 0.14, 0.21], dark, at: [0.02, -0.36, 0]))
		}
		for (leg, knee, z) in [(nearLeg, nearKnee, Float(0.155)), (farLeg, farKnee, Float(-0.155))] {
			leg.position = [0, 0.90, z]
			body.addChild(leg)
			leg.addChild(meshes.make([0.23, 0.43, 0.25], dark, shape: .taper, at: [0, -0.215, 0]))
			leg.addChild(meshes.make([0.07, 0.33, 0.27], cloth, at: [0.1, -0.19, 0]))
			knee.position = [0, -0.43, 0]
			leg.addChild(knee)
			knee.addChild(meshes.make([0.20, 0.39, 0.22], cloth, shape: .taper, at: [0, -0.19, 0]))
			knee.addChild(meshes.make([0.32, 0.13, 0.24], dark, at: [0.07, -0.40, 0]))
		}
		if character == .jade {
			let staff = Entity()
			staff.position = [0.03, -0.37, 0.01]
			staff.addChild(meshes.make([1.45, 0.045, 0.045], steel))
			for x: Float in [-0.70, 0.70] { staff.addChild(meshes.make([0.12, 0.065, 0.065], cloth, at: [x, 0, 0])) }
			nearElbow.addChild(staff)
			self.staff = staff
		} else if character == .sektor {
			body.addChild(meshes.make([0.24, 0.25, 0.34], steel, shape: .taper, at: [-0.23, 1.28, 0]))
			body.addChild(meshes.make([0.20, 0.25, 0.23], cloth, at: [0.05, 1.58, -0.32]))
			body.addChild(meshes.make([0.015, 0.08, 0.10], dark, at: [0.16, 1.58, -0.32]))
			head.addChild(meshes.make([0.08, 0.045, 0.34], eye, at: [0.21, 0.21, 0]))
		}
	}

	func update(_ fighter: borrowing Fighter, frame: Int, fraction: Float = 0) {
		let move = fighter.move, pose = fighter.pose, caughtBy = fighter.caughtBy
		let moveFrame = fighter.moveFrame, health = fighter.health
		let time = Float(frame) + fraction
		let x = min(Float(Fight.edge), max(-Float(Fight.edge), Float(fighter.x) + Float(fighter.vx) * fraction))
		root.position = [x / 256, max(0, Float(fighter.y) + Float(fighter.vy) * fraction) / 256, 0]
		root.orientation = simd_quatf(angle: fighter.facing < 0 ? .pi : 0, axis: [0, 1, 0])
		root.isEnabled = !(move.isTeleport && moveFrame >= 5 && moveFrame < 8)
		body.position = [0, 0, 0]
		body.orientation = simd_quatf(angle: 0, axis: [0, 0, 1])
		var armA: Float = 0.38, armB: Float = 0.55, elbowA: Float = 1.1, elbowB: Float = 0.9
		var legA: Float = 0.16, legB: Float = -0.16, kneeA: Float = -0.18, kneeB: Float = -0.12
		var staffAngle: Float = 0
		let breath = sin(time * 0.055) * 0.012
		if fighter.crouching {
			body.position.y = -0.35
			legA = 0.95; legB = 0.95; kneeA = -1.45; kneeB = -1.45
		} else if pose == .walk || pose == .dash {
			let stride = sin(time * (pose == .dash ? 0.46 : 0.28))
			legA = stride * 0.6; legB = -stride * 0.6
			kneeA = -max(0, -stride) * 0.65; kneeB = -max(0, stride) * 0.65
			body.position.y = abs(stride) * 0.035
		} else if fighter.airborne {
			legA = 0.70; legB = -0.55; kneeA = -1.1; kneeB = -0.8
		} else { body.position.y = breath }
		if pose == .guard {
			armA = 1.35; armB = 1.25; elbowA = 1.20; elbowB = 1.35
		}
		if move != .none {
			let data = move.data
			let elapsed = Float(moveFrame) + fraction
			let strike: Float = elapsed <= Float(data.startup) ? elapsed / Float(max(1, data.startup))
				: max(0, 1 - (elapsed - Float(data.startup + data.active)) / Float(max(1, data.recovery)))
			if move.isKick {
				legA = 0.2 + strike * 1.45; kneeA = -0.1 * (1 - strike)
				body.orientation = simd_quatf(angle: -0.12 * strike, axis: [0, 0, 1])
			} else if move == .uppercut || move == .string212 || move == .teleportUppercut {
				armA = 0.4 + strike * 2.3; elbowA = 0.8 * (1 - strike)
			} else if move.isProjectile {
				armA = 0.4 + strike; elbowA = 0.9 * (1 - strike)
				armB = 0.7 + strike * 0.5; elbowB = 0.8 * (1 - strike)
			} else {
				let far = move == .punch2 || move == .string11 || move == .string21 || move == .air2
				if far { armB = 0.55 + strike; elbowB = 0.9 * (1 - strike) }
				else { armA = 0.38 + strike * 1.17; elbowA = 1.1 * (1 - strike) }
			}
			staffAngle = -strike * 1.5
		}
		if pose == .hit {
			body.orientation = simd_quatf(angle: -0.17, axis: [0, 0, 1])
			armA = -0.5; armB = -0.35; elbowA = 0.3; elbowB = 0.3
		}
		if pose == .down || health == 0 {
			body.position = [0, 0.18, 0]
			body.orientation = simd_quatf(angle: -.pi / 2, axis: [0, 0, 1])
			armA = 0.3; armB = -0.4; legA = 0.1; legB = -0.2
		}
		frost.isEnabled = pose == .frozen && caughtBy == .ice
		rotate(nearArm, armA); rotate(farArm, armB)
		rotate(nearElbow, elbowA); rotate(farElbow, elbowB)
		rotate(nearLeg, legA); rotate(farLeg, legB)
		rotate(nearKnee, kneeA); rotate(farKnee, kneeB)
		if let staff { rotate(staff, staffAngle) }
	}

	private func rotate(_ entity: Entity, _ angle: Float) {
		entity.orientation = simd_quatf(angle: angle, axis: [0, 0, 1])
	}
}
