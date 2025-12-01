// Data-oriented approach - focus on data layout and transformations
// No state machine abstraction - just direct code

const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

// ============================================================================
// DATA DEFINITIONS - All data up front, plain and visible
// ============================================================================

const PlayerMode = enum {
    walking,
    deploying,
    combat,
};

const CombatMode = enum {
    selecting,
    moving,
    attacking,
};

// Simple, flat structure - no hidden behavior
const PlayerState = struct {
    mode: PlayerMode,
    movement_cooldown: f32,

    // Deploying state
    selected_puppet_id: ?u32,
    deploy_highlighted: bool,

    // Combat state
    combat_mode: CombatMode,
    selected_entity_id: ?u32,
    turn_taken: bool,
};

const Input = struct {
    movement: ?Vector2Int,
    action: bool, // A key
    cancel: bool, // B or ESC
    confirm: bool, // Space or Enter
    start_combat: bool, // F key
    number_key: ?u8, // 1-5 for entity selection
};

// ============================================================================
// INPUT GATHERING - Separate input reading from logic
// ============================================================================

fn gather_input() Input {
    var input = Input{
        .movement = null,
        .action = false,
        .cancel = false,
        .confirm = false,
        .start_combat = false,
        .number_key = null,
    };

    // Gather all input in one place
    var dx: i32 = 0;
    var dy: i32 = 0;
    if (c.IsKeyDown(c.KEY_LEFT)) dx -= 1;
    if (c.IsKeyDown(c.KEY_RIGHT)) dx += 1;
    if (c.IsKeyDown(c.KEY_UP)) dy -= 1;
    if (c.IsKeyDown(c.KEY_DOWN)) dy += 1;

    if (dx != 0 or dy != 0) {
        input.movement = Vector2Int{ .x = dx, .y = dy };
    }

    input.action = c.IsKeyPressed(c.KEY_A);
    input.cancel = c.IsKeyPressed(c.KEY_B) or c.IsKeyPressed(c.KEY_ESCAPE);
    input.confirm = c.IsKeyPressed(c.KEY_SPACE) or c.IsKeyPressed(c.KEY_ENTER);
    input.start_combat = c.IsKeyPressed(c.KEY_F);

    if (c.IsKeyPressed(c.KEY_ONE)) input.number_key = 1;
    if (c.IsKeyPressed(c.KEY_TWO)) input.number_key = 2;
    if (c.IsKeyPressed(c.KEY_THREE)) input.number_key = 3;
    if (c.IsKeyPressed(c.KEY_FOUR)) input.number_key = 4;
    if (c.IsKeyPressed(c.KEY_FIVE)) input.number_key = 5;

    return input;
}

// ============================================================================
// MAIN UPDATE - Direct, obvious control flow
// ============================================================================

pub fn update_player(ctx: *GameContext, dt: f32) !void {
    const input = gather_input();
    var state = &ctx.player_state;

    // Simple switch - no hidden abstractions
    switch (state.mode) {
        .walking => try update_walking(ctx, state, input, dt),
        .deploying => try update_deploying(ctx, state, input),
        .combat => try update_combat(ctx, state, input),
    }

    // Update animations/visuals
    update_player_animation(ctx, dt);
    update_puppet_animations(ctx, dt);
}

// ============================================================================
// WALKING MODE - All logic in one place, easy to read top-to-bottom
// ============================================================================

fn update_walking(ctx: *GameContext, state: *PlayerState, input: Input, dt: f32) !void {
    state.movement_cooldown += dt;

    // Early out if still in cooldown
    if (state.movement_cooldown < MOVEMENT_DURATION) {
        return;
    }

    // Force combat for testing
    if (input.start_combat) {
        transition_to_deploying(ctx, state);
        return;
    }

    // Handle movement
    if (input.movement) |delta| {
        const new_pos = add_vec2(ctx.player_pos, delta);

        if (!can_move_to(ctx, new_pos)) {
            return;
        }

        // Check for staircase
        if (is_staircase(ctx.world, new_pos)) {
            if (get_staircase_dest(ctx.world, new_pos)) |dest| {
                ctx.current_level = dest.level;
                ctx.player_pos = dest.pos;
                state.movement_cooldown = 0;
                calculate_fov(ctx);
                return;
            }
        }

        // Normal movement
        ctx.player_pos = new_pos;
        state.movement_cooldown = 0;
        calculate_fov(ctx);

        // Check if enemies nearby
        const enemy_count = count_nearby_enemies(ctx, ctx.player_pos, 3);
        if (enemy_count > 0) {
            transition_to_deploying(ctx, state);
        } else {
            // Enemy turn happens here
            enemy_turn(ctx);
        }
    }
}

// ============================================================================
// DEPLOYING MODE - Straightforward state progression
// ============================================================================

