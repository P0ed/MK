# Local Kombat

A small MK9-inspired Swift fighter with RealityKit graphics. Scorpion, Sub-Zero,
Jade, Sektor, Cyrax, Kitana, Smoke, and Liu Kang each have three specials, a unique
directional string, combat tuning, and low-poly articulated rigs. One player
fights the CPU; two players fight on the same machine. Practice provides an idle
dummy and infinite health.

Requires Xcode 27 / Swift 6.4. Deployment: iOS/iPadOS 27.0 and Mac Catalyst 27.0,
matching `../PG`'s universal UIKit setup. The fight uses a 16:9 canvas; iPhone uses
landscape, while iPad windows can rotate and resize.

## Run

Open `MK.xcodeproj`, select the **MK** scheme, and run on **My Mac (Mac Catalyst)**
or an iPhone/iPad. For a physical iOS device, choose your development team in
Signing & Capabilities.

Unsigned Mac build:

```sh
xcodebuild -project MK.xcodeproj -scheme MK -configuration Release \
  -destination 'generic/platform=macOS,variant=Mac Catalyst' \
  -derivedDataPath build/Catalyst CODE_SIGNING_ALLOWED=NO build
open build/Catalyst/Build/Products/Release-maccatalyst/MK.app
```

Simulator/device build checks:

