import UIKit
import GameController
import QuartzCore
import COR

enum Device: Hashable { case keyboard, controller(ObjectIdentifier) }
enum MenuCommand { case left, right, up, down, confirm, back, pause }

@MainActor
final class InputController {
	private struct Pad {
		var controller: GCController
		var held: Input = []
		var menu = false
	}

	var command: (MenuCommand, Device) -> Void = { _, _ in }
	var disconnected: (Device) -> Void = { _ in }
	var topologyChanged: () -> Void = {}
	private var observers: [NotificationCenter.ObservationToken] = []
	private var pads: [ObjectIdentifier: Pad] = [:]
	private var order: [ObjectIdentifier] = []
	private var buffers: InlineArray<2, InputBuffer> = .init(repeating: .init())
	private(set) var seats: InlineArray<2, Device?> = .init(repeating: nil)
	private var keyboardHeld: Input = []
	private var keyboardUsed = false

	init() {
		let center = NotificationCenter.default
		observers.append(center.addObserver(of: GCController.self, for: .didConnect) { [weak self] message in
			self?.attach(message.controller)
		})
		observers.append(center.addObserver(of: GCController.self, for: .didDisconnect) { [weak self] message in
			guard let self else { return }
			let id = ObjectIdentifier(message.controller)
			pads.removeValue(forKey: id)
			order.removeAll { $0 == id }
			disconnected(.controller(id))
			topologyChanged()
		})
		observers.append(center.addObserver(of: GCKeyboard.self, for: .didDisconnect) { [weak self] _ in
			self?.keyboardUsed = false
			self?.disconnected(.keyboard)
			self?.topologyChanged()
		})
		observers.append(center.addObserver(of: GCKeyboard.self, for: .didConnect) { [weak self] _ in self?.topologyChanged() })
		for controller in GCController.controllers() { attach(controller) }
	}

	isolated deinit {
		for observer in observers { NotificationCenter.default.removeObserver(observer) }
		for pad in pads.values { pad.controller.input.inputStateAvailableHandler = nil }
	}

	private func attach(_ controller: GCController) {
		guard controller.extendedGamepad != nil else { return }
		let id = ObjectIdentifier(controller)
		guard pads[id] == nil else { return }
		pads[id] = .init(controller: controller)
		order.append(id)
		controller.handlerQueue = .main
		controller.input.queue = .main
		controller.input.inputStateQueueDepth = 64
		controller.input.inputStateAvailableHandler = { [weak self] input in
			MainActor.assumeIsolated {
				while let state = input.nextInputState() { self?.receive(state, id: id) }
			}
		}
		for seat in 0 ..< 2 {
			if let device = seats[seat], !available(device) { assign(.controller(id), to: seat); break }
		}
		topologyChanged()
	}

	private func receive(_ state: any GCDevicePhysicalInputState, id: ObjectIdentifier) {
		guard var pad = pads[id] else { return }
		var held: Input = []
		if let dpad = state.dpads[GCDirectionPadElementName.directionPad] {
			if dpad.xAxis.value < -0.5 { held.insert(.left) }
			if dpad.xAxis.value > 0.5 { held.insert(.right) }
			if dpad.yAxis.value < -0.5 { held.insert(.down) }
			if dpad.yAxis.value > 0.5 { held.insert(.up) }
		}
		if state.buttons[GCButtonElementName.x]?.pressedInput.isPressed == true { held.insert(.one) }
		if state.buttons[GCButtonElementName.y]?.pressedInput.isPressed == true { held.insert(.two) }
		if state.buttons[GCButtonElementName.a]?.pressedInput.isPressed == true { held.insert(.three) }
		if state.buttons[GCButtonElementName.b]?.pressedInput.isPressed == true { held.insert(.four) }
		if state.buttons[GCButtonElementName.rightTrigger]?.pressedInput.isPressed == true { held.insert(.block) }
		let menu = state.buttons[GCButtonElementName.menu]?.pressedInput.isPressed == true
		let previous = pad.held
		let wasMenu = pad.menu
		pad.held = held
		pad.menu = menu
		pads[id] = pad
		let device = Device.controller(id)
		let time = CACurrentMediaTime() - min(0.25, max(0, state.lastEventLatency))
		receive(held, previous: previous, device: device, time: time)
		if menu, !wasMenu { command(.pause, device) }
		let pressed = held.subtracting(previous)
		if pressed.contains(.three) { command(.confirm, device) }
		if pressed.contains(.four) { command(.back, device) }
	}

