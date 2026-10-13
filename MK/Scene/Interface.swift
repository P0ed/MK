import UIKit
import COR

@MainActor
private func label(_ size: CGFloat, weight: UIFont.Weight = .regular, color: UIColor = .white) -> UILabel {
	let label = UILabel()
	label.font = .systemFont(ofSize: size, weight: weight)
	label.textColor = color
	label.adjustsFontSizeToFitWidth = true
	label.minimumScaleFactor = 0.6
	return label
}

final class MenuButton: UIButton {
	override var canBecomeFocused: Bool { false }

	init(_ title: String, action: @escaping () -> Void) {
		super.init(frame: .zero)
		setTitle(title, for: .normal)
		titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
		titleLabel?.adjustsFontSizeToFitWidth = true
		layer.cornerRadius = 3
		layer.borderWidth = 1
		focus(false)
		addAction(UIAction { _ in action() }, for: .touchUpInside)
	}

	required init?(coder: NSCoder) { fatalError() }

	func focus(_ focused: Bool) {
		setTitleColor(focused ? Colors.gold : .white, for: .normal)
		backgroundColor = focused ? Colors.gold.withAlphaComponent(0.13) : Colors.panel
		layer.borderColor = (focused ? Colors.gold : Colors.muted.withAlphaComponent(0.3)).cgColor
	}
}

private final class HealthBar: UIView {
	private let fill = UIView()
	var progress: CGFloat = 1 { didSet { setNeedsLayout() } }
	var reversed = false

	init() {
		super.init(frame: .zero)
		backgroundColor = UIColor(white: 0.16, alpha: 1)
		layer.cornerRadius = 2
		clipsToBounds = true
		addSubview(fill)
	}

	required init?(coder: NSCoder) { fatalError() }
	func color(_ color: UIColor) { fill.backgroundColor = color }

	override func layoutSubviews() {
		super.layoutSubviews()
		let width = bounds.width * max(0, min(1, progress))
		fill.frame = CGRect(x: reversed ? bounds.width - width : 0, y: 0, width: width, height: bounds.height)
	}
}

final class HUD: UIView {
	private let names: InlineArray<2, UILabel> = .init { _ in label(16, weight: .bold) }
	private let bars: InlineArray<2, HealthBar> = .init { _ in HealthBar() }
	private let wins: InlineArray<2, UILabel> = .init { _ in label(17, color: Colors.gold) }
	private let combos: InlineArray<2, UILabel> = .init { _ in label(16, weight: .bold, color: Colors.gold) }
	private let round = label(11, weight: .semibold, color: Colors.muted)
	private let banner = label(48, weight: .heavy, color: Colors.gold)
	private var health: InlineArray<2, Int> = .init(repeating: -1)
	private var scores: InlineArray<2, Int> = .init(repeating: -1)
	private var roundNumber = 0
	let pauseButton: UIButton

	init(pause: @escaping () -> Void) {
		pauseButton = MenuButton("Ⅱ", action: pause)
		super.init(frame: .zero)
		for i in 0 ..< 2 { addSubview(names[i]); addSubview(bars[i]); addSubview(wins[i]); addSubview(combos[i]) }
		bars[1].reversed = true
		names[1].textAlignment = .right
		wins[1].textAlignment = .right
		combos[1].textAlignment = .right
		round.textAlignment = .center
		banner.textAlignment = .center
		addSubview(round)
		addSubview(banner)
		addSubview(pauseButton)
		pauseButton.accessibilityLabel = "Pause"
	}

	required init?(coder: NSCoder) { fatalError() }

	func configure(_ first: Character, _ second: Character, practice: Bool = false) {
		names[0].text = first.name
		names[1].text = practice ? "DUMMY · \(second.name)" : second.name
		bars[0].color(first.color)
		bars[1].color(second.color)
		health = .init(repeating: -1)
		scores = .init(repeating: -1)
		roundNumber = 0
	}

