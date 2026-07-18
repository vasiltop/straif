# Deathmatch Ragdoll Camera Design

## Problem

In deathmatch, a local player can see only the skybox after dying and while
waiting for the server-controlled respawn. The player should instead watch
their own ragdoll for the full 1.5-second death-to-respawn delay.

The player scene currently splits local death-view state across unrelated
properties. `setup()` hides the local third-person body, while `ragdoll()`
starts physical-bone simulation and selects the ragdoll camera without showing
that body. `respawn()` restores first-person cameras separately. This incomplete
transition allows camera ownership and model visibility to drift apart.

## Scope

This change will:

- centralize the local death and respawn view transitions in `Player`;
- show the local third-person model while its ragdoll camera is active;
- keep the ragdoll camera current until respawn;
- restore the first-person and gun cameras, viewmodel, and hidden local body on
  respawn;
- preserve the existing deathmatch respawn delay and elimination spectating.

It will not change Gamma geometry, spawn markers, deathmatch timing, damage
rules, or spectator target selection.

## Design

`Player` remains the owner of local camera state. Small local-view helpers will
make each transition atomic:

1. The death-view helper shows `third_person`, hides the first-person weapon
   viewport, hides the weapon handler, and calls
   `ragdoll_camera.make_current()`.
2. The first-person helper hides `third_person`, calls `camera.make_current()`
   and `gun_camera.make_current()`, shows the weapon handler, and restores the
   weapon viewport.

`ragdoll()` will start physical-bone simulation and update death state before
calling the death-view helper for the locally controlled player. `respawn()`
will stop simulation and reset gameplay state before calling the first-person
helper for the locally controlled player.

Remote players will not run either local-view helper. Their existing
third-person representation and replicated ragdoll behavior remain unchanged.
Elimination spectating may continue to override camera ownership through
`begin_local_spectate_view()` and `end_local_spectate_view()`; when no teammate
is available, its existing ragdoll-camera selection remains compatible with
the centralized death view.

## Error Handling

The exported player cameras are required scene dependencies. The transition
will not silently fall back to an arbitrary camera when a dependency is
missing, because that would recreate the skybox symptom and hide a broken
player scene configuration.

## Testing

A headless Godot regression test will instantiate the player scene and exercise
the local view-transition helpers. It will assert that:

- death view makes the ragdoll camera current;
- death view shows the local third-person body and hides the viewmodel;
- first-person view makes the player and gun cameras current in their
  respective viewports;
- first-person view hides the local third-person body and restores the
  viewmodel.

The existing Godot smoke tests will run alongside the new regression test to
catch scene-loading and script regressions.
