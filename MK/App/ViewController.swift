import UIKit
import AVFAudio
import QuartzCore
import COR

private enum Screen { case title, selection, fighting, paused, controls, result }

final class ViewController: UIViewController {
	private let arena = Arena()
	private let inputs = InputController()
	private let sounds = Sounds()
	private let canvas = UIView()
	private let menu = MenuOverlay()
	private let selection = SelectionView()
	private lazy var controls = ControlsView { [weak self] in self?.closeControls() }
	private lazy var hud = HUD { [weak self] in self?.pause(reason: "Game paused") }
	private var fight = Fight()
	private var cpu = AI()
	private var clock = FrameClock()
	private var screen: Screen = .title
	private var controlsFrom: Screen = .title
	private var choices: InlineArray<2, Character> = [.scorpion, .sektor]
	private var ready: InlineArray<2, Bool> = .init(repeating: false)
	private var solo = true
	private var selectionCursor = 0
	private var previewFrame = 0
	private var resultSettledFrame: Int?
	private var interruption: NSObjectProtocol?
	#if DEBUG
	private let demo = ProcessInfo.processInfo.arguments.contains("--demo")
	private var demoCPU = AI(seed: 17)
	#endif

	override var prefersStatusBarHidden: Bool { true }
	override var prefersHomeIndicatorAutoHidden: Bool { true }
	override var canBecomeFirstResponder: Bool { true }
	override var supportedInterfaceOrientations: UIInterfaceOrientationMask { traitCollection.userInterfaceIdiom == .pad ? .all : .landscape }

	override func loadView() {
		view = UIView()
		view.backgroundColor = Colors.background
		view.addSubview(canvas)
		for view in [arena.view, hud, menu, selection, controls] { canvas.addSubview(view) }
		arena.update = { [weak self] delta in self?.update(delta) }
		inputs.command = { [weak self] command, device in self?.handle(command, device: device) }
		inputs.disconnected = { [weak self] device in
			guard let self, let seat = inputs.seat(for: device), seat == 0 || !solo else { return }
			pause(reason: "Player \(seat + 1) disconnected · reconnect to resume")
		}
		inputs.topologyChanged = { [weak self] in self?.refreshDevices() }
		selection.choose = { [weak self] character in self?.choose(character) }
		selection.showMoves = { [weak self] in self?.showControls() }
		selection.confirm = { [weak self] in
			guard let self else { return }
			handle(.confirm, device: inputs.seats[0] ?? inputs.defaultDevice)
		}
		interruption = NotificationCenter.default.addObserver(forName: AVAudioSession.didBecomeInactiveNotification, object: nil, queue: .main) { [weak self] _ in
			MainActor.assumeIsolated { self?.pause(reason: "Audio interrupted · resume when ready") }
		}
		showTitle()
		#if DEBUG
		if demo {
			let arguments = ProcessInfo.processInfo.arguments
			if let index = arguments.firstIndex(of: "--fighters"), arguments.count > index + 2,
				let first = UInt8(arguments[index + 1]), let second = UInt8(arguments[index + 2]),
				let a = Character(rawValue: first), let b = Character(rawValue: second) { choices = [a, b] }
			inputs.assign(.keyboard, to: 0)
			startFight()
		}
		#endif
	}

	isolated deinit { if let interruption { NotificationCenter.default.removeObserver(interruption) } }

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		becomeFirstResponder()
	}

	override func viewDidLayoutSubviews() {
		super.viewDidLayoutSubviews()
		let safe = view.bounds.inset(by: view.safeAreaInsets)
		let width = min(safe.width, safe.height * 16 / 9)
		let height = width * 9 / 16
		canvas.frame = CGRect(x: safe.midX - width / 2, y: safe.midY - height / 2, width: width, height: height)
		for view in [arena.view, hud, menu, selection, controls] { view.frame = canvas.bounds }
	}

	override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		var handled = false
		for press in presses { if let key = press.key { handled = inputs.key(key, pressed: true) || handled } }
		if !handled { super.pressesBegan(presses, with: event) }
	}

	override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		var handled = false
		for press in presses { if let key = press.key { handled = inputs.key(key, pressed: false) || handled } }
		if !handled { super.pressesEnded(presses, with: event) }
	}

	override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		inputs.cancelKeyboard()
		super.pressesCancelled(presses, with: event)
	}
}