```sh
xcodebuild -scheme MK -configuration Release -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -scheme MK -configuration Release -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

## Controls

| Action | Xbox / PlayStation | Keyboard |
|---|---|---|
| Move, crouch, jump | D-pad | Arrows |
| Front punch (1) | X / Square | A |
| Back punch (2) | Y / Triangle | S |
| Front kick (3) | A / Cross | Z |
| Back kick (4) | B / Circle | X |
| Block | RT / R2 | Space |
| Pause | Menu | Escape |
| Confirm / back in menus | A / B, Cross / Circle | Enter / Backspace |

Thumbsticks are ignored. There are no gameplay touch controls; menus support
pointer/touch input. Jump diagonally with up + left/right. Double-tap forward or
back within a third of a second to dash. Release the direction between taps.
Forward dashes can cancel into an attack or block.

The device choosing the mode owns player one. In **Two Players**, a second
controller or the keyboard joins with A / Enter. Each player picks and confirms
their own fighter. In **One Player**, pick your fighter and then the CPU fighter.
Mirror matches are supported. Disconnecting pauses the match; reconnect and
explicitly resume. Held commands are cleared on pause.

In **Practice**, choose your fighter and then the dummy. The dummy has no AI and
both fighters have infinite health, including protection from chip damage.
Hits, stun, launches, and combo damage still work; practice has no round wins or
KO results. Use **Pause → Reset Practice** to return both fighters to their
starting positions and clear attacks, projectiles, and the current combo while
keeping the selected matchup.

The roster uses a four-column, two-row grid; left/right cycles fighters and
up/down switches rows. Character select shows each fighter's strength and
playstyle. Strength is deliberately uneven: picking a stronger fighter makes
one-player fights more forgiving, while picking a stronger CPU raises the
challenge. These differences also apply in two-player matches.

| Strength | Fighters | Tradeoffs |
|---|---|---|
| Strong | Scorpion, Sektor, Liu Kang | Reliable pulls, teleports, rocket pressure, or powerful fast kicks. |
| Standard | Jade, Kitana | Lighter hits offset by staff reach, returning blades, or fast footwork. |
| Challenge | Sub-Zero, Cyrax, Smoke | Slower capture fighters or risky ambushes that reward deliberate setups and follow-ups. |

These labels consider the complete kit. Cyrax and Sub-Zero hit harder with
normals, but their slower footwork and capture setups make them harder to use.

Use **MOVES** in character select to read the selected fighters' commands.

## Moves

Directions are relative to the opponent: **F** toward, **B** away, **D** down.
For specials, press directions in order, followed by the numbered attack. For
directional attacks, hold the direction while pressing the attack. Inputs mirror
automatically when you switch sides.

| Fighter | Special 1 | Special 2 | Special 3 |
|---|---|---|---|
| Scorpion | B, F + 1 — spear and pull | D, B + 3 — teleport strike | D, B + 4 — low takedown |
| Sub-Zero | D, F + 1 — ice freeze | B, F + 4 — slide | D, B + 2 — close-range ice burst |
| Jade | D, F + 1 — returning razor-rang | B, F + 4 — shadow kick | D, B + 2 — staff-spin launcher |
| Sektor | B, F + 1 — rocket | D, F + 4 — teleport uppercut | D, B + 2 — flame burner |
| Cyrax | B, F + 1 — immobilizing net | D, B + 4 — delayed ground bomb | D, F + 2 — buzzsaw |
| Kitana | D, F + 1 — fast fan throw | B, F + 2 — close-range fan lift | D, B + 3 — overhead square wave |
| Smoke | D, B + 1 — delayed smoke-cloud launcher | D, F + 3 — overhead smoke teleport | D, B + 2 — smoke strike |
| Liu Kang | D, F + 1 — mid fireball | B, F + 4 — flying kick | B, F + 3 — bicycle kick |

**B + 1** is a standing launcher for every fighter. Each fighter also has a
unique two-hit string that ends in a launcher. Release and press again for
repeated buttons such as Sektor's **F + 4, 4**.

The following close-range routes connect four hits for roughly **30–40%** damage:
**B + 1 → unique string → combo ender**. After B + 1 recovers, enter the string
and buffer its second attack. Enter the ender's motion as the second attack
connects. Damage is original tuning for this game, rather than MK9 frame data.

| Fighter | Unique string | Combo ender | Damage |
|---|---|---|---|
| Scorpion | Hellfire rush: F + 2, 1 | D, B + 3 — teleport | 32.0% |
| Sub-Zero | Frost hammer: B + 2, 2 | D, B + 2 — ice burst | 32.4% |
| Jade | Staff dance: F + 3, 4 | D, B + 2 — staff spin | 30.3% |
| Sektor | Thruster combo: F + 4, 4 | D, B + 2 — flame burner | 35.6% |
| Cyrax | Cyber crush: F + 2, 3 | D, F + 2 — buzzsaw | 37.6% |
| Kitana | Royal grace: B + 2, 1 | D, B + 3 — square wave | 31.5% |
| Smoke | Vapor trail: F + 3, 2 | D, B + 2 — smoke strike | 32.5% |
| Liu Kang | Dragon's tail: F + 3, 3 | B, F + 3 — bicycle kick | 36.7% |

Strings: **1,1,2** knocks down, **2,1,2** launches, **3,4** ends low. Follow-ups
can be entered during the current string. Cancel designated attacks into specials
after connecting on hit or block. Down + 2 is an uppercut; down + 4 is a sweep.
Uppercuts use a shorter launch arc that still allows follow-up attacks.
Each attack button also has a jumping attack. Normal attack timings, reach,
damage, and movement vary by fighter; Jade's arm attacks use her staff and
Kitana fights with her fans. Cyrax's net captures without pulling, his bomb
lands before exploding low, and Smoke's cloud sets a delayed trap ahead of him.
Liu Kang's fireball catches crouching opponents; high projectiles can be ducked.
Spear pulls, ice freezes (including Ice Burst), and net binds hold the opponent
twice as long to give more time for follow-ups.

Standing block stops highs, mids, and overheads. Crouching block stops mids and
lows. Crouching avoids high attacks; overheads punish crouch-blocking. Blocking
causes small chip damage. Airborne fighters cannot block.

In scored matches, health resets each round. First to **two wins**, at most three scored rounds;
double KO retries the current round. The defeated fighter finishes falling
before the result menu appears, with at least a one-second KO beat. Rounds are
untimed. No meter, breakers,
throws, fatalities, X-rays, progression, or networking.

## Code and validation

- `COR`: a headless, noncopyable `Fight` with fixed 60 Hz steps, integer motion,
  inline inputs/events/projectiles, frame tables, hitboxes, and a delayed CPU.
- `MK`: UIKit menus/HUD and device ownership, non-AR RealityKit rendering, cached
  code-authored meshes, smoothly blended procedural poses, character-specific
  effects, and a preloaded eight-voice sound pool. Teleports dissolve and reform
  along a visible transition; render animation keeps combat timing unchanged.
- Move timings and damage are original compact tuning in `COR/Sources/Moves.swift`.
  One launcher and one capture are allowed per combo; damage scales down and
  juggle gravity increases. Jade's razor-rang connects once per flight leg.

Run the meaningful combat checks:

```sh
swift test --package-path COR
swift test --package-path COR -c release
```

Tests cover frame timing, buffered/invalid strings, all eight unique strings and
third specials, mirrored directional attacks, special priority, hit/block
cancels, preventing cancels after a whiff, four-hit 30–40% combo routes, input
taps, guard levels, trades, dashes, jumps, projectiles, round scoring, pause
clearing, seeded CPU matches, practice health/reset/no-AI behavior, KO landing
without repeated scoring, and identical results at 30/60/120 Hz rendering.

In a Debug build, `--demo` runs CPU-versus-CPU matches for visual smoke testing.
Add `--fighters 2 3` for Jade versus Sektor (0 Scorpion, 1 Sub-Zero, 2 Jade,
3 Sektor, 4 Cyrax, 5 Kitana, 6 Smoke, 7 Liu Kang). These arguments are not enabled
in Release builds.

## Assets

All meshes are authored in Swift and cached before fighting. No downloaded art,
model files, sampled recordings, or external package dependencies.

Regenerate the bundled 17 WAV effects with the standalone Swift CLI package
(48 kHz mono, 16-bit PCM):

```sh
swift run --package-path Scripts/SoundGen -c release soundgen --output MK/Sounds
```

The generator uses seeded noise, layered low-frequency impact bodies, sharp
transients, filtered air and metal textures, and smooth saturation. It creates
the effects procedurally without recordings or coarse waveform quantization.
Use `soundgen --help` for output options.

Regenerate the procedural app icon on macOS:

```sh
swift Scripts/icon.swift
```