	private func receive(_ held: Input, previous: Input, device: Device, time: Double) {
		if held != previous {
			if let seat = seat(for: device) { buffers[seat].append(held, time: time) }
			if held.horizontal != previous.horizontal, held.horizontal != 0 { command(held.horizontal < 0 ? .left : .right, device) }
			if held.vertical != previous.vertical, held.vertical != 0 { command(held.vertical < 0 ? .down : .up, device) }
		}
	}

	@discardableResult
	func key(_ key: UIKey, pressed: Bool) -> Bool {
		keyboardUsed = true
		if pressed {
			switch key.keyCode {
			case .keyboardReturnOrEnter: command(.confirm, .keyboard); return true
			case .keyboardDeleteOrBackspace: command(.back, .keyboard); return true
			case .keyboardEscape: command(.pause, .keyboard); return true
			default: break
			}
		}
		let input: Input
		switch key.keyCode {
		case .keyboardLeftArrow: input = .left
		case .keyboardRightArrow: input = .right
		case .keyboardUpArrow: input = .up
		case .keyboardDownArrow: input = .down
		case .keyboardA: input = .one
		case .keyboardS: input = .two
		case .keyboardZ: input = .three
		case .keyboardX: input = .four
		case .keyboardSpacebar: input = .block
		default: return false
		}
		let previous = keyboardHeld
		if pressed { keyboardHeld.insert(input) } else { keyboardHeld.remove(input) }
		receive(keyboardHeld, previous: previous, device: .keyboard, time: CACurrentMediaTime())
		return true
	}

	func cancelKeyboard() {
		let previous = keyboardHeld
		keyboardHeld = []
		receive([], previous: previous, device: .keyboard, time: CACurrentMediaTime())
	}

	var defaultDevice: Device { order.first.map(Device.controller) ?? .keyboard }
	var hasDevices: Bool { !pads.isEmpty || available(.keyboard) }

	func available(_ device: Device) -> Bool {
		switch device {
		case .controller(let id): return pads[id] != nil
		case .keyboard:
			return GCKeyboard.coalesced != nil || keyboardUsed
		}
	}

	func name(for seat: Int) -> String {
		guard let device = seats[seat] else { return "Press A / Enter to join" }
		switch device {
		case .keyboard: return available(device) ? "Keyboard" : "Connect a controller or keyboard"
		case .controller(let id): return pads[id]?.controller.vendorName ?? "Controller disconnected"
		}
	}

	func seat(for device: Device) -> Int? {
		for i in 0 ..< 2 where seats[i] == device { return i }
		return nil
	}

	func assign(_ device: Device, to seat: Int) {
		seats[seat] = device
		var holding = keyboardHeld
		if case .controller(let id) = device, let pad = pads[id] {
			pad.controller.playerIndex = seat == 0 ? .index1 : .index2
			holding = pad.held
		}
		buffers[seat] = .init(holding: holding)
	}

	func releaseSeats() {
		for pad in pads.values { pad.controller.playerIndex = .indexUnset }
		seats = .init(repeating: nil)
		buffers = .init(repeating: .init())
	}

	func flush() {
		for i in 0 ..< 2 { buffers[i].reset() }
	}

	func frame(for seat: Int, until time: Double) -> InputFrame { buffers[seat].frame(until: time) }
}