fn update_deploying(ctx: *GameContext, state: *PlayerState, input: Input) !void {
    // Cancel to go back to walking
    if (input.cancel) {
        if (can_end_combat(ctx)) {
            transition_to_walking(ctx, state);
        }
        return;
    }

    // Phase 1: Select which puppet to deploy
    if (state.selected_puppet_id == null) {
        if (!ctx.ui.deploy_menu_open) {
            ctx.ui.deploy_menu_open = true;
        }

        if (input.movement) |delta| {
            move_menu_cursor(&ctx.ui.deploy_menu, delta);
        }

        if (input.confirm) {
            const menu_selection = ctx.ui.deploy_menu.selected_index;
            if (menu_selection < ctx.puppets.len) {
                state.selected_puppet_id = ctx.puppets[menu_selection].id;
                ctx.ui.deploy_menu_open = false;

                // Setup deployment area
                ctx.cursor_pos = ctx.player_pos;
                highlight_deployable_area(ctx, ctx.player_pos);
                state.deploy_highlighted = true;
            }
        }
        return;
    }

    // Phase 2: Place the selected puppet
    const puppet_id = state.selected_puppet_id.?;

    if (input.movement) |delta| {
        move_cursor(&ctx.cursor_pos, delta);
    }

    if (input.confirm) {
        if (can_deploy_at(ctx, ctx.cursor_pos)) {
            deploy_puppet_at(ctx, puppet_id, ctx.cursor_pos);
            state.selected_puppet_id = null;
            clear_highlights(ctx);
            state.deploy_highlighted = false;

            // Check if all puppets deployed
            if (all_puppets_deployed(ctx)) {
                transition_to_combat(ctx, state);
            }
        }
    }
}

// ============================================================================
// COMBAT MODE - Clear, linear flow
// ============================================================================

fn update_combat(ctx: *GameContext, state: *PlayerState, input: Input) !void {
    // Force end combat for testing
    if (input.start_combat) {
        transition_to_walking(ctx, state);
        return;
    }

    switch (ctx.current_turn) {
        .player => update_player_combat_turn(ctx, state, input),
        .enemy => update_enemy_combat_turn(ctx, state),
    }
}

fn update_player_combat_turn(ctx: *GameContext, state: *PlayerState, input: Input) void {
    // Entity selection
    if (input.number_key) |key| {
        const index = key - 1;
        if (index == 0) {
            state.selected_entity_id = ctx.player_id;
        } else if (index - 1 < ctx.puppets.len) {
            state.selected_entity_id = ctx.puppets[index - 1].id;
        }

        if (state.selected_entity_id != null) {
            state.combat_mode = .selecting;
            clear_highlights(ctx);
            ctx.cursor_active = false;
        }
    }

    const entity = get_entity_by_id(ctx, state.selected_entity_id orelse return);
    if (entity == null) return;

    switch (state.combat_mode) {
        .selecting => {
            // Q for move, W for attack
            if (c.IsKeyPressed(c.KEY_Q) and !entity.?.has_moved) {
                state.combat_mode = .moving;
                ctx.cursor_pos = entity.?.pos;
                ctx.cursor_active = true;
                highlight_movement_range(ctx, entity.?);
            } else if (c.IsKeyPressed(c.KEY_W) and !entity.?.has_attacked) {
                state.combat_mode = .attacking;
                ctx.cursor_pos = entity.?.pos;
                ctx.cursor_active = true;
                highlight_attack_range(ctx, entity.?);
            }
        },

        .moving => {
            if (input.cancel) {
                state.combat_mode = .selecting;
                ctx.cursor_active = false;
                clear_highlights(ctx);
                return;
            }

            if (input.movement) |delta| {
                move_cursor(&ctx.cursor_pos, delta);
            }

            if (input.action) {
                if (can_move_to_highlighted(ctx, ctx.cursor_pos)) {
                    // Pathfind and move
                    const path = find_path(ctx, entity.?.pos, ctx.cursor_pos);
                    if (path) |p| {
                        entity.?.path = p;
                        entity.?.has_moved = true;
                        state.combat_mode = .selecting;
                        ctx.cursor_active = false;
                        clear_highlights(ctx);
                    }
                }
            }
        },

        .attacking => {
            if (input.cancel) {
                state.combat_mode = .selecting;
                ctx.cursor_active = false;
                clear_highlights(ctx);
                return;
            }

            if (input.movement) |delta| {
                move_cursor(&ctx.cursor_pos, delta);
            }

            if (input.action) {
                if (can_attack_highlighted(ctx, ctx.cursor_pos)) {
                    const target = get_entity_at(ctx, ctx.cursor_pos);
                    if (target) |t| {
                        perform_attack(ctx, entity.?, t);
                        entity.?.has_attacked = true;
                        state.combat_mode = .selecting;
                        ctx.cursor_active = false;
                        clear_highlights(ctx);
                    }
                }
            }
        },
    }

    // Check if turn is done
    if (entity.?.has_moved and entity.?.has_attacked) {
        entity.?.turn_taken = true;
    }

    if (all_entities_done(ctx)) {
        reset_entity_turns(ctx);
        ctx.current_turn = .enemy;
    }
}

