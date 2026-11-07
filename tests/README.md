# Automated tests

Headless Godot scripts that load the real levels, drive the game with simulated input and print what they measure.
They are not part of the game: the export preset leaves `tests/*` out of the build.

Run one from the project folder (use the `_console` Godot executable on Windows to see the output):

```
godot --headless --path . --script res://tests/combat_test.gd
```

`ui_test.gd` and `combat_test.gd` list every check as `ok` / `FAIL`, print `== ALL OK` and exit with 0 when all pass
(otherwise the exit code is the number of failures). The other scripts print what they measured; the last column says what a good run looks like.

|Script|What it checks|A good run shows|
|-|-|-|
|`ui_test.gd`|Music / SFX buses, saved volumes (`user://settings.cfg`, clamped, restored), Esc pause (freeze, music keeps playing, Resume / Restart / Main Menu), How to Play screen, sliders, layout, on both levels and the main menu|`== ALL OK`|
|`combat_test.gd`|The upper-body layer (mask = 6 bones, legs still follow Walk while the arm swings), animation events at 0.16 s / 0.30 s, one hit per swing, no hit out of range or behind, knockback, stun, health bar, death, hit-stop and the time scale coming back|`== ALL OK`|
|`chase_attack_test.gd`|A guard coming from 8 directions always ends up swinging at a player who stands still|`guards that never swung / never hit: 0 of 8` for both levels|
|`level_flow_test.gd`|Level 1 win, Next Level, Level 2 content (3 guards, 6 lamps, dark spawn), guards patrol on the NavMesh, 4 switches open the exit and the exit wins|`SWITCH 4 -> done 4/4 exit_open=true`, `WIN ... title='YOU ESCAPED!'`|
|`guard_lure_chase_test.gd`|Lamp noise sends guards to INVESTIGATE and back to PATROL; a lit player is chased and attacked until the game is over|`CHASE ... states seen: [PATROL, CHASE, HIT, ATTACK]`|
|`guard_lure_test.gd`|The original huddle bug: every lured guard reaches the lamp spot, then returns to PATROL, and guards do not pile up|every guard ends in PATROL, closest two guards about 1 m apart|
|`guard_pathing_test.gd`|A guard standing at a spot does not block a patrolling guard; three guards chasing do not pile up; a player in a rack aisle the guards cannot enter does not cause a lock-up; Level 1 patrol|Guard1 keeps patrolling, all three reach ATTACK, closest two guards at least 1 m apart|
|`sfx_test.gd`|Lamp, wall switch, exit door and hit effect each start their sound once and free the player node afterwards|`players=0` at the end of each level|
|`music_test.gd`|Music level (-5 dB), ducked out while a guard is alerted, back at -5 dB when he calms down|`music=-80.0` while alerted, `music=-5.0` afterwards|
|`hit_sound_test.gd`|The hit sound plays once per landed hit, not for a hit blocked by i-frames|`1`, `1`, then `0` after the clip|

Notes:
- Every script starts with `await process_frame`: the `Settings` autoload is registered only after a `SceneTree` script's `_init`.
- The scripts change `Engine.time_scale` and some write `user://settings.cfg`; `ui_test.gd` deletes the file when it finishes.
- In Level 1 the guard spots a player who stands still at the spawn within the first second, so tests that need a calm start set the guard's `sight_range` and `close_range` to 0.