private extension ViewController {
	func update(_ delta: Double) {
		if screen == .fighting {
			if delta > 0.25 { pause(reason: "Game paused"); return }
			let steps = clock.advance(delta)
			let now = CACurrentMediaTime()
			for index in 0 ..< steps {
				let deadline = now - clock.remainder - Double(steps - index - 1) * FrameClock.duration
				var first = inputs.frame(for: 0, until: deadline)
				#if DEBUG
				if demo { first = demoCPU.input(fight, player: 0) }
				#endif
				let second = solo ? cpu.input(fight) : inputs.frame(for: 1, until: deadline)
				let events = fight.step([first, second])
				for i in 0 ..< events.count { sounds.play(events[i]); arena.process(events[i], frame: fight.frame) }
				if fight.phase == .matchEnd {
					if fight.defeatedSettled, resultSettledFrame == nil { resultSettledFrame = fight.phaseFrame }
					if let resultSettledFrame, fight.phaseFrame >= max(60, resultSettledFrame + 15) {
						#if DEBUG
						if demo { startFight(); break }
						#endif
						showResult()
						break
					}
				}
			}
			arena.draw(fight, fraction: Float(clock.remainder / FrameClock.duration))
			hud.update(fight)
		} else if screen == .title || screen == .selection || (screen == .controls && (controlsFrom == .title || controlsFrom == .selection)) {
			previewFrame += clock.advance(delta)
			// The preview has no combat side effects.
			arena.draw(fight, fraction: Float(clock.remainder / FrameClock.duration), previewFrame: previewFrame)
		} else { clock.reset() }
	}

	func display(_ screen: Screen) {
		self.screen = screen
		clock.reset()
		hud.isHidden = screen != .fighting
		menu.isHidden = screen != .title && screen != .paused && screen != .result
		selection.isHidden = screen != .selection
		controls.isHidden = screen != .controls
	}

	func showTitle() {
		inputs.releaseSeats()
		choices = [.scorpion, .sektor]
		fight = Fight(choices[0], choices[1])
		arena.select(choices[0], choices[1])
		arena.draw(fight)
		display(.title)
		menu.show(title: "MORTAL KOMBAT", subtitle: "Eight fighters. One arena. First to two.",
			rows: ["ONE PLAYER", "TWO PLAYERS", "CONTROLS"], footer: deviceHint) { [weak self] index in
			guard let self else { return }
			if index == 2 { showControls() }
			else { beginSelection(solo: index == 0, device: inputs.defaultDevice) }
		}
	}

	var deviceHint: String {
		inputs.hasDevices ? "D-pad / arrows to choose · A / Enter to confirm" : "Connect a controller or hardware keyboard to play"
	}

	func beginSelection(solo: Bool, device: Device) {
		self.solo = solo
		ready = .init(repeating: false)
		selectionCursor = 0
		inputs.releaseSeats()
		inputs.assign(device, to: 0)
		display(.selection)
		refreshSelection()
	}

	func refreshSelection() {
		fight = Fight(choices[0], choices[1])
		arena.select(choices[0], choices[1])
		arena.draw(fight)
		selection.update(choices, ready: ready, inputs: inputs, solo: solo, cursor: selectionCursor)
	}

	func choose(_ character: Character) {
		guard screen == .selection, !ready[selectionCursor] else { return }
		choices[selectionCursor] = character
		sounds.play(.menu)
		refreshSelection()
	}

	func startFight() {
		fight = Fight(choices[0], choices[1])
		resultSettledFrame = nil
		cpu.reset()
		inputs.flush()
		sounds.resume()
		arena.select(choices[0], choices[1])
		hud.configure(choices[0], choices[1])
		hud.update(fight)
		display(.fighting)
	}

