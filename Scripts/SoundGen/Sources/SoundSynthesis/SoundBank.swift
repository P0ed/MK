import Foundation

public enum SoundEffect: String, CaseIterable, Sendable {
	case menu, swing, punch, kick, block, spear, ice, rang, rocket, explode, teleport, round
	case net, bomb, fan, smoke, fire

	public var duration: Double {
		switch self {
		case .menu: 0.085
		case .swing: 0.16
		case .punch: 0.24
		case .kick: 0.30
		case .block: 0.22
		case .spear: 0.34
		case .ice: 0.42
		case .rang: 0.34
		case .rocket: 0.46
		case .explode: 0.62
		case .teleport: 0.38
		case .round: 0.74
		case .net: 0.32
		case .bomb: 0.28
		case .fan: 0.34
		case .smoke: 0.44
		case .fire: 0.44
		}
	}

	var peak: Double {
		switch self {
		case .menu: 0.42
		case .swing: 0.55
		case .punch, .kick, .explode, .round: 0.90
		default: 0.78
		}
	}
}

/// All assets use one format so the game's preloaded player nodes can share a mixer.
public enum SoundBank {
	public static let sampleRate = 48_000

	public static func samples(for effect: SoundEffect) -> [Int16] {
		let seed = UInt64(SoundEffect.allCases.firstIndex(of: effect)! + 1)
		var noise = Noise(seed: seed)
		var highPass = HighPass(cutoff: 28)
		let count = Int((effect.duration * Double(sampleRate)).rounded())
		var waveform = [Double]()
		waveform.reserveCapacity(count)
		var peak = 0.0
		for frame in 0 ..< count {
			let time = Double(frame) / Double(sampleRate)
			let bands = noise.next()
			let raw = synthesize(effect, time: time, noise: bands)
			// Remove DC/inaudible rumble, then add gentle analog-style saturation.
			let saturated = tanh(highPass.process(raw) * 1.35)
			let attack = smoothstep(time / 0.0006)
			let release = smoothstep(Double(count - 1 - frame) / (Double(sampleRate) * 0.018))
			let sample = saturated * attack * release
			waveform.append(sample)
			peak = max(peak, abs(sample))
		}
		let gain = peak > 0 ? effect.peak / peak : 0
		return waveform.map { Int16(($0 * gain * Double(Int16.max)).rounded()) }
	}

	public static func wav(for effect: SoundEffect) -> Data {
		let pcm = samples(for: effect)
		let byteCount = UInt32(pcm.count * MemoryLayout<Int16>.size)
		var data = Data()
		data.reserveCapacity(44 + Int(byteCount))
		data.append(contentsOf: "RIFF".utf8)
		data.appendLE(byteCount + 36)
		data.append(contentsOf: "WAVEfmt ".utf8)
		data.appendLE(UInt32(16))
		data.appendLE(UInt16(1)) // Linear PCM.
		data.appendLE(UInt16(1)) // Mono.
		data.appendLE(UInt32(sampleRate))
		data.appendLE(UInt32(sampleRate * 2))
		data.appendLE(UInt16(2))
		data.appendLE(UInt16(16))
		data.append(contentsOf: "data".utf8)
		data.appendLE(byteCount)
		for sample in pcm { data.appendLE(sample) }
		return data
	}
}

private extension Data {
	mutating func appendLE<T: FixedWidthInteger>(_ value: T) {
		var littleEndian = value.littleEndian
		Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
	}
}

private let tau = 2 * Double.pi

private func decay(_ time: Double, _ length: Double) -> Double {
	exp(-max(0, time) / length)
}

private func smoothstep(_ value: Double) -> Double {
	let x = min(1, max(0, value))
	return x * x * (3 - 2 * x)
}

private func tone(_ frequency: Double, _ time: Double, phase: Double = 0) -> Double {
	sin(tau * frequency * time + phase)
}

/// Integrating an exponential pitch fall avoids discontinuities between samples.
private func thump(_ time: Double, start: Double, end: Double, fall: Double) -> Double {
	sin(tau * (end * time + (start - end) * fall * (1 - exp(-time / fall))))
}

