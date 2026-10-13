public enum Phase: Sendable { case intro, fighting, roundEnd, matchEnd }
public enum EventKind: Sendable { case none, attack, special, hit, block, roundStart, knockout, roundWin, matchWin, detonate }

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
	public internal(set) var vy: Int32 = 0
	public internal(set) var age = 0
	public internal(set) var returning = false
	public internal(set) var detonating = false
	var contacted = false
	var oldX: Int32 = 0

	var box: Box {
		if move == .bomb { return .init(left: x - 170, bottom: 0, right: x + 170, top: 240) }
		if move == .smokeCloud { return .init(left: x - 90, bottom: y - 170, right: x + 90, top: y + 170) }
		if move == .net { return .init(left: min(x, oldX) - 40, bottom: y - 90, right: max(x, oldX) + 40, top: y + 90) }
		return .init(left: min(x, oldX) - 26, bottom: y - 24, right: max(x, oldX) + 26, top: y + 24)
	}

	var canHit: Bool {
		active && (move != .bomb || detonating) && (move != .smokeCloud || age >= 10)
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
	public let practice: Bool

	/// Results can be presented once the defeated fighter's last airborne arc has landed.
	public var defeatedSettled: Bool {
		guard phase == .roundEnd || phase == .matchEnd else { return false }
		for index in 0 ..< 2 where fighters[index].health == 0 {
			if fighters[index].airborne || fighters[index].pose != .down { return false }
		}
		return true
	}

	public init(_ first: Character = .scorpion, _ second: Character = .sektor, practice: Bool = false) {
		fighters = [.init(character: first, side: 0), .init(character: second, side: 1)]
		self.practice = practice
		if practice { phase = .fighting }
	}

	init(fighters: consuming InlineArray<2, Fighter>, phase: Phase = .fighting, round: Int = 1,
		projectiles: consuming InlineArray<2, Projectile> = .init(repeating: .init()), practice: Bool = false) {
		self.fighters = fighters
		self.phase = phase
		self.round = round
		self.projectiles = projectiles
		self.practice = practice
	}

	/// The only combat entry point. Results and runtime storage stay inline.
	public mutating func step(_ inputs: borrowing InlineArray<2, InputFrame>) -> FrameEvents {
		frame += 1
		var events = FrameEvents()
		for i in 0 ..< 2 { fighters[i].ingest(inputs[i], frame: frame) }

		guard phase == .fighting else {
			for i in 0 ..< 2 { fighters[i].clearCommands() }
			phaseFrame += 1
			if phase == .roundEnd || phase == .matchEnd { settleAfterKnockout() }
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
		for i in 0 ..< 2 { advanceProjectile(i, events: &events) }

		var contacts: InlineArray<4, Contact> = .init(repeating: .init())
		var count = 0
		for i in 0 ..< 2 {
			let target = 1 - i
			let fighter = fighters[i]
			if fighter.move != .none, !fighter.move.isProjectile, !fighter.contacted,
				fighter.moveFrame >= fighter.moveData.startup,
				fighter.moveFrame < fighter.moveData.startup + fighter.moveData.active,
				!fighters[target].intangible, fighter.hitbox.overlaps(fighters[target].hurtbox) {
				contacts[count] = .init(source: i, move: fighter.move, blocked: fighters[target].guards(fighter.moveData.level))
				count += 1
				fighters[i].contacted = true
				fighters[i].connected = true
			}
			let projectile = projectiles[i]
			if projectile.canHit, !projectile.contacted, !fighters[target].intangible,
				projectile.box.overlaps(fighters[target].hurtbox) {
				contacts[count] = .init(source: i, move: projectile.move, blocked: fighters[target].guards(projectile.move.data.level))
				count += 1
				projectiles[i].contacted = true
				if projectile.move != .rang && projectile.move != .bomb && projectile.move != .smokeCloud { projectiles[i].active = false }
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

	/// Restart drills without an intro, leftover inputs or a scored round.
	public mutating func resetPractice() {
		guard practice else { return }
		for i in 0 ..< 2 {
			fighters[i] = .init(character: fighters[i].character, side: i)
			projectiles[i] = .init()
		}
		frame = 0
		phase = .fighting
		phaseFrame = 0
		round = 1
		winner = nil
		hitstop = 0
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
				if !fighter.airborne { fighter.resetChain() }
			}
		} else {
			if !fighter.airborne { fighter.resetChain() }
			if fighter.move != .none {
				fighter.moveFrame += 1
				if fighter.moveFrame >= fighter.moveData.total {
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
				let continuation = !command.move.isSpecial && command.predecessor != .none && command.predecessor == fighter.move && fighter.moveFrame >= fighter.moveData.linkFrame
				let cancel = command.move.isSpecial && !fighter.move.isSpecial && fighter.connected
					&& (command.predecessor == .none || command.predecessor == fighter.move)
					&& fighter.moveFrame >= fighter.moveData.cancelStart && fighter.moveFrame <= fighter.moveData.cancelEnd
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
						fighter.vx = fighter.input.horizontal * (fighter.character.walkSpeed + 3)
						fighter.pose = .jump
						fighter.dashFrames = 0
					} else if fighter.pendingDash != 0, fighter.input.vertical == 0 {
						fighter.dashDirection = fighter.pendingDash
						fighter.dashForward = fighter.pendingDash == fighter.facing
						fighter.dashFrames = 12
					}
					if fighter.dashFrames > 0 {
						fighter.vx = fighter.dashDirection * fighter.character.dashSpeed
						fighter.pose = .dash
					} else if fighter.pose != .guard, fighter.pose != .jump {
						if fighter.input.vertical < 0 { fighter.pose = .crouch }
						else if fighter.input.horizontal != 0 { fighter.pose = .walk; fighter.vx = fighter.input.horizontal * fighter.character.walkSpeed }
						else { fighter.pose = .idle }
					}
				}
			} else {
				let move = fighter.move
				if move.isTeleport, !fighter.effectDone, fighter.moveFrame >= (move == .smokeTeleport ? 12 : 8) {
					let target = fighters[1 - index]
					if move == .smokeTeleport {
						fighter.x = max(-Self.edge, min(Self.edge, target.x - fighter.facing * 180))
						fighter.y = 180
						fighter.vy = -12
					} else {
						fighter.x = max(-Self.edge, min(Self.edge, target.x - target.facing * 210))
					}
					fighter.facing = fighter.x < target.x ? 1 : -1
					fighter.effectDone = true
				}
				if move.isProjectile, !fighter.effectDone, fighter.moveFrame >= fighter.moveData.startup {
					var projectile = Projectile(active: true, move: move, x: fighter.x + fighter.facing * 100,
						y: fighter.y + 385, vx: fighter.facing * 22, oldX: fighter.x)
					switch move {
					case .rocket: projectile.vx = fighter.facing * 26
					case .fan: projectile.vx = fighter.facing * 34
					case .fireball: projectile.vx = fighter.facing * 30; projectile.y = 260
					case .net: projectile.vx = fighter.facing * 18
					case .bomb: projectile.vx = fighter.facing * 18; projectile.y = 220; projectile.vy = 34
					case .smokeCloud:
						projectile.x = max(-Self.edge, min(Self.edge, fighter.x + fighter.facing * 650))
						projectile.oldX = projectile.x
						projectile.y = 270
						projectile.vx = 0
					default: break
					}
					projectiles[index] = projectile
					fighter.effectDone = true
				}
				if move == .slide || move == .shadowKick || move == .flyingKick {
					let speed: Int32 = move == .flyingKick ? 48 : 30
					fighter.vx = !fighter.contacted && fighter.moveFrame >= fighter.moveData.startup && fighter.moveFrame < fighter.moveData.startup + fighter.moveData.active ? fighter.facing * speed : 0
				} else if fighter.moveData.advanceSpeed > 0, !fighter.airborne {
					let distance = max(0, (fighters[1 - index].x - fighter.x) * fighter.facing - 150)
					fighter.vx = !fighter.contacted && fighter.moveFrame < fighter.moveData.startup + fighter.moveData.active
						? fighter.facing * min(fighter.moveData.advanceSpeed, distance) : 0
				}
			}
			fighter.x += fighter.vx
		}
		fighter.pendingDash = 0
		fighter.pendingJump = false
		if fighter.airborne, fighter.pose != .frozen {
			fighter.y += fighter.vy
			fighter.vy -= 4 + Int32(min(3, fighter.chainHits / 3))
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
				} else if fighter.move != .smokeTeleport {
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

	private mutating func advanceProjectile(_ index: Int, events: inout FrameEvents) {
		guard projectiles[index].active else { return }
		var projectile = projectiles[index]
		projectile.age += 1
		projectile.oldX = projectile.x
		if projectile.move == .bomb {
			if projectile.age >= 48 {
				if !projectile.detonating {
					events.add(.init(kind: .detonate, player: index, move: .bomb, x: projectile.x, y: 0))
				}
				projectile.detonating = true
				projectile.y = 0
				projectile.vx = 0
				projectile.vy = 0
				if projectile.age >= 56 { projectile.active = false }
			} else {
				projectile.y += projectile.vy
				projectile.vy -= 3
				if projectile.y <= 0 {
					projectile.y = 0
					projectile.vy = 0
					projectile.vx = projectile.vx * 3 / 4
				}
			}
		} else if projectile.move == .smokeCloud {
			if projectile.age >= 42 { projectile.active = false }
		} else if projectile.move == .rang {
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
		if projectile.move == .bomb { projectile.x = max(-Self.edge, min(Self.edge, projectile.x)) }
		projectiles[index] = projectile
	}

	private mutating func resolve(_ contact: Contact, events: inout FrameEvents) {
		let source = contact.source
		let target = 1 - source
		let data = fighters[source].character.data(for: contact.move)
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
			damage = max(1, data.damage * max(20, 100 - victim.chainHits * 8) / 100)
			victim.chainHits += 1
			victim.chainDamage += damage
			victim.stun = data.hitstun
			victim.pose = .hit
			victim.move = .none
			victim.dashFrames = 0
			victim.vx = fighters[source].facing * (victim.chainHits > 1 ? 5 : 8)
			victim.clearCommands()
			victim.caughtBy = .none
			switch data.effect {
			case .strike:
				// A follow-up keeps a falling juggle reachable without granting another launcher.
				if victim.airborne, victim.falling { victim.vy = max(victim.vy, 20) }
			case .launch:
				if !victim.launched {
					victim.vy = data.launchSpeed
					victim.launched = true
					victim.falling = true
				} else if victim.airborne, victim.falling {
					victim.vy = max(victim.vy, 20)
				}
			case .knockdown:
				victim.vy = max(victim.vy, 20)
				victim.falling = true
			case .pull, .freeze, .bind:
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
		if !practice { victim.health = max(0, victim.health - damage) }
		fighters[target] = victim
		events.add(.init(kind: contact.blocked ? .block : .hit, player: source, move: contact.move,
			damage: damage, x: victim.x, y: victim.y + 330))
	}

	private mutating func finishRound(events: inout FrameEvents) {
		guard !practice else { return }
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
		for index in 0 ..< 2 {
			fighters[index].move = .none
			fighters[index].moveFrame = 0
			fighters[index].dashFrames = 0
			fighters[index].stun = 0
			fighters[index].input = []
			fighters[index].history = .init()
			fighters[index].clearCommands()
			fighters[index].caughtBy = .none
			if fighters[index].health == 0 {
				fighters[index].falling = fighters[index].airborne
				fighters[index].pose = fighters[index].airborne ? .hit : .down
			} else {
				fighters[index].falling = false
				fighters[index].pose = fighters[index].airborne ? .jump : .idle
			}
			if !fighters[index].airborne { fighters[index].vx = 0 }
		}
	}

	/// Ending phases keep only residual motion. No commands, contacts or scoring run here.
	private mutating func settleAfterKnockout() {
		for index in 0 ..< 2 {
			var fighter = fighters[index]
			fighter.input = []
			fighter.history = .init()
			fighter.clearCommands()
			if fighter.airborne {
				fighter.x = max(-Self.edge, min(Self.edge, fighter.x + fighter.vx))
				if fighter.health == 0 { fighter.vx = fighter.vx * 3 / 4 }
				fighter.y += fighter.vy
				fighter.vy -= 4 + Int32(fighter.health == 0 ? fighter.chainHits : 0)
			}
			// Authored arcs land much sooner; this bound also keeps result presentation finite.
			if fighter.y <= 0 || phaseFrame >= 90 {
				fighter.y = 0
				fighter.vy = 0
				fighter.vx = 0
				fighter.falling = false
				fighter.pose = fighter.health == 0 ? .down : .idle
			}
			fighters[index] = fighter
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
