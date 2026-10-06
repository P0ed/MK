import RealityKit
import UIKit
import simd

enum Shape { case box, taper, diamond, octagon, sphere, fan, ring }

@MainActor
final class Meshes {
	private let box = MeshResource.generateBox(size: 1)
	private let taper: MeshResource
	private let diamond: MeshResource
	private let octagon: MeshResource
	private let sphere = MeshResource.generateSphere(radius: 0.5)
	private let fan: MeshResource
	private let ring: MeshResource

	init() {
		let a: Float = 0.5, b: Float = 0.42
		let vertices: [SIMD3<Float>] = [
			[-a, -a, -a], [a, -a, -a], [b, a, -b], [-b, a, -b],
			[-a, -a, a], [a, -a, a], [b, a, b], [-b, a, b],
		]
		taper = Self.mesh([[4, 5, 6, 7], [1, 0, 3, 2], [5, 1, 2, 6], [0, 4, 7, 3], [3, 7, 6, 2], [0, 1, 5, 4]].map { face in face.map { vertices[$0] } })
		var faces: [[SIMD3<Float>]] = []
		for x: Float in [-1, 1] {
			for y: Float in [-1, 1] {
				for z: Float in [-1, 1] {
					let face: [SIMD3<Float>] = [[x * 0.5, 0, 0], [0, y * 0.5, 0], [0, 0, z * 0.5]]
					faces.append(x * y * z > 0 ? face : face.reversed())
				}
			}
		}
		diamond = Self.mesh(faces)
		faces = []
		let octagonRing: [SIMD3<Float>] = (0 ..< 8).map { i in
			let angle = Float(i) * .pi / 4
			return [cos(angle) * 0.5, -0.5, sin(angle) * 0.5]
		}
		for i in 0 ..< 8 {
			let next = (i + 1) % 8
			let top = octagonRing[i] + SIMD3<Float>(0, 1, 0)
			let topNext = octagonRing[next] + SIMD3<Float>(0, 1, 0)
			faces.append([octagonRing[i], top, topNext, octagonRing[next]])
			faces.append([[0, 0.5, 0], topNext, top])
			faces.append([[0, -0.5, 0], octagonRing[i], octagonRing[next]])
		}
		octagon = Self.mesh(faces)
		// A folding fan opens from the wrist. Its facets catch the arena light,
		// while the same cached mesh serves both held and thrown fans.
		faces = []
		for i in 0 ..< 8 {
			let first = Float(i) * .pi / 10 + .pi / 10
			let second = Float(i + 1) * .pi / 10 + .pi / 10
			let a = SIMD3<Float>(cos(first), sin(first), 0) * 0.5
			let b = SIMD3<Float>(cos(second), sin(second), 0) * 0.5
			let front = SIMD3<Float>(0, 0, 0.025)
			let back = SIMD3<Float>(0, 0, -0.025)
			faces.append([front, a + front, b + front])
			faces.append([back, b + back, a + back])
			faces.append([a + back, b + back, b + front, a + front])
		}
		fan = Self.mesh(faces)
		faces = []
		for i in 0 ..< 24 {
			let angle = Float(i) * .pi / 12
			let next = Float(i + 1) * .pi / 12
			let a = SIMD3<Float>(cos(angle) * 0.5, 0, sin(angle) * 0.5)
			let b = SIMD3<Float>(cos(next) * 0.5, 0, sin(next) * 0.5)
			let c = a * 0.88, d = b * 0.88
			let up = SIMD3<Float>(0, 0.015, 0)
			faces.append([a + up, c + up, d + up, b + up])
			faces.append([a - up, b - up, d - up, c - up])
			faces.append([a - up, a + up, b + up, b - up])
			faces.append([c + up, c - up, d - up, d + up])
		}
		ring = Self.mesh(faces)
	}

	private static func mesh(_ faces: [[SIMD3<Float>]]) -> MeshResource {
		var positions: [SIMD3<Float>] = []
		var normals: [SIMD3<Float>] = []
		var indices: [UInt32] = []
		for face in faces {
			let offset = UInt32(positions.count)
			let normal = simd_normalize(simd_cross(face[1] - face[0], face[2] - face[0]))
			positions.append(contentsOf: face)
			normals.append(contentsOf: repeatElement(normal, count: face.count))
			for i in 1 ..< face.count - 1 { indices += [offset, offset + UInt32(i), offset + UInt32(i + 1)] }
		}
		var descriptor = MeshDescriptor()
		descriptor.positions = .init(positions)
		descriptor.normals = .init(normals)
		descriptor.primitives = .triangles(indices)
		return (try? MeshResource.generate(from: [descriptor])) ?? .generateBox(size: 1)
	}

	func make(_ size: SIMD3<Float>, _ material: any Material, shape: Shape = .box, at position: SIMD3<Float> = .zero) -> ModelEntity {
		let mesh: MeshResource
		switch shape {
		case .box: mesh = box
		case .taper: mesh = taper
		case .diamond: mesh = diamond
		case .octagon: mesh = octagon
		case .sphere: mesh = sphere
		case .fan: mesh = fan
		case .ring: mesh = ring
		}
		let entity = ModelEntity(mesh: mesh, materials: [material])
		entity.scale = size
		entity.position = position
		return entity
	}

	func makeFan(size: Float, color: UIColor) -> Entity {
		let root = Entity()
		let silk = SimpleMaterial(color: color, roughness: 0.5, isMetallic: false)
		let steel = SimpleMaterial(color: .lightGray, roughness: 0.35, isMetallic: true)
		root.addChild(make([size, size, size], silk, shape: .fan))
		for i in 0 ... 8 {
			let angle = Float(i) * .pi / 10 + .pi / 10
			let rib = make([size * 0.51, size * 0.025, size * 0.025], steel,
				at: [cos(angle) * size * 0.25, sin(angle) * size * 0.25, size * 0.03])
			rib.orientation = simd_quatf(angle: angle, axis: [0, 0, 1])
			root.addChild(rib)
		}
		root.addChild(make([size * 0.11, size * 0.07, size * 0.08], steel, shape: .diamond))
		return root
	}

	func makeNet(size: SIMD2<Float>) -> Entity {
		let root = Entity()
		let wire = UnlitMaterial(color: UIColor(red: 0.20, green: 0.91, blue: 0.36, alpha: 0.85))
		for i in 0 ... 5 {
			let x = (Float(i) / 5 - 0.5) * size.x
			root.addChild(make([0.016, size.y, 0.016], wire, at: [x, 0, 0]))
		}
		for i in 0 ... 8 {
			let y = (Float(i) / 8 - 0.5) * size.y
			root.addChild(make([size.x, 0.016, 0.016], wire, at: [0, y, 0]))
		}
		return root
	}
}