private struct NoiseBands {
	let low: Double
	let body: Double
	let air: Double
	let crack: Double
}

private struct Noise {
	private var state: UInt64
	private var low = LowPass(cutoff: 170)
	private var body = BandPass(frequency: 820, q: 0.65)
	private var air = BandPass(frequency: 3_300, q: 0.7)
	private var crack = BandPass(frequency: 6_500, q: 0.7)

	init(seed: UInt64) { state = 0xD1B54A32D192ED03 &* seed }

	mutating func next() -> NoiseBands {
		// Fixed-seed xorshift64*: reproducible, with no platform-randomized hash seed.
		state ^= state >> 12
		state ^= state << 25
		state ^= state >> 27
		let bits = state &* 0x2545F4914F6CDD1D
		let white = Double(bits >> 11) / 4_503_599_627_370_496 - 1
		return NoiseBands(low: low.process(white) * 4.0, body: body.process(white),
			air: air.process(white), crack: crack.process(white))
	}
}

private struct LowPass {
	private var memory = 0.0
	private let coefficient: Double
	init(cutoff: Double) { coefficient = 1 - exp(-tau * cutoff / Double(SoundBank.sampleRate)) }
	mutating func process(_ sample: Double) -> Double {
		memory += coefficient * (sample - memory)
		return memory
	}
}

private struct HighPass {
	private var low: LowPass
	init(cutoff: Double) { low = LowPass(cutoff: cutoff) }
	mutating func process(_ sample: Double) -> Double { sample - low.process(sample) }
}

private struct BandPass {
	private let b0: Double
	private let b2: Double
	private let a1: Double
	private let a2: Double
	private var x1 = 0.0
	private var x2 = 0.0
	private var y1 = 0.0
	private var y2 = 0.0

	init(frequency: Double, q: Double) {
		let omega = tau * frequency / Double(SoundBank.sampleRate)
		let alpha = sin(omega) / (2 * q)
		let a0 = 1 + alpha
		b0 = alpha / a0
		b2 = -alpha / a0
		a1 = -2 * cos(omega) / a0
		a2 = (1 - alpha) / a0
	}

	mutating func process(_ sample: Double) -> Double {
		let result = b0 * sample + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1; x1 = sample; y2 = y1; y1 = result
		return result
	}
}

private func impact(_ time: Double, noise: NoiseBands, heavy: Bool) -> Double {
	let bass = thump(time, start: heavy ? 132 : 190, end: heavy ? 46 : 62, fall: 0.025)
	let body = tone(heavy ? 175 : 240, time) * decay(time, 0.018)
	let transient = noise.crack * decay(time, 0.004) + noise.air * decay(time, 0.012)
	return bass * decay(time, heavy ? 0.066 : 0.048) * 0.82
		+ body * 0.20 + noise.body * decay(time, 0.045) * 1.50 + transient * 1.80
}

