public enum Phase: Sendable { case intro, fighting, roundEnd, matchEnd }
public enum EventKind: Sendable { case none, attack, special, hit, block, roundStart, knockout, roundWin, matchWin }

public struct FrameEvent: Sendable {
	public var kind: EventKind = .none
	public var player = 0
	public var move: MoveID = .none
	public var damage = 0
	public var x: Int32 = 0
	public var y: Int32 = 0
}

public struct FrameEvents: Sendable {
	public private(set) var count = 0
	private var storage: InlineArray<16, FrameEvent> = .init(repeating: .init())
	public subscript(_ index: Int) -> FrameEvent { storage[index] }

	mutating func add(_ event: FrameEvent) {
		guard count < storage.count else { return }
		storage[count] = event
		count += 1
	}
}

public struct Projectile: Sendable {
	public internal(set) var active = false
	public internal(set) var move: MoveID = .none
	public internal(set) var x: Int32 = 0
	public internal(set) var y: Int32 = 0
	public internal(set) var vx: Int32 = 0
	public internal(set) var age = 0
	public internal(set) var returning = false
	var contacted = false
	var oldX: Int32 = 0

	var box: Box {
		.init(left: min(x, oldX) - 26, bottom: y - 24, right: max(x, oldX) + 26, top: y + 24)
	}
}

struct Contact {
	var source = 0
	var move: MoveID = .none
	var blocked = false
}

public struct Fight: ~Copyable {
	public static let edge: Int32 = 1_408
	public private(set) var fighters: InlineArray<2, Fighter>
	public private(set) var projectiles: InlineArray<2, Projectile> = .init(repeating: .init())
	public private(set) var phase: Phase = .intro
	public private(set) var frame = 0
	public private(set) var phaseFrame = 0
	public private(set) var round = 1
	public private(set) var winner: Int?
	public private(set) var hitstop = 0

	public init(_ first: Character = .scorpion, _ second: Character = .sektor) {
		fighters = [.init(character: first, side: 0), .init(character: second, side: 1)]
	}

	init(fighters: consuming InlineArray<2, Fighter>, phase: Phase = .fighting, round: Int = 1,
		projectiles: consuming InlineArray<2, Projectile> = .init(repeating: .init())) {
		self.fighters = fighters
		self.phase = phase
		self.round = round
		self.projectiles = projectiles
	}

	/// The only combat entry point. Results and runtime storage stay inline.
	public mutating func step(_ inputs: borrowing InlineArray<2, InputFrame>) -> FrameEvents {
		frame += 1
		var events = FrameEvents()
		for i in 0 ..< 2 { fighters[i].ingest(inputs[i], frame: frame) }

		guard phase == .fighting else {
			for i in 0 ..< 2 { fighters[i].clearCommands() }
			phaseFrame += 1
			if phase == .intro, phaseFrame >= 60 {
				phase = .fighting
				phaseFrame = 0
				events.add(.init(kind: .roundStart))
			} else if phase == .roundEnd, phaseFrame >= 90 {
				resetRound()
			}
			return events
		}
		if hitstop > 0 {
			hitstop -= 1
			return events
		}

		let left = fighters[0].x <= fighters[1].x ? 0 : 1
		for i in 0 ..< 2 {
			if fighters[i].move == .none, fighters[i].stun == 0 {
				fighters[i].facing = fighters[i].x < fighters[1 - i].x ? 1 : -1
			}
			advanceFighter(i, events: &events)
		}
		separate(left: left)
		for i in 0 ..< 2 { advanceProjectile(i) }

		var contacts: InlineArray<4, Contact> = .init(repeating: .init())
		var count = 0
		for i in 0 ..< 2 {
			let target = 1 - i
			let fighter = fighters[i]
			if fighter.move != .none, !fighter.move.isProjectile, !fighter.contacted,
				fighter.moveFrame >= fighter.move.data.startup,
				fighter.moveFrame < fighter.move.data.startup + fighter.move.data.active,
				!fighters[target].intangible, fighter.hitbox.overlaps(fighters[target].hurtbox) {
				contacts[count] = .init(source: i, move: fighter.move, blocked: fighters[target].guards(fighter.move.data.level))
				count += 1
				fighters[i].contacted = true
				fighters[i].connected = true
			}
			let projectile = projectiles[i]
			if projectile.active, !projectile.contacted, !fighters[target].intangible,
				projectile.box.overlaps(fighters[target].hurtbox) {
				contacts[count] = .init(source: i, move: projectile.move, blocked: fighters[target].guards(projectile.move.data.level))
				count += 1
				projectiles[i].contacted = true
				if projectile.move != .rang { projectiles[i].active = false }
				if fighters[i].move == projectile.move { fighters[i].connected = true }
			}
		}
		for i in 0 ..< count { resolve(contacts[i], events: &events) }
		finishRound(events: &events)
		return events
	}