	func update(_ fight: borrowing Fight) {
		for i in 0 ..< 2 {
			let fighter = fight.fighters[i]
			if health[i] != fighter.health {
				health[i] = fighter.health
				bars[i].progress = CGFloat(fighter.health) / CGFloat(Fighter.maxHealth)
			}
			if fight.practice {
				wins[i].text = "∞ HEALTH"
			} else if scores[i] != fighter.wins {
				scores[i] = fighter.wins
				wins[i].text = String(repeating: "● ", count: fighter.wins) + String(repeating: "○ ", count: 2 - fighter.wins)
			}
			combos[i].isHidden = fighter.comboHits < (fight.practice ? 1 : 2) || fight.frame - fighter.comboFrame > 90
			if !combos[i].isHidden {
				let damage = fighter.comboDamage * 100 / Fighter.maxHealth
				let text = "\(fighter.comboHits) \(fighter.comboHits == 1 ? "HIT" : "HITS")  ·  \(damage)%"
				if combos[i].text != text { combos[i].text = text }
			}
		}
		if fight.practice { round.text = "PRACTICE" }
		else if roundNumber != fight.round { roundNumber = fight.round; round.text = "ROUND \(fight.round)" }
		let text: String
		switch fight.phase {
		case .intro: text = fight.phaseFrame < 40 ? "ROUND \(fight.round)" : "FIGHT"
		case .roundEnd: text = fight.winner.map { "PLAYER \($0 + 1) WINS" } ?? "DOUBLE KO"
		case .matchEnd: text = fight.phaseFrame < 30 ? "K.O." : fight.winner.map { "\(fight.fighters[$0].character.name) WINS" } ?? "DOUBLE KO"
		default: text = ""
		}
		banner.isHidden = text.isEmpty
		if banner.text != text { banner.text = text }
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		let w = bounds.width, h = bounds.height
		let margin: CGFloat = max(16, w * 0.028)
		let width = w * 0.40
		for i in 0 ..< 2 {
			let x = i == 0 ? margin : w - margin - width
			names[i].frame = CGRect(x: x, y: 12, width: width, height: 23)
			bars[i].frame = CGRect(x: x, y: 39, width: width, height: 13)
			wins[i].frame = CGRect(x: x, y: 58, width: width, height: 22)
			combos[i].frame = CGRect(x: x, y: 85, width: width, height: 25)
		}
		round.frame = CGRect(x: w / 2 - 50, y: 15, width: 100, height: 18)
		pauseButton.frame = CGRect(x: w / 2 - 17, y: 40, width: 34, height: 28)
		banner.frame = CGRect(x: 30, y: h * 0.34, width: w - 60, height: 66)
	}
}

final class MenuOverlay: UIView {
	private let kicker = label(10, weight: .semibold, color: Colors.gold)
	private let title = label(36, weight: .heavy)
	private let subtitle = label(13, color: Colors.muted)
	private let footer = label(11, color: Colors.muted)
	private var buttons: [MenuButton] = []
	private(set) var selection = 0
	private var activate: (Int) -> Void = { _ in }

	override init(frame: CGRect) {
		super.init(frame: frame)
		backgroundColor = Colors.background.withAlphaComponent(0.82)
		kicker.text = "LOCAL KOMBAT"
		for label in [kicker, title, subtitle, footer] { label.textAlignment = .center; addSubview(label) }
		footer.numberOfLines = 2
	}

	required init?(coder: NSCoder) { fatalError() }

	func show(title: String, subtitle: String, rows: [String], footer: String, activate: @escaping (Int) -> Void) {
		self.title.text = title
		self.subtitle.text = subtitle
		self.footer.text = footer
		self.activate = activate
		selection = 0
		for button in buttons { button.removeFromSuperview() }
		buttons = rows.enumerated().map { index, text in
			let button = MenuButton(text) { [weak self] in self?.activate(index) }
			addSubview(button)
			return button
		}
		focus(0)
		setNeedsLayout()
	}

	func focus(_ index: Int) {
		guard !buttons.isEmpty else { return }
		selection = (index + buttons.count) % buttons.count
		for (i, button) in buttons.enumerated() { button.focus(i == selection) }
	}

	func confirm() { activate(selection) }

	override func layoutSubviews() {
		super.layoutSubviews()
		let w = bounds.width, h = bounds.height
		kicker.frame = CGRect(x: 20, y: 12, width: w - 40, height: 14)
		title.frame = CGRect(x: 20, y: 31, width: w - 40, height: 43)
		title.font = .systemFont(ofSize: min(36, h * 0.10), weight: .heavy)
		subtitle.frame = CGRect(x: 24, y: 77, width: w - 48, height: 22)
		let available = h - 148 - CGFloat(max(0, buttons.count - 1)) * 7
		let rowHeight = min(43, max(24, min(h * 0.105, available / CGFloat(max(1, buttons.count)))))
		let total = CGFloat(buttons.count) * (rowHeight + 7) - 7
		let start = min(max(106, (h - total) / 2 + 25), h - total - 42)
		let width = min(310, w * 0.47)
		for (index, button) in buttons.enumerated() {
			button.frame = CGRect(x: (w - width) / 2, y: start + CGFloat(index) * (rowHeight + 7), width: width, height: rowHeight)
		}
		footer.frame = CGRect(x: 20, y: h - 36, width: w - 40, height: 30)
	}
}

