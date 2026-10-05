# Shadow Siphon

Advanced Game Design (Lec/Lab) - Midterm Mini-Project, Milestone 2 (Alpha Build)
Built with **Godot 4.7** (GDScript). Instructor: Prof Rob Malitao.

Team: *Christian Paean Ylai F. Bisquera / Andrew Ryan T. Miranda*

## Concept

The Protagonist must sneak past a patrolling Antagonist guard and activate two extraction
switches to open the exit door. The room is dark: only lit lamps expose you. You can
toggle the lamps to create shadows to hide in, or click a lamp from far away to make noise
and lure the guard away from your path.

**Win:** activate both extraction switches, then reach the exit door.
**Lose:** the guard catches you.

## Controls

|Key|Action|
|-|-|
|W A S D|Move|
|Shift|Sneak (guard sees you from a shorter distance when you are lit)|
|E|Use a lamp or extraction switch|
|R|Restart after winning or losing|

## Two ways to solve it

1. **Stealth through shadows** - switch lamps off and move through the dark. In shadow the guard only notices you from very close.
2. **Distraction** - clicking a lamp makes noise. The guard walks over to investigate, leaving his route open.

## How to run

* **Build:** unzip `Build\_ShadowSiphon.zip` and run `ShadowSiphon.exe`.
* **From source:** open the project folder in Godot 4.7 or newer and press F5 (main scene is `menu.tscn`).

## Project structure

|File|Purpose|
|-|-|
|`menu.tscn` / `menu.gd`|Start menu (Start / Quit)|
|`main.tscn`|Game scene: room, characters, lamps, switches, exit, HUD, audio|
|`game.gd`|Game loop: switch counter, exit door, win/lose, HUD text, restart|
|`player.gd`|Protagonist movement, sneaking, interaction, lit/hidden check, animation states|
|`antagonist.gd`|Guard AI state machine, vision, hearing, navigation|
|`lamp.gd`|Toggleable light source, line-of-sight lighting check, noise lure|
|`extraction\_switch.gd`|Switch state, dual-state material swap, reports to `game.gd`|
|`audio.gd`|Background music, detection sound crossfade, victory theme|
|`Protagonist.glb`, `Antagonist.glb`, `SS\_Room.glb`|Models, rigs and animations exported from Blender|

## Systemic architecture

* **Lighting drives detection.** `lamp.gd` exposes `illuminates(point)`, which checks radius and uses a raycast so walls block the light. `player.gd` asks every lamp each physics frame whether the player is lit.
* **Guard state machine** (`antagonist.gd`): `PATROL -> CHASE -> INVESTIGATE -> PATROL`. Lamp clicks within hearing range send the guard to `INVESTIGATE`.
* **Perception rules:** while lit, the guard sees the player inside a 90 degree vision cone up to 9 m (60% of that when sneaking). In shadow, he only notices the player within 1.8 m. A raycast line-of-sight check means walls and props block vision.
* **Pathfinding:** `NavigationAgent3D` on a baked `NavigationRegion3D`, so the guard walks around obstacles.
* **Animation state machines:** both characters use an `AnimationTree` with `Idle`, `Walk` and `Action` states, driven from the scripts.
* **Audio reacts to guard state:** music fades out and the detection sound plays whenever the guard is not on `PATROL`; they swap back when he calms down.

## Asset pipeline

Blender (modeling, UV unwrap, rigging, weight painting, animation actions) -> glTF 2.0 `.glb` export (one file per character, all actions exported) -> Godot import (materials, loop modes, collision, navigation mesh) -> Windows build.

## Audio credits

Third-party tracks used for this class demonstration only: *Stealth Music - Hunter*, the Metal Gear Solid alert sound and the Final Fantasy VII victory fanfare. Replace with royalty-free audio before any public release.