	/// Pause clears commands, but preserves health, attack frames and projectiles.
	public mutating func clearInputs() {
		for i in 0 ..< 2 {
			fighters[i].input = []
			fighters[i].history = .init()
			fighters[i].clearCommands()
		}
	}
}

extension Fight {
	private mutating func advanceFighter(_ index: Int, events: inout FrameEvents) {
		var fighter = fighters[index]
		var commandIndex = 0
		while commandIndex < fighter.queueCount {
			if fighter.queue[commandIndex].expires < frame { fighter.removeCommand(at: commandIndex) }
			else { commandIndex += 1 }
		}

		if fighter.stun > 0 {
			fighter.stun -= 1
			if fighter.stun > 6 { fighter.clearCommands() }
			if fighter.pose != .frozen { fighter.x += fighter.vx; fighter.vx = fighter.vx * 3 / 4 }
			if fighter.stun == 0 {
				fighter.pose = fighter.airborne ? .jump : .idle
				fighter.caughtBy = .none
			}
		} else {
			if !fighter.airborne { fighter.resetChain() }
			if fighter.move != .none {
				fighter.moveFrame += 1
				if fighter.moveFrame >= fighter.move.data.total {
					fighter.move = .none
					fighter.pose = fighter.airborne ? .jump : .idle
				}
			}
			if fighter.dashFrames > 0 {
				fighter.dashFrames -= 1
				if fighter.dashForward, fighter.input.contains(.block) || fighter.queueCount > 0 { fighter.dashFrames = 0 }
			}
			if fighter.queueCount > 0, fighter.dashFrames == 0, !fighter.input.contains(.block) {
				let command = fighter.queue[0]
				let continuation = command.predecessor != .none && command.predecessor == fighter.move && fighter.moveFrame >= fighter.move.data.linkFrame
				let cancel = command.move.isSpecial && fighter.connected && fighter.moveFrame >= fighter.move.data.cancelStart && fighter.moveFrame <= fighter.move.data.cancelEnd
				let neutral = fighter.move == .none && command.predecessor == .none
				let allowed = !command.move.isSpecial || !fighter.airborne
				let projectileAvailable = !command.move.isProjectile || !projectiles[index].active
				if (neutral || continuation || cancel), allowed, projectileAvailable {
					fighter.start(command.move)
					fighter.removeCommand(at: 0)
					events.add(.init(kind: command.move.isSpecial ? .special : .attack, player: index, move: command.move, x: fighter.x, y: fighter.y))
				} else if fighter.move == .none, command.predecessor != .none {
					fighter.removeCommand(at: 0)
				}
			}

			if fighter.move == .none {
				if !fighter.airborne {
					fighter.vx = 0
					fighter.pose = .idle
					if fighter.input.contains(.block) {
						fighter.pose = .guard
					} else if fighter.pendingJump {
						fighter.vy = 64
						fighter.vx = fighter.input.horizontal * 12
						fighter.pose = .jump
						fighter.dashFrames = 0
					} else if fighter.pendingDash != 0, fighter.input.vertical == 0 {
						fighter.dashDirection = fighter.pendingDash
						fighter.dashForward = fighter.pendingDash == fighter.facing
						fighter.dashFrames = 12
					}
					if fighter.dashFrames > 0 {
						fighter.vx = fighter.dashDirection * 25
						fighter.pose = .dash
					} else if fighter.pose != .guard, fighter.pose != .jump {
						if fighter.input.vertical < 0 { fighter.pose = .crouch }
						else if fighter.input.horizontal != 0 { fighter.pose = .walk; fighter.vx = fighter.input.horizontal * 9 }
						else { fighter.pose = .idle }
					}
				}
			} else {
				let move = fighter.move
				if move.isTeleport, !fighter.effectDone, fighter.moveFrame >= 8 {
					let target = fighters[1 - index]
					fighter.x = max(-Self.edge, min(Self.edge, target.x - target.facing * 210))
					fighter.facing = fighter.x < target.x ? 1 : -1
					fighter.effectDone = true
				}
				if move.isProjectile, !fighter.effectDone, fighter.moveFrame >= move.data.startup {
					projectiles[index] = .init(active: true, move: move, x: fighter.x + fighter.facing * 100,
						y: fighter.y + 385, vx: fighter.facing * (move == .rocket ? 26 : 22), oldX: fighter.x)
					fighter.effectDone = true
				}
				if move == .slide || move == .shadowKick {
					fighter.vx = fighter.moveFrame >= move.data.startup && fighter.moveFrame < move.data.startup + move.data.active ? fighter.facing * 30 : 0
				}
			}
			fighter.x += fighter.vx
		}
		fighter.pendingDash = 0
		fighter.pendingJump = false
		if fighter.airborne, fighter.pose != .frozen {
			fighter.y += fighter.vy
			fighter.vy -= 4 + Int32(fighter.chainHits)
			if fighter.y <= 0 {
				fighter.y = 0
				fighter.vy = 0
				fighter.vx = 0
				if fighter.falling {
					fighter.pose = .down
					fighter.stun = 20
					fighter.move = .none
					fighter.falling = false
					fighter.clearCommands()
				} else {
					fighter.move = .none
					if fighter.stun == 0 { fighter.pose = .idle }
				}
			}
		}
		fighter.x = max(-Self.edge, min(Self.edge, fighter.x))
		fighters[index] = fighter
	}