final class SelectionView: UIView {
	private let title = label(27, weight: .heavy)
	private let hint = label(12, color: Colors.muted)
	private let names: InlineArray<2, UILabel> = .init { _ in label(17, weight: .bold) }
	private let devices: InlineArray<2, UILabel> = .init { _ in label(11, color: Colors.muted) }
	private var cards: [MenuButton] = []
	private let ready: MenuButton
	private let moveGuide: MenuButton
	var choose: (Character) -> Void = { _ in }
	var confirm: () -> Void = {}
	var showMoves: () -> Void = {}

	override init(frame: CGRect) {
		ready = MenuButton("READY", action: {})
		moveGuide = MenuButton("MOVES", action: {})
		super.init(frame: frame)
		title.text = "CHOOSE YOUR FIGHTER"
		title.textAlignment = .center
		hint.textAlignment = .center
		addSubview(title); addSubview(hint)
		for i in 0 ..< 2 { addSubview(names[i]); addSubview(devices[i]); devices[i].numberOfLines = 3 }
		names[1].textAlignment = .right; devices[1].textAlignment = .right
		for character in Character.allCases {
			let card = MenuButton(character.name) { [weak self] in self?.choose(character) }
			card.titleLabel?.font = .systemFont(ofSize: 12, weight: .bold)
			card.titleLabel?.numberOfLines = 2
			card.titleLabel?.textAlignment = .center
			cards.append(card)
			addSubview(card)
		}
		ready.addAction(UIAction { [weak self] _ in self?.confirm() }, for: .touchUpInside)
		moveGuide.addAction(UIAction { [weak self] _ in self?.showMoves() }, for: .touchUpInside)
		addSubview(ready)
		addSubview(moveGuide)
	}

	required init?(coder: NSCoder) { fatalError() }

	func update(_ choices: borrowing InlineArray<2, Character>, ready: borrowing InlineArray<2, Bool>, inputs: InputController, solo: Bool, cursor: Int, practice: Bool = false) {
		title.text = practice ? "CHOOSE YOUR FIGHTER & DUMMY" : "CHOOSE YOUR FIGHTER"
		hint.text = practice ? (cursor == 0 ? "Choose your fighter · A / Enter to ready" : "Choose the idle dummy · Infinite health · A / Enter to practice") : solo ? (cursor == 0 ? "Stronger fighters ease the challenge · A / Enter to ready" : "Stronger opponents raise the challenge · A / Enter to fight") : "Each player chooses with their own D-pad · A / Enter to ready"
		for i in 0 ..< 2 {
			let seat = i == 1 && practice ? "DUMMY" : solo && i == 1 ? "CPU" : "PLAYER \(i + 1)"
			names[i].text = "\(seat)  ·  \(choices[i].name)\(ready[i] ? "  ✓" : "")"
			names[i].textColor = choices[i].color
			let device = i == 1 && practice ? "No AI · Infinite health" : solo && i == 1 ? "Local opponent" : inputs.name(for: i)
			devices[i].text = "\(device)\n\(choices[i].strength) · \(choices[i].playstyle)"
		}
		for (index, card) in cards.enumerated() {
			let character = Character(rawValue: UInt8(index))!
			var suffix = ""
			if choices[0] == character { suffix += " · P1" }
			if choices[1] == character { suffix += practice ? " · DUMMY" : solo ? " · CPU" : " · P2" }
			card.setTitle(character.name + suffix + "\n" + character.strength, for: .normal)
			card.accessibilityLabel = character.name + suffix + ", " + character.strength + ", " + character.playstyle
			card.focus(choices[cursor] == character)
			card.layer.borderColor = (choices[cursor] == character ? character.color : Colors.muted.withAlphaComponent(0.3)).cgColor
		}
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		let w = bounds.width, h = bounds.height, margin: CGFloat = 20
		let compact = h < 330
		title.font = .systemFont(ofSize: compact ? 23 : 27, weight: .heavy)
		title.frame = CGRect(x: margin, y: compact ? 5 : 12, width: w - margin * 2, height: compact ? 28 : 35)
		hint.frame = CGRect(x: margin, y: compact ? 35 : 50, width: w - margin * 2, height: compact ? 18 : 22)
		for i in 0 ..< 2 {
			let width = w * 0.44
			let x = i == 0 ? margin : w - margin - width
			names[i].font = .systemFont(ofSize: compact ? 14 : 17, weight: .bold)
			devices[i].font = .systemFont(ofSize: compact ? 9 : 11)
			names[i].frame = CGRect(x: x, y: compact ? 56 : 81, width: width, height: compact ? 20 : 25)
			devices[i].frame = CGRect(x: x, y: compact ? 76 : 106, width: width, height: compact ? 31 : 45)
		}
		let gap: CGFloat = compact ? 6 : 8, width = (w - margin * 2 - gap * 3) / 4
		let rows = (cards.count + 3) / 4
		let rowHeight = min(43, max(28, h * 0.09))
		let gridHeight = CGFloat(rows) * rowHeight + CGFloat(rows - 1) * gap
		let top = h - (compact ? 55 : 61) - gridHeight
		for (i, card) in cards.enumerated() {
			card.titleLabel?.font = .systemFont(ofSize: compact ? 10 : 12, weight: .bold)
			card.frame = CGRect(x: margin + CGFloat(i % 4) * (width + gap), y: top + CGFloat(i / 4) * (rowHeight + gap), width: width, height: rowHeight)
		}
		moveGuide.frame = CGRect(x: w / 2 - 142, y: h - 49, width: 134, height: 34)
		ready.frame = CGRect(x: w / 2 + 8, y: h - 49, width: 134, height: 34)
	}
}

