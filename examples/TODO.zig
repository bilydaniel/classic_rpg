//FIRST
pub fn playerChangeState(ctx: *Game.Context, newState: typeof(ctx.player.data.player.state)) !void {
    const oldState = ctx.player.data.player.state;
    if (oldState == newState) return;

    // explicit exit logic
    switch (oldState) {
        .walking => exitWalking(ctx),
        .deploying_puppets => exitDeploying(ctx),
        .in_combat => exitCombat(ctx),
    }

    ctx.player.data.player.state = newState;

    // explicit enter logic
    switch (newState) {
        .walking => enterWalking(ctx),
        .deploying_puppets => enterDeploying(ctx),
        .in_combat => enterCombat(ctx),
    }
}

//SECOND
// gameplay => ui communication
ctx.gamestate.showDeployMenu = true;

// ui => gameplay communication
pub const UIIntent = struct {
    confirm: bool,
    cancel: bool,
    move_dir: ?Types.Vector2Int, // input direction
    menu_select: ?usize,
    quick_select_entity_idx: ?u8, // for pressing keys 1..n
    //TODO: reset each frame after consumed, at the end of the update function
};

//THIRD 
//maybe put some of the data from gamestate into a state machine struct
//

//FOURTH
//input.poll() -> fills InputState.
// ui.update(input, &ui_state, &ui_intent) — UI reads GameState & writes UIIntent.
// game.process_intents(&UIIntent, &GameState) — small dispatcher to transform intents into game actions (e.g. set gamestate.cursor).
// player_state_step(&ctx) — single call; decides moves / transitions based on GameState + Intent.
// enemy_ai_step(&ctx) — enemy decision making.
// movement_step(&ctx) — apply movement paths, update positions, collisions.
// combat_resolution_step(&ctx) — resolve attacks queued this frame.
// visibility_step(&ctx) — recompute FOV, visibility flags.
// camera_step(&ctx) — set camera target from GameState.
// prepare_render_state(&ctx) — build arrays/sprites to draw.
// render(&render_state).
// each function just mutates the ctx, no callbacks or calling each other, etc.






//FIFTH
const std = @import("std");
const Types = @import("../common/types.zig");
const Config = @import("../common/config.zig");

pub const UIIntent = struct {
    confirm: bool = false,
    cancel: bool = false,
    move_dir: ?Types.Vector2Int = null,
    quick_select: ?u8 = null,
};

pub const PlayerMode = enum { Walking, Deploying, Combat };

pub const PlayerState = struct {
    mode: PlayerMode = .Walking,
    selected_puppet_id: ?u32 = null,
    movement_cooldown: f32 = 0.0,
    turn_taken: bool = false,
};

pub const GameState = struct {
    player: PlayerState,
    cursor: ?Types.Vector2Int = null,
    deployable_cells: ?[8]?Types.Vector2Int = null,
    current_turn: enum { Player, Enemy } = .Player,
    // Add more pure game model here: entities, grid, etc.
};

pub const Context = struct {
    gs: GameState,
    intent: UIIntent,
    delta: f32,
    // references to other systems
    // entities: *Entities,
    // grid: *Grid,
    // pathfinder: *Pathfinder,
};

pub fn frameStep(ctx: *Context) !void {
    // 1) UI already ran and filled ctx.intent
    // 2) process intents into GameState
    processIntents(ctx);

    // 3) Player state machine (single call)
    try playerStateStep(ctx);

    // 4) Enemy AI
    // try enemyStep(ctx);

    // 5) movement / path execution
    // movementStep(ctx);

    // 6) combat resolution
    // combatStep(ctx);

    // 7) visibility
    // visibilityStep(ctx);

    // reset per-frame intents
    ctx.intent = UIIntent{};
}

fn processIntents(ctx: *Context) void {
    if (ctx.intent.move_dir) |d| {
        if (ctx.gs.cursor) |cur| {
            ctx.gs.cursor = Types.vector2IntAdd(cur, d);
        } else {
            // create cursor near player or something
        }
    }
    if (ctx.intent.confirm) {
        // mark a flag on GameState that will be consumed by playerStateStep
        // For example: ctx.gs.confirm_pressed = true;
    }
}

pub fn processIntents(ctx: *Game.Context) void {
    // move cursor by delta (UI supplies deltas)
    if (ctx.intent.move_cursor) |d| {
        if (ctx.gamestate.cursor) |cur| {
            const new = Types.vector2IntAdd(cur, d);
            // clamp to bounds
            if (new.x >= 0 and new.y >= 0 and new.x < Config.level_width and new.y < Config.level_height) {
                ctx.gamestate.cursor = new;
            }
        } else {
            // if no cursor, create one near player
            ctx.gamestate.makeCursor(ctx.player.pos);
            if (ctx.gamestate.cursor) |cur| {
                const new = Types.vector2IntAdd(cur, d);
                if (new.x >= 0 and new.y >= 0 and new.x < Config.level_width and new.y < Config.level_height) {
                    ctx.gamestate.cursor = new;
                }
            }
        }
    }

    // quick select maps to selecting a puppet by index (UI convention)
    if (ctx.intent.quick_select) |idx| {
        const i = @intCast(usize, idx);
        if (i < ctx.player.data.player.puppets.items.len) {
            ctx.gamestate.selectedPupId = ctx.player.data.player.puppets.items[i].id;
        }
    }

    // confirm/cancel are consumed by state update functions
}



//SIXTH
//make systems in style of this:
pathfinder.findPath(grid, start, end, entities) -> PathResult (pure: no UI, no global state)
//movement is interesting
movement.applyMovement(entity, path, grid) — moves entity one step or completes path
deployment.canDeploy(gs, grid, entities) -> bool — pure predicate
deployment.placePuppet(ctx, puppet_id, pos) — mutates entities and mark puppet deployed
combat.queueAttack(attacker, target, attackData) — adds an intent to combat queue (doesn't resolve immediately)
combat.resolveQueue(ctx) — resolves all queued attacks in deterministic order

//SEVEN
if (!canDeploy(ctx, puppet_id, pos)) {
    // show error in UI? sound? doesn't matter.
    return;
}


//EIGHT
if (gs.player.selected_puppet == null) {
        // Wait for player to choose one via intent.select_puppet_index
        return;
    }

//NINE
//have a look at updates, where am i updating player, where puppets and where enemies, etc.

//TEN
//probably should just go through the whole codebase now that I know what iam making, clean up