	private mutating func separate(left: Int) {
		guard !fighters[0].airborne, !fighters[1].airborne,
			!fighters[0].intangible, !fighters[1].intangible else { return }
		let right = 1 - left
		let overlap = 150 - (fighters[right].x - fighters[left].x)
		guard overlap > 0 else { return }
		fighters[left].x -= overlap / 2
		fighters[right].x += overlap - overlap / 2
		if fighters[left].x < -Self.edge {
			fighters[left].x = -Self.edge
			fighters[right].x = -Self.edge + 150
		}
		if fighters[right].x > Self.edge {
			fighters[right].x = Self.edge
			fighters[left].x = Self.edge - 150
		}
	}

	private mutating func advanceProjectile(_ index: Int) {
		guard projectiles[index].active else { return }
		var projectile = projectiles[index]
		projectile.age += 1
		projectile.oldX = projectile.x
		if projectile.move == .rang {
			if !projectile.returning, projectile.age >= 28 || abs(projectile.x) > Self.edge {
				projectile.returning = true
				projectile.contacted = false
			}
			if projectile.returning {
				let difference = fighters[index].x - projectile.x
				projectile.vx = difference < 0 ? -26 : 26
				projectile.y += (fighters[index].y + 385 - projectile.y) / 4
				if abs(difference) < 40 { projectile.active = false }
			}
		} else if abs(projectile.x) > Self.edge + 120 { projectile.active = false }
		if projectile.age > 150 { projectile.active = false }
		projectile.x += projectile.vx
		projectiles[index] = projectile
	}

	private mutating func resolve(_ contact: Contact, events: inout FrameEvents) {
		let source = contact.source
		let target = 1 - source
		let data = contact.move.data
		var victim = fighters[target]
		var damage: Int
		if contact.blocked {
			damage = max(1, data.damage / 10)
			victim.stun = data.blockstun
			victim.pose = .guard
			victim.vx = fighters[source].facing * 8
			victim.resetChain()
			hitstop = max(hitstop, 3)
		} else {
			damage = max(1, data.damage * max(25, 100 - victim.chainHits * 12) / 100)
			victim.chainHits += 1
			victim.chainDamage += damage
			victim.stun = data.hitstun
			victim.pose = .hit
			victim.move = .none
			victim.dashFrames = 0
			victim.vx = fighters[source].facing * 10
			victim.clearCommands()
			victim.caughtBy = .none
			switch data.effect {
			case .strike: break
			case .launch:
				if !victim.launched {
					victim.vy = 78
					victim.launched = true
					victim.falling = true
				}
			case .knockdown:
				victim.vy = max(victim.vy, 20)
				victim.falling = true
			case .pull, .freeze:
				if !victim.captured {
					victim.captured = true
					victim.caughtBy = contact.move
					victim.pose = .frozen
					victim.vx = 0
					victim.vy = 0
					if data.effect == .pull {
						victim.x = max(-Self.edge, min(Self.edge, fighters[source].x + fighters[source].facing * 175))
						victim.y = 0
					}
				} else { victim.stun = min(victim.stun, 12) }
			}
			fighters[source].comboHits = victim.chainHits
			fighters[source].comboDamage = victim.chainDamage
			fighters[source].comboFrame = frame
			hitstop = max(hitstop, 4)
		}
		victim.health = max(0, victim.health - damage)
		fighters[target] = victim
		events.add(.init(kind: contact.blocked ? .block : .hit, player: source, move: contact.move,
			damage: damage, x: victim.x, y: victim.y + 330))
	}

	private mutating func finishRound(events: inout FrameEvents) {
		guard fighters[0].health == 0 || fighters[1].health == 0 else { return }
		phase = .roundEnd
		phaseFrame = 0
		hitstop = 0
		for i in 0 ..< 2 { projectiles[i].active = false }
		winner = fighters[0].health == fighters[1].health ? nil : fighters[0].health > 0 ? 0 : 1
		events.add(.init(kind: .knockout, player: winner ?? 0))
		if let winner {
			fighters[winner].wins += 1
			events.add(.init(kind: .roundWin, player: winner))
			if fighters[winner].wins == 2 {
				phase = .matchEnd
				events.add(.init(kind: .matchWin, player: winner))
			}
		}
	}

	private mutating func resetRound() {
		if winner != nil { round += 1 }
		for i in 0 ..< 2 {
			let wins = fighters[i].wins
			fighters[i] = .init(character: fighters[i].character, side: i)
			fighters[i].wins = wins
			projectiles[i] = .init()
		}
		winner = nil
		phase = .intro
		phaseFrame = 0
	}
}
