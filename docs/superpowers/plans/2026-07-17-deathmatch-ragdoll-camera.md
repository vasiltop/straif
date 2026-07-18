# Deathmatch Ragdoll Camera Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep the local player's ragdoll camera active and body visible from death until deathmatch respawn restores first-person view.

**Architecture:** `Player` will own two atomic local-view transitions: one for ragdoll view and one for first-person view. `ragdoll()` and `respawn()` will call those helpers only for the locally controlled player, leaving server timing, remote-player state, and elimination spectator overrides unchanged.

**Tech Stack:** Godot 4, GDScript, headless `SceneTree` regression tests

---

## File Structure

- Create `tests/death_camera_test.gd`: headless regression coverage for local ragdoll and first-person camera transitions.
- Modify `src/player/player.gd`: define the two local-view helpers and call them from `ragdoll()` and `respawn()`.

### Task 1: Activate the Complete Local Ragdoll View

**Files:**
- Create: `tests/death_camera_test.gd`
- Modify: `src/player/player.gd:77-90`

- [ ] **Step 1: Write the failing death-view regression test**

Create `tests/death_camera_test.gd`:

```gdscript
extends SceneTree

const PlayerScene := preload("res://src/player/player.tscn")

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player: Player = PlayerScene.instantiate()
	root.add_child(player)
	await process_frame

	player._show_local_ragdoll_view()

	_check(player.ragdoll_camera.is_current(), "Ragdoll camera should be current during death view")
	_check(player.third_person.visible, "Local third-person body should be visible during death view")
	_check(not player.weapon_handler.visible, "First-person weapon should be hidden during death view")
	_check(not player.gun_vp_container.visible, "Viewmodel viewport should be hidden during death view")

	player.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
godot --headless --path . --script tests/death_camera_test.gd
```

Expected: FAIL because `Player` does not define `_show_local_ragdoll_view()`.

- [ ] **Step 3: Add the local ragdoll-view helper**

Add this helper above `ragdoll()` in `src/player/player.gd`:

```gdscript
func _show_local_ragdoll_view() -> void:
	third_person.visible = true
	weapon_handler.visible = false
	set_viewmodel_viewport_visible(false)
	ragdoll_camera.make_current()
```

Replace the local camera/viewmodel assignments in `ragdoll()` so the method is:

```gdscript
@rpc("call_local", "authority", "reliable")
func ragdoll() -> void:
	bone_simulator.physical_bones_start_simulation()
	is_dead = true
	can_move = false
	weapon_handler.weapon_scene.visible = false

	if is_me():
		if sniper_overlay.visible:
			weapon_handler.toggle_sniper_scope()

		_show_local_ragdoll_view()
```

- [ ] **Step 4: Run the death-view test**

Run:

```bash
godot --headless --path . --script tests/death_camera_test.gd
```

Expected: PASS with exit code 0.

- [ ] **Step 5: Commit the death-view transition**

```bash
git add tests/death_camera_test.gd src/player/player.gd
git commit -m "fix: activate local ragdoll camera" \
  -m "Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>" \
  -m "Copilot-Session: c5086bef-2da0-4af6-bdc4-2e09e245365d"
```

### Task 2: Restore the Complete Local First-Person View

**Files:**
- Modify: `tests/death_camera_test.gd`
- Modify: `src/player/player.gd:92-106`

- [ ] **Step 1: Extend the regression test with the respawn transition**

Replace `tests/death_camera_test.gd` with:

```gdscript
extends SceneTree

const PlayerScene := preload("res://src/player/player.tscn")

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var player: Player = PlayerScene.instantiate()
	root.add_child(player)
	await process_frame

	player._show_local_ragdoll_view()

	_check(player.ragdoll_camera.is_current(), "Ragdoll camera should be current during death view")
	_check(player.third_person.visible, "Local third-person body should be visible during death view")
	_check(not player.weapon_handler.visible, "First-person weapon should be hidden during death view")
	_check(not player.gun_vp_container.visible, "Viewmodel viewport should be hidden during death view")

	player._show_local_first_person_view()

	_check(player.camera.is_current(), "Player camera should be current after respawn")
	_check(player.gun_camera.is_current(), "Gun camera should be current after respawn")
	_check(not player.third_person.visible, "Local third-person body should be hidden after respawn")
	_check(player.weapon_handler.visible, "First-person weapon should be visible after respawn")
	_check(player.gun_vp_container.visible, "Viewmodel viewport should be visible after respawn")

	player.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failed = true
	push_error(message)
```

- [ ] **Step 2: Run the test to verify the new assertions fail**

Run:

```bash
godot --headless --path . --script tests/death_camera_test.gd
```

Expected: FAIL because `Player` does not define `_show_local_first_person_view()`.

- [ ] **Step 3: Add the first-person helper and use it during respawn**

Add this helper immediately after `_show_local_ragdoll_view()` in
`src/player/player.gd`:

```gdscript
func _show_local_first_person_view() -> void:
	third_person.visible = false
	weapon_handler.visible = true
	set_viewmodel_viewport_visible(true)
	camera.make_current()
	gun_camera.make_current()
```

Replace the local camera/viewmodel assignments in `respawn()` so the method is:

```gdscript
@rpc("call_local", "authority", "reliable")
func respawn() -> void:
	bone_simulator.physical_bones_stop_simulation()
	is_dead = false
	can_move = true
	weapon_handler.weapon_scene.visible = true
	health = MAX_HEALTH
	damaged.emit(health)

	if is_me():
		weapon_handler.reset_ammo()
		_show_local_first_person_view()
```

- [ ] **Step 4: Run the complete camera-transition test**

Run:

```bash
godot --headless --path . --script tests/death_camera_test.gd
```

Expected: PASS with exit code 0.

- [ ] **Step 5: Commit the respawn transition**

```bash
git add tests/death_camera_test.gd src/player/player.gd
git commit -m "fix: restore local camera on respawn" \
  -m "Co-authored-by: Copilot App <223556219+Copilot@users.noreply.github.com>" \
  -m "Copilot-Session: c5086bef-2da0-4af6-bdc4-2e09e245365d"
```

### Task 3: Verify Camera and Existing Game Smoke Coverage

**Files:**
- Test: `tests/death_camera_test.gd`
- Test: `tests/offline_playtest_smoke.gd`
- Test: `tests/world_record_announcement_test.gd`

- [ ] **Step 1: Run all Godot regression scripts**

Run:

```bash
for test_script in \
  tests/death_camera_test.gd \
  tests/offline_playtest_smoke.gd \
  tests/world_record_announcement_test.gd
do
  godot --headless --path . --script "$test_script" || exit 1
done
```

Expected: all three scripts exit with code 0.

- [ ] **Step 2: Check the final diff**

Run:

```bash
git status --short
git diff --check
git diff --stat main...HEAD
```

Expected: no uncommitted files, no whitespace errors, and only the design,
implementation plan, player camera logic, and camera regression test in the
branch diff.
