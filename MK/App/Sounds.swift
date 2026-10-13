import AVFAudio
import QuartzCore
import COR

enum Sound: Int, CaseIterable {
	case menu, swing, punch, kick, block, spear, ice, rang, rocket, explode, teleport, round
	case net, bomb, fan, smoke, fire
}

private let soundNames: InlineArray<17, String> = [
	"menu", "swing", "punch", "kick", "block", "spear", "ice", "rang", "rocket", "explode", "teleport", "round",
	"net", "bomb", "fan", "smoke", "fire"
]

@MainActor
final class Sounds {
	private final class Voice {
		let node = AVAudioPlayerNode()
		var until = 0.0
	}

	private let engine = AVAudioEngine()
	private let voices: InlineArray<8, Voice>
	private var buffers: InlineArray<17, AVAudioPCMBuffer?> = .init(repeating: nil)

	init() {
		try? AVAudioSession.sharedInstance().setCategory(.ambient)
		voices = .init { _ in Voice() }
		for (i, sound) in Sound.allCases.enumerated() {
			guard let url = Bundle.main.url(forResource: soundNames[sound.rawValue], withExtension: "wav"),
				let file = try? AVAudioFile(forReading: url),
				let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
				(try? file.read(into: buffer)) != nil else { continue }
			buffers[i] = buffer
		}
		for i in voices.indices {
			engine.attach(voices[i].node)
			try? engine.connectNode(voices[i].node, to: engine.mainMixerNode, format: buffers[0]?.format)
		}
		engine.mainMixerNode.outputVolume = 0.55
		try? engine.start()
	}

	func resume() {
		try? AVAudioSession.sharedInstance().setActive(true)
		if !engine.isRunning { try? engine.start() }
	}

	func stop() {
		for i in voices.indices { voices[i].node.stop(); voices[i].until = 0 }
	}

	func play(_ sound: Sound) {
		guard engine.isRunning, let buffer = buffers[sound.rawValue] else { return }
		let time = CACurrentMediaTime()
		var voice = voices[0]
		for i in voices.indices {
			if voices[i].until <= time { voice = voices[i]; break }
			if voices[i].until < voice.until { voice = voices[i] }
		}
		voice.node.stop()
		voice.node.scheduleBuffer(buffer, completionHandler: nil)
		voice.until = time + Double(buffer.frameLength) / buffer.format.sampleRate
		try? voice.node.playAudio()
	}

	func play(_ event: FrameEvent) {
		switch event.kind {
		case .attack: play(.swing)
		case .block: play(.block)
		case .hit:
			switch event.move {
			case .rocket: play(.explode)
			case .net: play(.net)
			case .fan, .fanLift, .squareWave: play(.fan)
			case .smokeCloud, .smokeTeleport, .smokeStrike: play(.smoke)
			case .fireball, .flameBurner: play(.fire)
			case .iceBurst: play(.ice)
			case .staffSpin, .buzzsaw: play(.rang)
			default: play(event.move.isKick ? .kick : .punch)
			}
		case .special:
			switch event.move {
			case .spear: play(.spear)
			case .ice, .iceBurst: play(.ice)
			case .rang, .staffSpin, .buzzsaw: play(.rang)
			case .rocket: play(.rocket)
			case .teleport, .teleportUppercut: play(.teleport)
			case .net: play(.net)
			case .bomb: play(.bomb)
			case .fan, .fanLift, .squareWave: play(.fan)
			case .smokeCloud, .smokeTeleport, .smokeStrike: play(.smoke)
			case .fireball, .flameBurner: play(.fire)
			default: play(.kick)
			}
		case .detonate: play(.explode)
		case .roundStart, .knockout: play(.round)
		default: break
		}
	}
}