	func showResult() {
		display(.result)
		let winner = fight.winner ?? 0
		menu.show(title: "\(choices[winner].name) WINS", subtitle: "\(fight.fighters[0].wins) – \(fight.fighters[1].wins)",
			rows: ["REMATCH", "CHARACTER SELECT", "MAIN MENU"], footer: "A / Enter to confirm") { [weak self] index in
			guard let self else { return }
			if index == 0 { startFight() }
			else if index == 1 { returnToSelection() }
			else { showTitle() }
		}
	}

	func returnToSelection() {
		ready = .init(repeating: false)
		selectionCursor = 0
		inputs.flush()
		display(.selection)
		refreshSelection()
	}

	func showControls() {
		controlsFrom = screen
		controls.configure(choices[0], choices[1])
		display(.controls)
	}

	func closeControls() {
		if controlsFrom == .paused { pauseMenu(reason: "Game paused") }
		else if controlsFrom == .selection { display(.selection); refreshSelection() }
		else { showTitle() }
	}

	func pauseMenu(reason: String) {
		display(.paused)
		menu.show(title: "PAUSED", subtitle: reason, rows: ["RESUME", "CONTROLS & MOVES", "CHARACTER SELECT", "MAIN MENU"],
			footer: "A / Enter to confirm · B / Escape to resume") { [weak self] index in
			guard let self else { return }
			switch index {
			case 0: resume()
			case 1: showControls()
			case 2: returnToSelection()
			default: showTitle()
			}
		}
	}

	func resume() {
		for seat in 0 ..< (solo ? 1 : 2) {
			guard let device = inputs.seats[seat], inputs.available(device) else {
				pauseMenu(reason: "Reconnect Player \(seat + 1) to resume")
				return
			}
		}
		inputs.flush()
		fight.clearInputs()
		cpu.reset()
		sounds.resume()
		display(.fighting)
	}

	func refreshDevices() {
		if screen == .selection { selection.update(choices, ready: ready, inputs: inputs, solo: solo, cursor: selectionCursor) }
		else if screen == .title { showTitle() }
	}

	func handle(_ command: MenuCommand, device: Device) {
		switch screen {
		case .fighting:
			if command == .pause { pause(reason: "Game paused") }
		case .controls:
			if command == .back || command == .pause || command == .confirm { closeControls() }
		case .selection:
			if command == .pause { showTitle(); return }
			if !solo, inputs.seat(for: device) == nil, inputs.seats[1] == nil, command == .confirm {
				inputs.assign(device, to: 1)
				selectionCursor = 1
				refreshSelection()
				return
			}
			guard let seat = inputs.seat(for: device) else { return }
			let cursor = solo ? selectionCursor : seat
			if command == .back {
				if ready[cursor] { ready[cursor] = false }
				else if solo, cursor == 1 { selectionCursor = 0; ready[0] = false }
				else { showTitle(); return }
			} else if command == .left || command == .right || command == .up || command == .down {
				guard !ready[cursor] else { return }
				selectionCursor = cursor
				let roster = Character.allCases
				let offset = command == .left ? -1 : command == .right ? 1 : command == .up ? -4 : 4
				let index = (Int(choices[cursor].rawValue) + offset + roster.count) % roster.count
				choices[cursor] = roster[index]
				sounds.play(.menu)
			} else if command == .confirm {
				guard inputs.available(device) else { return }
				ready[cursor] = true
				if solo, cursor == 0 { selectionCursor = 1 }
				if ready[0] && ready[1] { startFight(); return }
			}
			refreshSelection()
		case .title, .paused, .result:
			if command == .up || command == .left { menu.focus(menu.selection - 1); sounds.play(.menu) }
			else if command == .down || command == .right { menu.focus(menu.selection + 1); sounds.play(.menu) }
			else if command == .confirm {
				if screen == .title, menu.selection < 2 { beginSelection(solo: menu.selection == 0, device: device) }
				else { menu.confirm() }
			} else if command == .back || command == .pause, screen == .paused { resume() }
		}
	}
}

extension ViewController {
	func pause(reason: String) {
		guard screen == .fighting || (screen == .controls && controlsFrom == .paused) else { return }
		inputs.flush()
		fight.clearInputs()
		sounds.stop()
		pauseMenu(reason: reason)
	}
}