final class ControlsView: UIView {
	private let title = label(25, weight: .heavy)
	private let hint = label(10, color: Colors.muted)
	private let left = label(13, color: .white)
	private let right = label(13, color: .white)
	private let leftScroll = UIScrollView()
	private let rightScroll = UIScrollView()
	private let back: MenuButton

	init(back action: @escaping () -> Void) {
		back = MenuButton("BACK", action: action)
		super.init(frame: .zero)
		backgroundColor = Colors.background.withAlphaComponent(0.95)
		title.text = "CONTROLS & MOVES"
		title.textAlignment = .center
		hint.text = "↑ / ↓ or swipe to scroll · A / Enter to go back"
		hint.textAlignment = .center
		left.numberOfLines = 0; right.numberOfLines = 0
		left.text = "D-PAD / ARROWS\nMove · crouch · jump\nDouble-tap F / B: dash\n\n1  X / Square  or A\n2  Y / Triangle  or S\n3  A / Cross  or Z\n4  B / Circle  or X\n\nBLOCK  RT / R2 / Space\nPAUSE  Menu / Escape\n\nStand-block overheads.\nCrouch-block lows.\n\nSHARED STRINGS\n1, 1, 2  ·  knockdown\n2, 1, 2  ·  launcher\n3, 4     ·  low\nB + 1    ·  launcher\n\nF / B = toward / away\nD = down\n\nCancel strings into specials.\nFollow launchers with attacks.\n\nPRACTICE\nIdle dummy · Infinite health\nPause → Reset Practice"
		leftScroll.addSubview(left)
		rightScroll.addSubview(right)
		for scroll in [leftScroll, rightScroll] { scroll.indicatorStyle = .white; scroll.alwaysBounceVertical = true }
		for view in [title, hint, leftScroll, rightScroll, back] { addSubview(view) }
	}

	required init?(coder: NSCoder) { fatalError() }

	func configure(_ first: Character, _ second: Character) {
		right.text = "\(first.name)\n\(first.stringOne.hint)\n\(first.moves)\n\n\(second.name)\n\(second.stringOne.hint)\n\(second.moves)"
		leftScroll.setContentOffset(.zero, animated: false)
		rightScroll.setContentOffset(.zero, animated: false)
		setNeedsLayout()
	}

	func scroll(_ direction: Int) {
		for scroll in [leftScroll, rightScroll] {
			let end = max(0, scroll.contentSize.height - scroll.bounds.height)
			let offset = min(end, max(0, scroll.contentOffset.y + CGFloat(direction) * 60))
			scroll.setContentOffset(CGPoint(x: 0, y: offset), animated: true)
		}
	}

	override func layoutSubviews() {
		super.layoutSubviews()
		let w = bounds.width, h = bounds.height
		title.frame = CGRect(x: 20, y: 8, width: w - 40, height: 30)
		hint.frame = CGRect(x: 20, y: 38, width: w - 40, height: 14)
		let size: CGFloat = h < 400 ? 12 : 15
		left.font = .monospacedSystemFont(ofSize: size, weight: .regular)
		right.font = .monospacedSystemFont(ofSize: size, weight: .regular)
		leftScroll.frame = CGRect(x: w * 0.06, y: 57, width: w * 0.43, height: h - 115)
		rightScroll.frame = CGRect(x: w * 0.53, y: 57, width: w * 0.43, height: h - 115)
		for (scroll, text) in [(leftScroll, left), (rightScroll, right)] {
			let width = scroll.bounds.width - 8
			let height = text.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
			text.frame = CGRect(x: 0, y: 0, width: width, height: height)
			scroll.contentSize = CGSize(width: scroll.bounds.width, height: height)
		}
		back.frame = CGRect(x: w / 2 - 75, y: h - 47, width: 150, height: 33)
	}
}
