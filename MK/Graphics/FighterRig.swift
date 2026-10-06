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
	private let snare = Entity()
	private let vapor = Entity()
	private let fanWind = Entity()
	private var smokeWisps: [Entity] = []
	private var staff: Entity?
	private var nearFan: Entity?
	private var farFan: Entity?
	private let character: Character
	private var effects: FighterEffects?
	private var lastTime: Float?
	private var lastMove: MoveID = .none
	private var lastCaughtBy: MoveID = .none
	private var lastAirborne = false
	private var jumpedAt: Float = -100
	private var landedAt: Float = -100
	private var pulledAt: Float = -100
	private var pulledFrom = SIMD3<Float>.zero
	private var teleportOrigin = SIMD3<Float>.zero
	private var sample = RigSample()
	private var angles: InlineArray<10, Float> = .init(repeating: 0)
	private var bodyOpacity: Float = 1
	private var frostOpacity: Float = 0
	private var netOpacity: Float = 0
	private var windOpacity: Float = 0
	private var vaporOpacity: Float = 0

	init(_ character: Character, meshes: Meshes) {
		self.character = character
		let robot = character == .sektor || character == .cyrax
		let female = character == .jade || character == .kitana
		let cloth = SimpleMaterial(color: character.color, roughness: robot ? 0.45 : 0.8, isMetallic: robot)
		let dark = SimpleMaterial(color: UIColor(white: 0.07, alpha: 1), roughness: 0.9, isMetallic: false)
		let skin = SimpleMaterial(color: UIColor(red: 0.68, green: 0.48, blue: 0.34, alpha: 1), roughness: 0.9, isMetallic: false)
		let steel = SimpleMaterial(color: UIColor(white: 0.38, alpha: 1), roughness: 0.65, isMetallic: true)
		let eye = UnlitMaterial(color: robot ? .yellow : UIColor(white: 0.95, alpha: 1))
		frost = meshes.make([0.62, 1.72, 0.76], UnlitMaterial(color: UIColor(red: 0.3, green: 0.8, blue: 1, alpha: 0.22)), shape: .diamond, at: [0, 0.95, 0])
		frost.isEnabled = false
		root.addChild(body)
		body.components.set(OpacityComponent(opacity: 1))
		nearArm.name = "nearArm"; farArm.name = "farArm"
		nearElbow.name = "nearElbow"; farElbow.name = "farElbow"
		nearLeg.name = "nearLeg"; farLeg.name = "farLeg"
		nearKnee.name = "nearKnee"; farKnee.name = "farKnee"
		root.addChild(frost)
		root.addChild(snare)
		for z: Float in [-0.40, 0.40] {
			let net = meshes.makeNet(size: [0.78, 1.65])
			net.position = [0, 1.02, z]
			snare.addChild(net)
		}
		snare.isEnabled = false
		root.addChild(vapor)
		let smoke = SimpleMaterial(color: UIColor(white: 0.58, alpha: 0.25), roughness: 1, isMetallic: false)
		for i in 0 ..< 5 {
			let wisp = meshes.make([0.38, 0.47, 0.38], smoke, shape: .sphere)
			vapor.addChild(wisp)
			smokeWisps.append(wisp)
			wisp.position = [Float(i % 2) * 0.3 - 0.15, 0.35 + Float(i) * 0.31, Float(i % 3 - 1) * 0.26]
		}
		vapor.isEnabled = false
		root.addChild(fanWind)
		fanWind.position = [0.50, 1.12, 0]
		for i in 0 ..< 6 {
			let angle = Float(i) * .pi / 3
			let gust = meshes.make([0.5, 0.035, 0.06], UnlitMaterial(color: UIColor(red: 0.3, green: 0.7, blue: 1, alpha: 0.65)), shape: .diamond,
				at: [cos(angle) * 0.33, sin(angle) * 0.65, 0.10])
			gust.orientation = simd_quatf(angle: angle + .pi / 2, axis: [0, 0, 1])
			fanWind.addChild(gust)
		}
		fanWind.isEnabled = false
		let width: Float = female ? 0.83 : robot ? 1.07 : 1
		body.addChild(meshes.make([0.37 * width, 0.55, 0.60 * width], dark, shape: .taper, at: [0, 1.2, 0]))
		body.addChild(meshes.make([0.41 * width, 0.44, 0.62 * width], character == .liuKang ? skin : cloth, shape: .taper, at: [0.015, 1.25, 0]))
		body.addChild(meshes.make([0.39 * width, 0.12, 0.54 * width], dark, at: [0, 0.96, 0]))
		body.addChild(meshes.make([0.025, 0.09, 0.12], steel, at: [0.21, 0.96, 0]))
		body.addChild(meshes.make([0.30, 0.28, 0.43 * width], dark, shape: .taper, at: [0, 0.78, 0]))
		body.addChild(meshes.make([0.07, 0.24, 0.28], cloth, at: [0.17, 0.78, 0]))
		head.position = [0, 1.55, 0]
		body.addChild(head)
		head.addChild(meshes.make([0.34, 0.37, 0.35], robot ? cloth : character == .liuKang ? skin : dark, shape: .taper, at: [0, 0.16, 0]))
		head.addChild(meshes.make([0.03, character == .liuKang ? 0.26 : 0.12, 0.29], robot ? steel : skin, at: [0.177, 0.18, 0]))
		head.addChild(meshes.make([0.09, character == .liuKang ? 0.11 : 0.18, 0.33], character == .liuKang ? skin : cloth, shape: .taper, at: [0.2, 0.09, 0]))
		for z: Float in [-0.09, 0.09] {
			head.addChild(meshes.make([0.014, 0.033, 0.068], eye, at: [0.201, 0.235, z]))
		}
		for (arm, elbow, z) in [(nearArm, nearElbow, Float(0.29)), (farArm, farElbow, Float(-0.29))] {
			arm.position = [0, 1.42, z * width]
			body.addChild(arm)
			arm.addChild(meshes.make([0.18 * width, 0.38, 0.19 * width], robot ? steel : skin, shape: .taper, at: [0, -0.19, 0]))
			if character != .liuKang {
				arm.addChild(meshes.make([0.25 * width, 0.16, 0.25 * width], cloth, shape: .taper, at: [0, -0.04, 0]))
			}
			elbow.position = [0, -0.38, 0]
			arm.addChild(elbow)
			elbow.addChild(meshes.make([0.17 * width, 0.33, 0.20 * width], character == .liuKang ? skin : cloth, shape: .taper, at: [0, -0.165, 0]))
			elbow.addChild(meshes.make([0.19, 0.14, 0.21], dark, at: [0.02, -0.36, 0]))
			if character == .liuKang { elbow.addChild(meshes.make([0.19, 0.10, 0.21], cloth, at: [0, -0.28, 0])) }
		}
		for (leg, knee, z) in [(nearLeg, nearKnee, Float(0.155)), (farLeg, farKnee, Float(-0.155))] {
			leg.position = [0, 0.90, z]
			body.addChild(leg)
			leg.addChild(meshes.make([0.23 * width, 0.43, 0.25 * width], female ? skin : dark, shape: .taper, at: [0, -0.215, 0]))
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
		} else if robot {
			body.addChild(meshes.make([0.24, 0.25, 0.34], steel, shape: .taper, at: [-0.23, 1.28, 0]))
			head.addChild(meshes.make([0.08, 0.045, 0.34], eye, at: [0.21, 0.21, 0]))
			for z: Float in [-0.30, 0.30] {
				body.addChild(meshes.make([0.33, 0.28, 0.08], cloth, shape: .taper, at: [0.03, 1.27, z]))
				body.addChild(meshes.make([0.13, 0.045, 0.09], dark, at: [0.03, 1.28, z * 1.18]))
			}
			if character == .cyrax {
				let green = UnlitMaterial(color: UIColor(red: 0.25, green: 0.95, blue: 0.28, alpha: 1))
				body.addChild(meshes.make([0.06, 0.24, 0.36], dark, at: [0.245, 1.27, 0]))
				for z: Float in [-0.12, -0.04, 0.04, 0.12] {
					body.addChild(meshes.make([0.025, 0.17, 0.018], green, at: [0.285, 1.27, z]))
				}
				body.addChild(meshes.make([0.075, 0.14, 0.14], steel, shape: .diamond, at: [0.25, 1.02, 0]))
				for z: Float in [-0.13, 0, 0.13] {
					head.addChild(meshes.make([0.09, 0.45, 0.045], dark, shape: .taper, at: [-0.19, -0.04, z]))
				}
			} else {
				body.addChild(meshes.make([0.20, 0.25, 0.23], cloth, at: [0.05, 1.58, -0.32]))
				body.addChild(meshes.make([0.015, 0.08, 0.10], dark, at: [0.16, 1.58, -0.32]))
			}
		} else if character == .kitana {
			let first = meshes.makeFan(size: 0.90, color: character.color)
			let second = meshes.makeFan(size: 0.82, color: character.color)
			first.position = [0.06, -0.38, 0.08]
			second.position = [0.06, -0.38, -0.08]
			nearElbow.addChild(first); farElbow.addChild(second)
			nearFan = first; farFan = second
			head.addChild(meshes.make([0.17, 0.57, 0.20], dark, shape: .taper, at: [-0.24, -0.13, 0]))
			head.addChild(meshes.make([0.37, 0.05, 0.37], cloth, at: [0, 0.30, 0]))
			for z: Float in [-0.21, 0.21] {
				body.addChild(meshes.make([0.08, 0.48, 0.14], cloth, shape: .taper, at: [0.17, 0.66, z]))
			}
		} else if character == .liuKang {
			head.addChild(meshes.make([0.34, 0.08, 0.36], dark, shape: .taper, at: [-0.015, 0.34, 0]))
			head.addChild(meshes.make([0.07, 0.31, 0.36], dark, at: [-0.17, 0.19, 0]))
			head.addChild(meshes.make([0.37, 0.055, 0.38], cloth, at: [0, 0.27, 0]))
			for z: Float in [-0.07, 0.07] {
				let ribbon = meshes.make([0.43, 0.045, 0.055], cloth, at: [-0.32, 0.22, z])
				ribbon.orientation = simd_quatf(angle: 0.22, axis: [0, 0, 1])
				head.addChild(ribbon)
			}
			body.addChild(meshes.make([0.40, 0.13, 0.60], cloth, at: [0.02, 0.97, 0]))
			for z: Float in [-0.18, 0.18] {
				body.addChild(meshes.make([0.05, 0.18, 0.23], skin, shape: .taper, at: [0.24, 1.33, z]))
			}
		} else if character == .smoke {
			body.addChild(meshes.make([0.44, 0.16, 0.59], cloth, shape: .taper, at: [0, 1.46, 0]))
			body.addChild(meshes.make([0.05, 0.73, 0.45], dark, shape: .taper, at: [-0.24, 1.08, 0]))
		}
		effects = FighterEffects(character: character, meshes: meshes, owner: root, body: body)
	}

	func resetAnimation() {
		lastTime = nil; lastMove = .none; lastCaughtBy = .none; lastAirborne = false
		jumpedAt = -100; landedAt = -100; pulledAt = -100
		bodyOpacity = 1; frostOpacity = 0; netOpacity = 0; windOpacity = 0; vaporOpacity = 0
		effects?.reset()
	}

	func update(_ fighter: borrowing Fighter, frame: Int, fraction: Float = 0) {
		let move = fighter.move, pose = fighter.pose, caughtBy = fighter.caughtBy
		let moveFrame = fighter.moveFrame, health = fighter.health
		let data = fighter.moveData
		let airborne = fighter.airborne, crouching = fighter.crouching
		let verticalSpeed = fighter.vy
		let time = Float(frame) + fraction
		if let lastTime, time < lastTime { resetAnimation() }
		let initialized = lastTime != nil
		let delta = initialized ? min(4, max(0, time - (lastTime ?? time))) : 0
		let elapsed = Float(moveFrame) + fraction
		let x = min(Float(Fight.edge), max(-Float(Fight.edge), Float(fighter.x) + Float(fighter.vx) * fraction))
		let physicalPosition = SIMD3<Float>(x / 256, max(0, Float(fighter.y) + Float(fighter.vy) * fraction) / 256, 0)
		if move.isTeleport, move != lastMove { teleportOrigin = initialized ? root.position : physicalPosition }
		if pose == .frozen, caughtBy == .spear, lastCaughtBy != .spear {
			pulledFrom = initialized ? root.position : physicalPosition; pulledAt = time
		}
		var position = physicalPosition
		if move.isTeleport {
			let relocation: Float = move == .smokeTeleport ? 12 : 8
			let duration = min(4, max(2, Float(data.startup) - relocation))
			if elapsed >= relocation {
				let travel = smooth((elapsed - relocation) / duration)
				position = teleportOrigin + (physicalPosition - teleportOrigin) * travel
				position.y += sin(travel * .pi) * 0.12
			}
		} else if caughtBy == .spear, pose == .frozen, time - pulledAt < 6 {
			position = pulledFrom + (physicalPosition - pulledFrom) * smooth((time - pulledAt) / 6)
		}
		root.position = position
		let facing = simd_quatf(angle: fighter.facing < 0 ? .pi : 0, axis: [0, 1, 0])
		root.orientation = initialized ? simd_slerp(sample.orientation, facing, 1 - exp(-delta * 0.75)) : facing
		root.isEnabled = true
		var bodyY: Float = 0, bodyTilt: Float = 0
		if initialized, airborne, !lastAirborne { jumpedAt = time }
		if initialized, !airborne, lastAirborne { landedAt = time + (caughtBy == .spear ? 6 : 0) }
		var armA: Float = 0.38, armB: Float = 0.55, elbowA: Float = 1.1, elbowB: Float = 0.9
		var legA: Float = 0.16, legB: Float = -0.16, kneeA: Float = -0.18, kneeB: Float = -0.12
		var staffAngle: Float = 0
		var fanAngle: Float = -.pi + 0.15
		let breath = sin(time * 0.055) * 0.012
		if character == .kitana { armA = 0.62; armB = 0.8; elbowA = 0.85; elbowB = 0.7 }
		if character == .liuKang { armA = 0.72; armB = 0.9; elbowA = 1.0; elbowB = 1.3; legA = 0.27; legB = -0.27 }
		if character == .smoke { armA = 0.55; armB = 0.75; legA = 0.25; legB = -0.25 }
		if crouching {
			bodyY = -0.35
			legA = 0.95; legB = 0.95; kneeA = -1.45; kneeB = -1.45
		} else if pose == .walk || pose == .dash {
			let stride = sin(time * (pose == .dash ? 0.46 : 0.28))
			legA = stride * 0.6; legB = -stride * 0.6
			kneeA = -max(0, -stride) * 0.65; kneeB = -max(0, stride) * 0.65
			bodyY = abs(stride) * 0.035
		} else if airborne {
			legA = 0.70; legB = -0.55; kneeA = -1.1; kneeB = -0.8
			bodyY = -0.08 * (1 - smooth((time - jumpedAt) / 4))
		} else { bodyY = breath }
		if pose == .guard {
			armA = 1.35; armB = 1.25; elbowA = 1.20; elbowB = 1.35
		}
		if move != .none {
			let strike: Float = elapsed <= Float(data.startup) ? smooth(elapsed / Float(max(1, data.startup)))
				: 1 - smooth((elapsed - Float(data.startup + data.active)) / Float(max(1, data.recovery)))
			if move == .flyingKick {
				legA = 0.5 + strike * 1.1; kneeA = 0
				legB = -0.65; kneeB = -1.4
				armA = -0.2; armB = 1.15; elbowA = 1.6; elbowB = 1.5
				bodyTilt = -0.23 * strike
			} else if move == .fanLift {
				armA = 0.8 + strike * 1.65; armB = 0.7 + strike * 1.7
				elbowA = 0.25; elbowB = 0.35
				fanAngle = -.pi + sin(elapsed * 0.6) * 0.45
				legA = 0.45; legB = -0.25
			} else if move == .bomb {
				bodyY -= strike * 0.16
				armA = 0.2 + strike * 0.6; elbowA = 0.2
				armB = 0.75; elbowB = 1.2
			} else if move == .net {
				armA = 0.35 + strike * 0.65; armB = 0.35 + strike * 0.65
				elbowA = 1.0; elbowB = 1.0
			} else if move == .fan {
				armA = 0.55 + strike * 1.0; elbowA = 0.15
				armB = 0.8; elbowB = 1.2
				fanAngle = -.pi + strike * 0.8
			} else if move == .smokeCloud {
				armA = 0.5 + strike * 0.9; elbowA = 0.1
				armB = -0.2; elbowB = 1.7
			} else if move == .smokeTeleport {
				armA = 1.0; armB = 1.7; elbowA = 0.4; elbowB = 0.4
				legA = 1.35; kneeA = -0.25; legB = -0.5; kneeB = -1.25
			} else if move == .fireball {
				armA = 0.5 + strike * 1.0; armB = 0.7 + strike * 0.8
				elbowA = 0.1; elbowB = 0.2
				legA = 0.55; legB = -0.45; kneeA = -0.5; kneeB = -0.3
			} else if move.isKick {
				legA = 0.2 + strike * 1.45; kneeA = -0.1 * (1 - strike)
				bodyTilt = -0.12 * strike
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
			bodyTilt = airborne ? -0.38 : -0.17
			armA = -0.5; armB = -0.35; elbowA = 0.3; elbowB = 0.3
		}
		if pose == .frozen {
			bodyY = 0
			armA = 0.18; armB = 0.18; elbowA = 0.8; elbowB = 0.8
			legA = 0; legB = 0; kneeA = 0; kneeB = 0
		}
		if pose == .down || health == 0 {
			bodyY = airborne ? 0 : 0.18
			bodyTilt = airborne ? (verticalSpeed >= 0 ? -0.49 : -0.85) : -.pi / 2
			armA = 0.3; armB = -0.4; legA = 0.1; legB = -0.2
		}
		if !airborne, health > 0, pose != .down {
			bodyY -= sin(smooth((time - landedAt) / 9) * .pi) * 0.10
		}
		let poseRate: Float = pose == .down || health == 0 ? 0.20 : pose == .hit || pose == .frozen ? 0.95 : move != .none ? 0.8 : 0.38
		let blend = initialized ? 1 - exp(-delta * poseRate) : 1
		let targets: InlineArray<10, Float> = [armA, armB, elbowA, elbowB, legA, legB, kneeA, kneeB, staffAngle, fanAngle]
		for i in angles.indices { angles[i] += (targets[i] - angles[i]) * blend }
		sample.bodyPosition.y += (bodyY - sample.bodyPosition.y) * blend
		sample.tilt += (bodyTilt - sample.tilt) * blend
		body.position = sample.bodyPosition
		body.orientation = simd_quatf(angle: sample.tilt, axis: [0, 0, 1])
		var visible: Float = 1
		if move.isTeleport {
			let relocation: Float = move == .smokeTeleport ? 12 : 8
			visible = elapsed < 4 ? 1 - smooth(elapsed / 4) : smooth((elapsed - relocation - 2) / 4)
		}
		let effectBlend = initialized ? 1 - exp(-delta * 0.75) : 1
		bodyOpacity += (visible - bodyOpacity) * effectBlend
		setOpacity(body, bodyOpacity)
		frostOpacity += ((pose == .frozen && caughtBy == .ice ? 1 : 0) - frostOpacity) * effectBlend
		netOpacity += ((pose == .frozen && caughtBy == .net ? 1 : 0) - netOpacity) * effectBlend
		setOpacity(frost, frostOpacity)
		setOpacity(snare, netOpacity)
		let smokeTeleport = move == .smokeTeleport && moveFrame >= 3 && moveFrame <= 18
		let vaporTarget: Float = (character == .smoke && health > 0) || smokeTeleport || (pose == .frozen && caughtBy == .smokeCloud) ? 1 : 0
		vaporOpacity += (vaporTarget - vaporOpacity) * effectBlend
		setOpacity(vapor, vaporOpacity)
		for i in smokeWisps.indices {
			let phase = time * 0.045 + Float(i) * 1.7
			smokeWisps[i].position.x = sin(phase) * (smokeTeleport ? 0.35 : 0.18)
			smokeWisps[i].position.y = 0.25 + Float(i) * 0.31 + sin(phase * 0.7) * 0.08
			let swell: Float = smokeTeleport ? 1.85 : 0.65 + sin(phase) * 0.16
			smokeWisps[i].scale = [0.38 * swell, 0.47 * swell, 0.38 * swell]
		}
		let windTarget: Float = move == .fanLift ? smooth((elapsed - Float(data.startup) + 4) / 4) * (1 - smooth((elapsed - Float(data.startup + data.active)) / 8)) : 0
		windOpacity += (windTarget - windOpacity) * effectBlend
		setOpacity(fanWind, windOpacity)
		fanWind.orientation = simd_quatf(angle: time * 0.22, axis: [0, 0, 1])
		rotate(nearArm, angles[0]); rotate(farArm, angles[1])
		rotate(nearElbow, angles[2]); rotate(farElbow, angles[3])
		rotate(nearLeg, angles[4]); rotate(farLeg, angles[5])
		rotate(nearKnee, angles[6]); rotate(farKnee, angles[7])
		if let staff { rotate(staff, angles[8]) }
		if let nearFan { rotate(nearFan, angles[9]) }
		if let farFan { rotate(farFan, angles[9] - 0.3) }
		sample.position = root.position; sample.orientation = root.orientation; sample.time = time
		for i in sample.joints.indices { sample.joints[i] = angles[i] }
		effects?.update(owner: root, sample: sample, move: move, elapsed: elapsed, data: data, pose: pose, caughtBy: caughtBy,
			landingAge: time - landedAt, teleportOrigin: teleportOrigin, alive: health > 0)
		lastTime = time; lastMove = move; lastCaughtBy = caughtBy; lastAirborne = airborne
	}

	private func setOpacity(_ entity: Entity, _ opacity: Float) {
		entity.isEnabled = opacity > 0.002
		entity.components[OpacityComponent.self] = .init(opacity: min(1, max(0, opacity)))
	}

	private func smooth(_ value: Float) -> Float {
		let t = min(1, max(0, value)); return t * t * (3 - 2 * t)
	}

	private func rotate(_ entity: Entity, _ angle: Float) {
		entity.orientation = simd_quatf(angle: angle, axis: [0, 0, 1])
	}
}