fn update_enemy_combat_turn(ctx: *GameContext, state: *PlayerState) void {
    _ = state;

    // Simple enemy AI - move toward player and attack
    for (ctx.enemies) |*enemy| {
        if (enemy.turn_taken) continue;

        // Try to attack if in range
        const dist = distance(enemy.pos, ctx.player_pos);
        if (dist <= enemy.attack_range) {
            perform_attack(ctx, enemy, get_entity_by_id(ctx, ctx.player_id).?);
            enemy.turn_taken = true;
            continue;
        }

        // Otherwise move closer
        const path = find_path(ctx, enemy.pos, ctx.player_pos);
        if (path) |p| {
            if (p.len > 0) {
                const move_dist = @min(enemy.movement_range, p.len);
                enemy.pos = p[move_dist - 1];
            }
        }
        enemy.turn_taken = true;
    }

    // Back to player turn
    reset_entity_turns(ctx);
    ctx.current_turn = .player;
}

// ============================================================================
// STATE TRANSITIONS - Explicit and obvious
// ============================================================================

fn transition_to_walking(ctx: *GameContext, state: *PlayerState) void {
    // Clear combat state
    clear_highlights(ctx);
    ctx.cursor_active = false;
    ctx.ui.deploy_menu_open = false;

    // Remove puppets from field
    for (ctx.puppets) |*puppet| {
        puppet.deployed = false;
        puppet.visible = false;
    }

    state.mode = .walking;
    state.selected_puppet_id = null;
    state.selected_entity_id = null;
    state.deploy_highlighted = false;
}

fn transition_to_deploying(ctx: *GameContext, state: *PlayerState) void {
    state.mode = .deploying;
    state.selected_puppet_id = null;
    state.deploy_highlighted = false;
    ctx.ui.deploy_menu_open = true;
}

fn transition_to_combat(ctx: *GameContext, state: *PlayerState) void {
    clear_highlights(ctx);
    ctx.ui.deploy_menu_open = false;

    state.mode = .combat;
    state.combat_mode = .selecting;
    state.selected_entity_id = null;

    ctx.current_turn = .player;
    reset_entity_turns(ctx);
}

// ============================================================================
// HELPER FUNCTIONS - Simple, direct operations on data
// ============================================================================

fn can_move_to(ctx: *GameContext, pos: Vector2Int) bool {
    if (pos.x < 0 or pos.y < 0 or pos.x >= LEVEL_WIDTH or pos.y >= LEVEL_HEIGHT) {
        return false;
    }

    const idx = pos.y * LEVEL_WIDTH + pos.x;
    if (ctx.grid[idx].solid) return false;

    // Check for entities
    for (ctx.entities) |entity| {
        if (entity.pos.x == pos.x and entity.pos.y == pos.y) {
            return false;
        }
    }

    return true;
}

fn count_nearby_enemies(ctx: *GameContext, pos: Vector2Int, radius: i32) u32 {
    var count: u32 = 0;
    for (ctx.enemies) |enemy| {
        if (distance(pos, enemy.pos) < radius) {
            count += 1;
        }
    }
    return count;
}

fn all_puppets_deployed(ctx: *GameContext) bool {
    for (ctx.puppets) |puppet| {
        if (!puppet.deployed) return false;
    }
    return true;
}

fn all_entities_done(ctx: *GameContext) bool {
    // Check player
    const player = get_entity_by_id(ctx, ctx.player_id) orelse return false;
    if (!player.turn_taken) return false;

    // Check puppets
    for (ctx.puppets) |puppet| {
        if (!puppet.turn_taken) return false;
    }

    return true;
}

fn reset_entity_turns(ctx: *GameContext) void {
    if (get_entity_by_id(ctx, ctx.player_id)) |player| {
        player.turn_taken = false;
        player.has_moved = false;
        player.has_attacked = false;
    }

    for (ctx.puppets) |*puppet| {
        puppet.turn_taken = false;
        puppet.has_moved = false;
        puppet.has_attacked = false;
    }

    for (ctx.enemies) |*enemy| {
        enemy.turn_taken = false;
        enemy.has_moved = false;
        enemy.has_attacked = false;
    }
}

// ============================================================================
// KEY DIFFERENCES FROM OOP APPROACH:
//
// 1. All data is visible and mutable - no hiding behind interfaces
// 2. Functions transform data, they don't "own" behavior
// 3. Control flow is explicit - read top to bottom
// 4. No virtual dispatch, no inheritance, no polymorphism
// 5. State transitions are just functions that modify data
// 6. Everything is in one file - easy to see the whole system
// 7. Less abstraction = easier to debug and modify
// ============================================================================
//
