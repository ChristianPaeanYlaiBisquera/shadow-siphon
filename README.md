# Shadow Siphon

Advanced Game Design (Lec/Lab) - Final Project (Lesson 9)
Built with **Godot 4.7** (GDScript). Instructor: Prof Rob Malitao.

Team: *Christian Paean Ylai F. Bisquera / Andrew Ryan T. Miranda*

## Concept

The Protagonist must sneak past a patrolling Antagonist guard and activate two extraction
switches to open the exit door. The room is dark: only lit lamps expose you. You can
toggle the lamps to create shadows to hide in, or press E on a lamp to make noise
and lure the guard away from your path.

**Win:** activate both extraction switches, then reach the exit door.

**Lose:** the guard hits you down to 0 health (100 HP, 20 damage per hit). Each hit gives you
1 second of invulnerability (the Protagonist blinks white), plus a red screen flash,
a spark burst and a short camera shake.

## Controls

|Key|Action|
|-|-|
|W A S D|Move|
|Shift|Sneak (guard sees you from a shorter distance when you are lit)|
|E|Use a lamp or extraction switch (a "Press E" bubble shows when one is in reach)|
|R|Restart the level|
|Mouse|Click the menu buttons and the Win / Game Over buttons|

## Screens

* **Main menu** (`main_menu.tscn`): **Play** starts the game, **Quit** closes it.
* **Win** ("YOU ESCAPED!") and **Game Over** overlays: **Restart** (or press R) reloads the level, **Main Menu** returns to the start menu.

## Two ways to solve it

1. **Stealth through shadows** - switch lamps off and move through the dark. In shadow the guard only notices you from very close.
2. **Distraction** - pressing E on a lamp toggles it and makes noise. If the guard is within 14 m he walks over to investigate, leaving his route open.

## How to run

* **Build:** run `ShadowSiphon.exe` (a single self-contained file, no install needed).
* **From source:** open the project folder in Godot 4.7 or newer and press F5 (main scene is `main_menu.tscn`).

## Building the .exe

Needs Godot 4.7 and the matching export templates (Editor > Manage Export Templates).
The Windows preset is saved in `export_presets.cfg` (x86_64, Embed PCK on).

1. Open **Project > Export...** and pick **Windows Desktop**.
2. Click **Export Project...**, untick **Export With Debug**, and save. The preset's path is `../Build_ShadowSiphon/ShadowSiphon.exe`, next to the project folder.
3. The result is one `ShadowSiphon.exe` of about 126 MB, with no extra DLLs.

Command-line equivalent (replace `godot` with the path to your Godot executable; it writes to the preset's path):

```
godot --headless --path . --export-release "Windows Desktop"
```

## Project structure

|File|Purpose|
|-|-|
|`main_menu.tscn` / `main_menu.gd`|Start menu (Play / Quit)|
|`main.tscn`|Game scene: room, characters, lamps, switches, exit, HUD, audio|
|`game.gd`|Game loop: switch counter, exit door, win/lose, HUD text, health bar, "Press E" bubble, Win / Game Over overlay (Restart / Main Menu), hit effects|
|`player.gd`|Protagonist movement, sneaking, interaction, lit/hidden check, health and i-frames, animation states|
|`antagonist.gd`|Guard AI state machine (patrol, chase, attack, investigate), vision, hearing, navigation|
|`lamp.gd`|Toggleable light source, line-of-sight lighting check, noise lure|
|`extraction_switch.gd`|Switch state, dual-state material swap, reports to `game.gd`|
|`audio.gd`|Background music, detection sound crossfade, victory theme|
|`export_presets.cfg`|Windows Desktop export preset (embedded PCK, so the build is one .exe)|
|`Protagonist.glb`, `Antagonist.glb`, `SS_Room.glb`|Models, rigs and animations exported from Blender|

## Systemic architecture

* **Lighting drives detection.** `lamp.gd` exposes `illuminates(point)`, which checks radius and uses a raycast so walls block the light. `player.gd` asks every lamp each physics frame whether the player is lit.
* **Guard state machine** (`antagonist.gd`): `PATROL -> CHASE -> ATTACK`. If the player escapes: `CHASE -> INVESTIGATE -> PATROL`. Pressing E on a lamp within its 14 m hearing range sends the guard to `INVESTIGATE`, unless he is already chasing or attacking.
* **Attack and damage:** within 1.6 m with a clear line, the guard stops and swings (0.4 s windup, 1.5 s cooldown). The hit only lands if the player is still within about 2.1 m with a clear line when the windup ends, so you can dodge by stepping away or behind cover. A landed hit calls `take_damage(20)` on the player.
* **I-frames and hit feedback:** after a hit the player ignores damage for 1 second (`iframe_time` in `player.gd`) and the model blinks white. Each hit also triggers a red screen flash, an HP bar pulse, a spark burst and a camera shake (`hit_effect()` in `game.gd`).
* **Perception rules:** while lit, the guard sees the player inside a 90 degree vision cone up to 9 m (60% of that when sneaking). In shadow, he only notices the player within 1.8 m. A raycast line-of-sight check means walls and props block vision.
* **Pathfinding:** `NavigationAgent3D` on a baked `NavigationRegion3D`, so the guard walks around obstacles.
* **Animation state machines:** both characters use an `AnimationTree` with `Idle`, `Walk` and `Action` states, driven from the scripts.
* **Audio reacts to guard state:** music fades out and the detection sound plays whenever the guard is not on `PATROL`; they swap back when he calms down.
* **UI is built in code** (`game.gd`): HUD text, health bar, the "Press E" bubble that follows the lamp or switch, and the Win / Game Over overlay.

## Asset pipeline

Blender (modeling, UV unwrap, rigging, weight painting, animation actions) -> glTF 2.0 `.glb` export (one file per character, all actions exported) -> Godot import (materials, loop modes, collision, navigation mesh) -> Windows build.

## Audio credits

Third-party tracks used for this class demonstration only: *Stealth Music - Hunter*, the Metal Gear Solid alert sound and the Final Fantasy VII victory fanfare. Replace with royalty-free audio before any public release.
