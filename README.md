# Shadow Siphon

Advanced Game Design (Lec/Lab) - Final Project (Lesson 9)
Built with **Godot 4.7** (GDScript). Instructor: Prof Rob Malitao.

Team: *Christian Paean Ylai F. Bisquera / Andrew Ryan T. Miranda*

## Concept

The Protagonist must sneak past a patrolling Antagonist guard and activate two extraction
switches to open the exit door. The room is dark: only lit lamps expose you. You can
toggle the lamps to create shadows to hide in, or press E on a lamp to make noise
and lure the guard away from your path. If a guard catches you, you can fight back:
Space swings your upper body while your legs keep walking, and three hits take a guard down.

**Win:** activate both extraction switches, then reach the exit door. Level 1 leads on to Level 2 (see Levels).

**Lose:** the guard hits you down to 0 health (100 HP, 20 damage per hit). Each hit gives you
1 second of invulnerability (the Protagonist blinks white), plus a red screen flash,
a spark burst, a hit sound, a short camera shake and a brief hit-stop freeze.

## Controls

|Key|Action|
|-|-|
|W A S D|Move|
|Shift|Sneak (guard sees you from a shorter distance when you are lit)|
|E|Use a lamp or extraction switch (a "Press E" bubble shows when one is in reach)|
|Space|Attack: an upper-body swing over your walking legs (0.6 s cooldown); the hit lands at the impact frames and does 20 damage|
|R|Restart the level|
|Esc|Pause menu: Resume, Restart, How to Play, Main Menu and the Music / SFX volume sliders (Esc again resumes)|
|Mouse|Click the menu, pause and Win / Game Over buttons; drag the volume sliders|

## Screens

* **Main menu** (`main_menu.tscn`): **Play** starts the game, **How to Play** shows the controls, tips and volume sliders, **Quit** closes it.
* **Pause menu** (Esc during a level): the game freezes and the music keeps playing. **Resume**, **Restart**, **How to Play** and **Main Menu**, plus **Music** and **SFX** volume sliders (saved between runs). Esc does nothing on the Win / Game Over screen.
* **How to Play**: the controls, three tips and the volume sliders; opened from the main menu or the pause menu, closed with **Back** or Esc.
* **Win** ("YOU ESCAPED!") and **Game Over** overlays: **Restart** (or press R) reloads the level, **Main Menu** returns to the start menu.

## Levels

