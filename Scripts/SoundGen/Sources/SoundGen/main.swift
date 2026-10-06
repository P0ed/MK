import Foundation
import SoundSynthesis

private let usage = """
Usage: soundgen [--output PATH]

Generate the game's procedural sound bank as 48 kHz mono 16-bit PCM WAV files.
The default output directory is MK/Sounds relative to the current directory.

  --output PATH  Write the sound bank to PATH.
  -h, --help     Show this help.

From the repository root:
  swift run --package-path Scripts/SoundGen soundgen --output MK/Sounds
"""

private enum CLIError: Error, CustomStringConvertible {
	case missingOutput, invalidArgument(String)
	var description: String {
		switch self {
		case .missingOutput: "--output requires a nonempty directory path"
		case .invalidArgument(let argument): "unexpected argument: \(argument)"
		}
	}
}

do {
	let arguments = Array(CommandLine.arguments.dropFirst())
	var destination = "MK/Sounds"
	var index = 0
	while index < arguments.count {
		switch arguments[index] {
		case "-h", "--help":
			print(usage)
			exit(EXIT_SUCCESS)
		case "--output":
			index += 1
			guard index < arguments.count, !arguments[index].isEmpty,
				!arguments[index].hasPrefix("-") else { throw CLIError.missingOutput }
			destination = arguments[index]
		default:
			throw CLIError.invalidArgument(arguments[index])
		}
		index += 1
	}
	let directory = URL(fileURLWithPath: destination, isDirectory: true)
	try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
	for effect in SoundEffect.allCases {
		try SoundBank.wav(for: effect).write(to: directory.appendingPathComponent(effect.rawValue + ".wav"), options: .atomic)
	}
	print("Generated \(SoundEffect.allCases.count) sounds in \(directory.path) (48 kHz, mono, 16-bit PCM).")
} catch {
	let message = "soundgen: \(error)\nRun soundgen --help for usage.\n"
	FileHandle.standardError.write(Data(message.utf8))
	exit(EXIT_FAILURE)
}
