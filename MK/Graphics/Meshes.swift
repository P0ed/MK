import RealityKit
import UIKit
import simd

enum Shape { case box, taper, diamond, octagon }

@MainActor
final class Meshes {
	private let box = MeshResource.generateBox(size: 1)
	private let taper: MeshResource
	private let diamond: MeshResource
	private let octagon: MeshResource

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
		let ring: [SIMD3<Float>] = (0 ..< 8).map { i in
			let angle = Float(i) * .pi / 4
			return [cos(angle) * 0.5, -0.5, sin(angle) * 0.5]
		}
		for i in 0 ..< 8 {
			let next = (i + 1) % 8
			let top = ring[i] + SIMD3<Float>(0, 1, 0)
			let topNext = ring[next] + SIMD3<Float>(0, 1, 0)
			faces.append([ring[i], top, topNext, ring[next]])
			faces.append([[0, 0.5, 0], topNext, top])
			faces.append([[0, -0.5, 0], ring[i], ring[next]])
		}
		octagon = Self.mesh(faces)
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
		}
		let entity = ModelEntity(mesh: mesh, materials: [material])
		entity.scale = size
		entity.position = position
		return entity
	}
}