private func synthesize(_ effect: SoundEffect, time t: Double, noise n: NoiseBands) -> Double {
	switch effect {
	case .menu:
		return (tone(920, t) + tone(1_370, t) * 0.28) * decay(t, 0.012) * 0.28
			+ n.body * decay(t, 0.008) * 0.45
	case .swing:
		let air = smoothstep(t / 0.019) * decay(t, 0.033)
		return (n.air * 1.1 + n.body * 0.45 + n.low * 0.25) * air
	case .punch:
		return impact(t, noise: n, heavy: false)
	case .kick:
		return impact(t, noise: n, heavy: true) + n.low * decay(t, 0.08) * 0.15
	case .block:
		let metal = tone(1_710, t) * decay(t, 0.025) + tone(2_860, t) * decay(t, 0.014) * 0.30
		return impact(t, noise: n, heavy: false) * 0.48 + metal * 0.30
	case .spear:
		let ring = tone(1_340, t) + tone(2_190, t) * 0.3
		return ring * decay(t, 0.045) * 0.20 + n.air * decay(t, 0.065) * 0.8
			+ thump(t, start: 185, end: 65, fall: 0.032) * decay(t, 0.04) * 0.55
	case .ice:
		let crystal = tone(2_630, t) * decay(t, 0.043) + tone(3_871, t) * decay(t, 0.087) * 0.34
			+ tone(5_213, t) * decay(t, 0.068) * 0.22
		return crystal * 0.25 + n.air * decay(t, 0.10) * 0.55
			+ n.crack * decay(t, 0.024) * 0.7 + n.low * decay(t, 0.10) * 0.16
	case .rang:
		let flutter = 0.65 + 0.35 * tone(48, t)
		return n.air * decay(t, 0.10) * flutter + n.body * decay(t, 0.074) * 0.5
			+ (tone(920, t) + tone(1_507, t) * 0.4) * decay(t, 0.067) * 0.12
	case .rocket:
		let roar = smoothstep(t / 0.008) * decay(t, 0.14)
		return (n.low * 0.72 + n.body * 0.95 + n.air * 0.22) * roar
			+ n.crack * decay(t, 0.004) * 0.8
			+ thump(t, start: 156, end: 48, fall: 0.04) * decay(t, 0.07) * 0.55
	case .explode:
		return impact(t, noise: n, heavy: true) * 1.1 + n.low * decay(t, 0.17) * 0.9
			+ n.body * decay(t, 0.13) * 0.65 + n.air * decay(t, 0.075) * 0.5
			+ thump(t, start: 87, end: 33, fall: 0.06) * decay(t, 0.11) * 0.75
	case .teleport:
		let rush = smoothstep(t / 0.075) * decay(t, 0.082)
		let collapse = max(0, t - 0.07)
		let body = t >= 0.07 ? thump(collapse, start: 140, end: 42, fall: 0.025) * decay(collapse, 0.05) : 0
		return (n.air * 0.8 + n.body * 0.6) * rush + body * 0.62
			+ tone(317, t) * decay(t, 0.045) * 0.15
	case .round:
		let second = max(0, t - 0.18)
		let hit = t >= 0.18 ? thump(second, start: 113, end: 38, fall: 0.035) * decay(second, 0.11) : 0
		return thump(t, start: 145, end: 52, fall: 0.038) * decay(t, 0.08) * 0.8
			+ hit * 0.9 + (tone(427, t) + tone(639, t) * 0.3) * decay(t, 0.18) * 0.18
			+ n.body * decay(t, 0.048) * 0.7 + n.low * decay(t, 0.15) * 0.25
	case .net:
		let weave = 0.65 + 0.35 * tone(73, t)
		return n.air * decay(t, 0.07) * weave + n.body * decay(t, 0.05) * 0.55
			+ (tone(1_610, t) + tone(2_390, t) * 0.4) * decay(t, 0.038) * 0.21
			+ thump(t, start: 175, end: 75, fall: 0.023) * decay(t, 0.042) * 0.55
	case .bomb:
		return impact(t, noise: n, heavy: true) * 0.72
			+ (tone(391, t) + tone(747, t) * 0.35) * decay(t, 0.052) * 0.22
			+ n.body * decay(t, 0.085) * (0.65 + 0.35 * tone(36, t)) * 0.4
	case .fan:
		let blade = 0.62 + 0.38 * tone(59, t)
		return n.air * decay(t, 0.078) * blade * 1.1
			+ (tone(2_030, t) + tone(3_127, t) * 0.3) * decay(t, 0.061) * 0.15
			+ n.body * decay(t, 0.055) * 0.50
	case .smoke:
		let puff = smoothstep(t / 0.005) * decay(t, 0.11)
		return (n.low * 0.85 + n.body * 0.8 + n.air * 0.40) * puff
			+ thump(t, start: 122, end: 44, fall: 0.048) * decay(t, 0.079) * 0.42
	case .fire:
		let flame = smoothstep(t / 0.004) * decay(t, 0.10)
		let crackle = n.crack * pow(max(0, tone(43, t, phase: 0.7)), 6) * decay(t, 0.087)
		return (n.low * 0.55 + n.body * 0.88 + n.air * 0.46) * flame + crackle * 0.8
			+ thump(t, start: 181, end: 51, fall: 0.025) * decay(t, 0.054) * 0.8
	}
}
