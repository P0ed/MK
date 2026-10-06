import Foundation
import XCTest
@testable import SoundSynthesis

final class SoundBankTests: XCTestCase {
	func testWAVFormatAndLengths() {
		for effect in SoundEffect.allCases {
			let data = SoundBank.wav(for: effect)
			let frames = Int((effect.duration * Double(SoundBank.sampleRate)).rounded())
			XCTAssertEqual(String(decoding: data[0 ..< 4], as: UTF8.self), "RIFF")
			XCTAssertEqual(String(decoding: data[8 ..< 16], as: UTF8.self), "WAVEfmt ")
			XCTAssertEqual(String(decoding: data[36 ..< 40], as: UTF8.self), "data")
			XCTAssertEqual(integer(data, at: 4, bytes: 4), data.count - 8)
			XCTAssertEqual(integer(data, at: 20, bytes: 2), 1)
			XCTAssertEqual(integer(data, at: 22, bytes: 2), 1)
			XCTAssertEqual(integer(data, at: 24, bytes: 4), 48_000)
			XCTAssertEqual(integer(data, at: 28, bytes: 4), 96_000)
			XCTAssertEqual(integer(data, at: 32, bytes: 2), 2)
			XCTAssertEqual(integer(data, at: 34, bytes: 2), 16)
			XCTAssertEqual(integer(data, at: 40, bytes: 4), frames * 2)
			XCTAssertEqual(data.count, 44 + frames * 2)
		}
	}

	func testDeterministicDistinctEffectsWithHeadroomAndQuietEdges() {
		var unique = Set<Data>()
		for effect in SoundEffect.allCases {
			let first = SoundBank.wav(for: effect)
			XCTAssertEqual(first, SoundBank.wav(for: effect), effect.rawValue)
			XCTAssertTrue(unique.insert(first).inserted, effect.rawValue)
			let samples = SoundBank.samples(for: effect)
			let peak = samples.map { abs(Int($0)) }.max()!
			XCTAssertGreaterThan(peak, 8_000, effect.rawValue)
			XCTAssertLessThan(peak, 30_000, effect.rawValue)
			XCTAssertEqual(samples.first, 0)
			XCTAssertEqual(samples.last, 0)
			let tail = samples.suffix(240).map { Double($0) / Double(Int16.max) }
			let rms = sqrt(tail.reduce(0) { $0 + $1 * $1 } / Double(tail.count))
			XCTAssertLessThan(rms, 0.005, effect.rawValue)
		}
	}

	private func integer(_ data: Data, at offset: Int, bytes: Int) -> Int {
		(0 ..< bytes).reduce(0) { $0 | Int(data[offset + $1]) << ($1 * 8) }
	}
}