|Level|Scene|Layout|
|-|-|-|
|1|`main.tscn`|The original room: 1 guard, 3 lamps, 2 extraction switches.|
|2 - Warehouse|`level2.tscn`|The expanded warehouse: 3 guards, 6 lamps you can switch off, 4 extraction switches. You start in the dark north-west corner; the switches are in the west corridor, in the south-east nook (one on the nook's north wall, one on its east wall) and on the north-east wall, and the exit is the north door.|

Finishing Level 1 shows **LEVEL COMPLETE** with a **Next Level** button. Finishing Level 2 shows **YOU ESCAPED!**.

## Three ways to solve it

1. **Stealth through shadows** - switch lamps off and move through the dark. In shadow the guard only notices you from very close.
2. **Distraction** - pressing E on a lamp toggles it and makes noise. If the guard is within 14 m he walks over to investigate, leaving his route open.
3. **Fight** - Space swings at a guard in front of you. A guard has 60 health and takes 20 per hit: he flashes white, is knocked back about a metre, is stunned for half a second (his swing is interrupted), and shows a health bar. The third hit takes him down for good. A fight is loud: other guards within 10 m come to investigate.

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
|`main_menu.tscn` / `main_menu.gd`|Start menu (Play / How to Play / Quit)|
|`main.tscn`|Level 1: room, characters, lamps, switches, exit, HUD, audio|
|`level2.tscn`|Level 2: warehouse, 3 guards with their own patrol routes, 6 lamps, 4 switches, baked NavMesh|
|`game.gd`|Game loop: switch counter, exit door, win/lose, HUD text, health bar, "Press E" bubble, Win / Game Over overlay (Next Level / Restart / Main Menu), level hand-over, hit effects, `play_sfx()` one-shot sounds|
|`player.gd`|Protagonist movement, sneaking, interaction, lit/hidden check, health and i-frames, animation states, the upper-body attack layer and its hitbox|
|`antagonist.gd`|Guard AI state machine (patrol, chase, attack, investigate), vision, hearing, navigation, health, knockback, stun, death, floating health bar|
|`lamp.gd`|Toggleable light source, line-of-sight lighting check, noise lure|
|`extraction_switch.gd`|Switch state, dual-state material swap, reports to `game.gd`|
|`audio.gd`|Background music, detection sound crossfade, victory theme (all on the Music bus)|
|`pause_menu.gd`|Esc pause menu (Resume / Restart / How to Play / Main Menu and the volume sliders), created by `game.gd`|
|`help_panel.gd`|"How to Play" screen (controls, tips, volume sliders), used by the main menu and the pause menu|
|`settings.gd`|Autoload `Settings`: Music / SFX volumes, applied to the audio buses and saved in `user://settings.cfg`|
|`default_bus_layout.tres`|Audio buses: Master > Music, SFX|
|`export_presets.cfg`|Windows Desktop export preset (embedded PCK, so the build is one .exe)|
|`Protagonist.glb`, `Antagonist.glb`, `SS_Room.glb`, `SS_Warehouse.glb`, `SS_Lamp.glb`|Models, rigs, animations and level maps exported from Blender|

## Systemic architecture

* **Lighting drives detection.** `lamp.gd` exposes `illuminates(point)`, which checks radius and uses a raycast so walls block the light. `player.gd` asks every lamp each physics frame whether the player is lit.
* **Guard state machine** (`antagonist.gd`): `PATROL -> CHASE -> ATTACK`. If the player escapes: `CHASE -> INVESTIGATE -> PATROL`. Pressing E on a lamp within its 14 m hearing range sends the guard to `INVESTIGATE`, unless he is already chasing or attacking.
* **Attack and damage:** within 1.6 m with a clear line, the guard stops and swings (0.4 s windup, 1.5 s cooldown). The hit only lands if the player is still within about 2.1 m with a clear line when the windup ends, so you can dodge by stepping away or behind cover. A landed hit calls `take_damage(20)` on the player.
* **I-frames and hit feedback:** after a hit the player ignores damage for 1 second (`iframe_time` in `player.gd`) and the model blinks white. Each hit also triggers a red screen flash, an HP bar pulse, a spark burst, a hit sound, a camera shake and a hit-stop (`hit_effect()` and `hit_stop()` in `game.gd`). Hit-stop sets `Engine.time_scale` to 0.05 for 0.06 s of real time (0.12 s for a knock-out), using a timer that ignores the time scale; overlapping freezes are counted and the old time scale is restored.
* **Upper-body animation layer** (`player.gd`, `_setup_upper_body_layer()`): the scene's `Idle` / `Walk` / `Action` state machine becomes the `Locomotion` node of an `AnimationNodeBlendTree`, and an `AnimationNodeOneShot` named `UpperBody` plays a `Swing` clip on top of it. The OneShot's bone filter is the mask (the Godot version of a Unity Avatar Mask with an Override layer at weight 1): spine, chest, neck, head and both upper arms. Pelvis, hips, thighs, shins and feet are not in it, so the legs keep following the Walk clip while the arms swing. The partner's `Action` clip only moves the spine and head, so the `Swing` clip is keyed in code on the same bones, on top of the Idle pose (arm forward 95 degrees, chest twist, lean).
* **Hitbox / hurtbox pipeline:** the player's attack hitbox is an `Area3D` (a 0.9 m sphere, 1 m in front of the chest, child of the model so it turns with him). It is off by default and is switched on and off by two animation events on the Swing clip (method-call track, `enable_hitbox(true)` at 0.16 s and `enable_hitbox(false)` at 0.30 s, the impact frames). While it is live every guard inside it (and not behind a wall) is hit once per swing through `take_hit(damage, from)`. The guard's capsule collider is the hurtbox. `take_hit` removes health, knocks the guard back along the vector away from the attacker, stuns him for 0.5 s, interrupts his swing, flashes him white, shows his health bar and makes the scuffle audible to nearby guards. At 0 health he falls, is removed from the `antagonist` group and from the physics, and is freed a few seconds later.
* **Perception rules:** while lit, the guard sees the player inside a 90 degree vision cone up to 9 m (60% of that when sneaking). In shadow, he only notices the player within 1.8 m. A raycast line-of-sight check means walls and props block vision.
* **Pathfinding:** `NavigationAgent3D` on a baked `NavigationRegion3D`, so the guard walks around obstacles.
* **Animation state machines:** both characters use an `AnimationTree` with `Idle`, `Walk` and `Action` states, driven from the scripts.
* **Audio reacts to guard state:** music fades out and the detection sound plays whenever the guard is not on `PATROL`; they swap back when he calms down.
* **Interaction sounds:** `play_sfx()` in `game.gd` plays one-shot sounds: a click when a wall switch is activated, a light-switch sound when a lamp is toggled, and a sci-fi door sound when the exit opens (the hit sound uses it too).
* **Pause and volume:** Esc pauses with `get_tree().paused`. The pause menu, the How to Play panel and `audio.gd` run in `PROCESS_MODE_ALWAYS`, so the music keeps playing and the sliders can be heard. Music, alert and victory are on the `Music` bus, every one-shot sound on `SFX`. The `Settings` autoload applies the saved volumes at start-up and writes `user://settings.cfg` half a second after a slider stops moving.
* **UI is built in code** (`game.gd`): HUD text, health bar, the "Press E" bubble that follows the lamp or switch, and the Win / Game Over overlay (with a Next Level button between levels).
* **Several guards:** every guard has its own `Waypoints` node and `NavigationAgent3D`. A lamp noise reaches all guards in range, the HUD shows the most alert guard, and the music reacts to any guard. Guards steer around each other (agent avoidance), fan out around a shared target, head for the nearest walkable point when a target is not on the NavMesh (a lamp's own spot), and skip a waypoint or give up on a spot if they stop making progress.
* **Level 2 map:** `SS_Warehouse.glb` gets its colliders on import from the `-col` suffix on the Blender object names; the NavMesh is baked from them (limited to the building by a Baking AABB) and the lamps are children of the `NavigationRegion3D`, so the bake routes around them. Its floor and walls reuse Level 1's `Floor.tres` and `MAT_Wall.tres` (set in `SS_Warehouse.glb.import`), with world-space UVs at Level 1's texture scale.

## Asset pipeline

Blender (modeling, UV unwrap, rigging, weight painting, animation actions) -> glTF 2.0 `.glb` export (one file per character, only that character's Idle / Walk / Action animations) -> Godot import (materials, loop modes, collision, navigation mesh) -> Windows build.

## Audio credits

Third-party tracks used for this class demonstration only: *Stealth Music - Hunter*, the Metal Gear Solid alert sound, the Final Fantasy VII victory fanfare, the Undertale attack hit sound effect, and three interaction sounds: a button click (wall switches), a light switch (Freesound sample 168860 by orginaljun, lamps) and a sci-fi door opening (exit door). Replace with royalty-free audio, or check each license, before any public release.
