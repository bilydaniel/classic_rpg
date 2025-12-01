const Config = @import("../common/config.zig");
const Utils = @import("../common/utils.zig");
const World = @import("world.zig");
const CameraManager = @import("cameraManager.zig");
const Entity = @import("entity.zig");
const Gamestate = @import("gamestate.zig");
const Level = @import("level.zig");
const Types = @import("../common/types.zig");
const std = @import("std");
const Pathfinder = @import("../game/pathfinder.zig");
const InputManager = @import("../game/inputManager.zig");
const Game = @import("game.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

// ============================================================================
// STATE MACHINE
// ============================================================================

const PlayerState = enum {
    walking,
    deploying_puppets,
    in_combat,
};

const PlayerStateMachine = struct {
    current_state: PlayerState,

    pub fn transition(self: *PlayerStateMachine, new_state: PlayerState, ctx: *Game.Context) !void {
        // Exit current state
        try self.exitState(ctx);

        // Update state
        self.current_state = new_state;

        // Enter new state
        try self.enterState(ctx);
    }

    fn exitState(self: *PlayerStateMachine, ctx: *Game.Context) !void {
        switch (self.current_state) {
            .walking => {},
            .deploying_puppets => {
                ctx.uiManager.hideDeployMenu();
                ctx.gamestate.reset();
            },
            .in_combat => {
                ctx.player.resetTurnTakens();
            },
        }
    }

    fn enterState(self: *PlayerStateMachine, ctx: *Game.Context) !void {
        switch (self.current_state) {
            .walking => {
                removeEntitiesType(ctx.entities, .puppet);
            },
            .deploying_puppets => {
                ctx.uiManager.showDeployMenu();
            },
            .in_combat => {
                ctx.gamestate.currentTurn = .player;
            },
        }
    }
};

// ============================================================================
// PLAYER ACTIONS
// ============================================================================

const PlayerAction = union(enum) {
    move: Types.Vector2Int,
    start_combat: void,
    end_combat: void,
    select_puppet: u32,
    deploy_puppet: u32,
    select_entity: usize,
    toggle_move_mode: void,
    toggle_attack_mode: void,
    skip_action: void,
    confirm_action: void,
    move_cursor: Types.Vector2Int,
};

// ============================================================================
// INPUT HANDLERS
// ============================================================================

const WalkingInput = struct {
    pub fn handle(ctx: *Game.Context) !?PlayerAction {
        if (c.IsKeyPressed(c.KEY_F)) {
            return .start_combat;
        }

        const deltaVector = ctx.inputManager.takePositionInput();
        if (deltaVector) |delta| {
            return PlayerAction{ .move = delta };
        }

        return null;
    }
};

const DeployingInput = struct {
    pub fn handle(ctx: *Game.Context) !?PlayerAction {
        if (c.IsKeyPressed(c.KEY_F)) {
            return .end_combat;
        }

        if (ctx.gamestate.selectedPupId == null) {
            return handleMenuSelection(ctx);
        } else {
            return handleDeployment(ctx);
        }
    }

    fn handleMenuSelection(ctx: *Game.Context) !?PlayerAction {
        const input = ctx.inputManager.takePositionInput();
        if (input) |in| {
            ctx.uiManager.updateActiveMenu(in);
        }

        if (ctx.inputManager.takeConfirmInput()) {
            const selectedItem = ctx.uiManager.getSelectedItem();
            if (selectedItem) |item| {
                return PlayerAction{ .select_puppet = item.puppet_id };
            }
        }

        return null;
    }

    fn handleDeployment(ctx: *Game.Context) !?PlayerAction {
        ctx.gamestate.makeCursor(ctx.player.pos);
        ctx.gamestate.updateCursor();

        if (ctx.inputManager.takeConfirmInput()) {
            if (canDeploy(ctx.player, ctx.gamestate, ctx.grid.*, ctx.entities)) {
                return PlayerAction{ .deploy_puppet = ctx.gamestate.selectedPupId.? };
            }
        }

        return null;
    }
};

const CombatInput = struct {
    pub fn handle(ctx: *Game.Context) !?PlayerAction {
        // Entity selection
        if (c.IsKeyPressed(c.KEY_ONE)) return PlayerAction{ .select_entity = 0 };
        if (c.IsKeyPressed(c.KEY_TWO)) return PlayerAction{ .select_entity = 1 };
        if (c.IsKeyPressed(c.KEY_THREE)) return PlayerAction{ .select_entity = 2 };
        if (c.IsKeyPressed(c.KEY_FOUR)) return PlayerAction{ .select_entity = 3 };
        if (c.IsKeyPressed(c.KEY_FIVE)) return PlayerAction{ .select_entity = 4 };

        // Mode selection
        if (c.IsKeyPressed(c.KEY_Q)) return .toggle_move_mode;
        if (c.IsKeyPressed(c.KEY_W)) return .toggle_attack_mode;
        if (c.IsKeyPressed(c.KEY_SPACE)) return .skip_action;
        if (c.IsKeyPressed(c.KEY_A)) return .confirm_action;

        // Cursor movement
        const delta = ctx.inputManager.takePositionInput();
        if (delta) |d| {
            return PlayerAction{ .move_cursor = d };
        }

        return null;
    }
};

// ============================================================================
// STATE HANDLERS
// ============================================================================

const WalkingState = struct {
    pub fn update(ctx: *Game.Context) !void {
        ctx.player.movementCooldown += ctx.delta;
        if (ctx.player.movementCooldown < Config.movement_animation_duration) {
            return;
        }

        const action = try WalkingInput.handle(ctx);
        if (action) |act| {
            try processAction(ctx, act);
        }
    }

    fn processAction(ctx: *Game.Context, action: PlayerAction) !void {
        switch (action) {
            .move => |delta| try handleMovement(ctx, delta),
            .start_combat => try ctx.player.startCombatSetup(ctx.entities, ctx.grid.*),
            else => {},
        }
    }

    fn handleMovement(ctx: *Game.Context, delta: Types.Vector2Int) !void {
        const new_pos = Types.vector2IntAdd(ctx.player.pos, delta);

        if (!canMove(ctx.world.currentLevel.grid, new_pos, ctx.entities.*)) {
            return;
        }

        // Handle staircase
        if (isStaircase(ctx.world, new_pos)) {
            if (getStaircaseDestination(ctx.world, new_pos)) |dest| {
                switchLevel(ctx.world, dest.level);
                ctx.player.move(dest.pos, ctx.grid);
                ctx.player.movementCooldown = 0;
                return;
            }
        }

        ctx.player.move(new_pos, ctx.grid);
        ctx.player.movementCooldown = 0;

        // Check combat
        const should_start_combat = checkCombatStart(ctx.player, ctx.entities);
        if (should_start_combat and ctx.player.data.player.state != .in_combat) {
            try ctx.player.startCombatSetup(ctx.entities, ctx.grid.*);
        } else if (!should_start_combat) {
            ctx.gamestate.currentTurn = .enemy;
        }
    }
};

const DeployingState = struct {
    pub fn update(ctx: *Game.Context) !void {
        const action = try DeployingInput.handle(ctx);
        if (action) |act| {
            try processAction(ctx, act);
        }

        try updateDeploymentUI(ctx);

        // Check if all puppets deployed
        if (ctx.player.data.player.allPupsDeployed()) {
            ctx.player.data.player.state = .in_combat;
            ctx.gamestate.reset();
            ctx.uiManager.hideDeployMenu();
        }
    }

    fn processAction(ctx: *Game.Context, action: PlayerAction) !void {
        switch (action) {
            .select_puppet => |id| {
                ctx.gamestate.selectedPupId = id;
                ctx.uiManager.hideDeployMenu();
            },
            .deploy_puppet => |id| {
                try deployPuppet(ctx, id);
            },
            .end_combat => {
                if (canEndCombat(ctx.player, ctx.entities)) {
                    ctx.gamestate.reset();
                    ctx.player.endCombat();
                    ctx.uiManager.hideDeployMenu();
                }
            },
            else => {},
        }
    }

    fn updateDeploymentUI(ctx: *Game.Context) !void {
        if (ctx.gamestate.selectedPupId != null) {
            if (ctx.gamestate.deployableCells == null) {
                ctx.gamestate.deployableCells = neighboursAll(ctx.player.pos);
            }

            if (ctx.gamestate.deployableCells) |cells| {
                if (!ctx.gamestate.deployHighlighted) {
                    for (cells) |cell| {
                        if (cell) |c| {
                            try highlightTile(ctx.gamestate, c);
                        }
                    }
                    ctx.gamestate.deployHighlighted = true;
                }
            }
        }
    }
};

const CombatState = struct {
    pub fn update(ctx: *Game.Context) !void {
        // Force end combat for testing
        if (c.IsKeyPressed(c.KEY_F)) {
            ctx.player.endCombat();
            ctx.gamestate.reset();
            return;
        }

        switch (ctx.gamestate.currentTurn) {
            .player => try handlePlayerTurn(ctx),
            .enemy => try handleEnemyTurn(ctx),
        }
    }

    fn handlePlayerTurn(ctx: *Game.Context) !void {
        const action = try CombatInput.handle(ctx);
        if (action) |act| {
            try processAction(ctx, act);
        }

        // Update visual highlights
        if (ctx.gamestate.selectedEntity) |entity| {
            highlightEntity(ctx.gamestate, entity.pos);
        }

        // Check turn completion
        if (shouldEndPlayerTurn(ctx)) {
            ctx.gamestate.currentTurn = .enemy;
            ctx.player.resetTurnTakens();
        }
    }

    fn processAction(ctx: *Game.Context, action: PlayerAction) !void {
        switch (action) {
            .select_entity => |idx| try selectEntity(ctx, idx),
            .toggle_move_mode => toggleMoveMode(ctx),
            .toggle_attack_mode => toggleAttackMode(ctx),
            .skip_action => skipCurrentAction(ctx),
            .confirm_action => try confirmCurrentAction(ctx),
            .move_cursor => ctx.gamestate.updateCursor(),
            else => {},
        }
    }

    fn selectEntity(ctx: *Game.Context, index: usize) !void {
        if (index == 0) {
            ctx.gamestate.selectedEntity = ctx.player;
        } else if (index - 1 < ctx.player.data.player.puppets.items.len) {
            ctx.gamestate.selectedEntity = ctx.player.data.player.puppets.items[index - 1];
        } else {
            return;
        }

        if (ctx.gamestate.selectedEntity) |selected_entity| {
            ctx.cameraManager.targetEntity = selected_entity;
            ctx.gamestate.removeCursor();
            ctx.gamestate.selectedEntityMode = .none;
            ctx.gamestate.resetMovementHighlight();
        }
    }

    fn toggleMoveMode(ctx: *Game.Context) void {
        if (ctx.gamestate.selectedEntity) |entity| {
            if (!entity.hasMoved) {
                if (ctx.gamestate.selectedEntityMode == .moving) {
                    ctx.gamestate.selectedEntityMode = .none;
                    ctx.gamestate.removeCursor();
                    ctx.gamestate.resetMovementHighlight();
                } else {
                    ctx.gamestate.selectedEntityMode = .moving;
                    ctx.gamestate.makeCursor(entity.pos);
                }
            }
        }
    }

    fn toggleAttackMode(ctx: *Game.Context) void {
        if (ctx.gamestate.selectedEntity) |entity| {
            if (ctx.gamestate.selectedEntityMode == .attacking) {
                ctx.gamestate.selectedEntityMode = .none;
                ctx.gamestate.removeCursor();
                ctx.gamestate.resetAttackHighlight();
            } else {
                ctx.gamestate.selectedEntityMode = .attacking;
                ctx.gamestate.makeCursor(entity.pos);
            }
        }
    }

    fn skipCurrentAction(ctx: *Game.Context) void {
        if (ctx.gamestate.selectedEntity) |entity| {
            switch (ctx.gamestate.selectedEntityMode) {
                .moving => {
                    entity.hasMoved = true;
                    ctx.gamestate.resetMovementHighlight();
                },
                .attacking => {
                    entity.hasAttacked = true;
                    ctx.gamestate.resetAttackHighlight();
                },
                .none => {},
            }
            ctx.gamestate.selectedEntityMode = .none;
            ctx.gamestate.removeCursor();
        }
    }

    fn confirmCurrentAction(ctx: *Game.Context) !void {
        if (ctx.gamestate.selectedEntity) |entity| {
            switch (ctx.gamestate.selectedEntityMode) {
                .moving => try executeMove(ctx, entity),
                .attacking => try executeAttack(ctx, entity),
                .none => {},
            }
        }
    }

    fn executeMove(ctx: *Game.Context, entity: *Entity.Entity) !void {
        try ctx.gamestate.highlightMovement(entity);

        if (ctx.gamestate.cursor) |cur| {
            if (ctx.gamestate.isinMovable(cur)) {
                entity.path = try ctx.pathfinder.findPath(ctx.grid.*, entity.pos, cur, ctx.entities.*);
                entity.hasMoved = true;
                ctx.gamestate.selectedEntityMode = .none;
                ctx.gamestate.resetMovementHighlight();
                ctx.gamestate.removeCursor();
            }
        }
    }

    fn executeAttack(ctx: *Game.Context, entity: *Entity.Entity) !void {
        try ctx.gamestate.highlightAttack(entity);

        if (ctx.gamestate.cursor) |cur| {
            if (ctx.gamestate.isinAttackable(cur)) {
                const attackedEntity = getEntityByPos(ctx.entities.*, cur);

                try ctx.shaderManager.spawnSlash(entity.pos, cur);
                try ctx.shaderManager.spawnImpact(cur);

                attack(ctx, entity, attackedEntity);
                ctx.gamestate.resetAttackHighlight();
                ctx.gamestate.removeCursor();
                entity.hasAttacked = true;
                ctx.gamestate.selectedEntityMode = .none;
            }
        }
    }

    fn shouldEndPlayerTurn(ctx: *Game.Context) bool {
        if (ctx.player.data.player.inCombatWith.items.len == 0) {
            return false;
        }
        return ctx.player.turnTaken or ctx.player.allPupsTurnTaken();
    }

    fn handleEnemyTurn(ctx: *Game.Context) !void {
        // TODO: Implement enemy AI
        _ = ctx;
    }
};

// ============================================================================
// MAIN UPDATE FUNCTION
// ============================================================================

pub fn updatePlayer(ctx: *Game.Context) !void {
    // Debug menu toggle
    if (c.IsKeyPressed(c.KEY_B)) {
        if (ctx.uiManager.deployMenu.visible) {
            ctx.uiManager.hideDeployMenu();
        } else {
            ctx.uiManager.showDeployMenu();
        }
    }

    // Update based on state
    switch (ctx.player.data.player.state) {
        .walking => try WalkingState.update(ctx),
        .deploying_puppets => try DeployingState.update(ctx),
        .in_combat => try CombatState.update(ctx),
    }

    // Update entities
    try ctx.player.update(ctx);
    for (ctx.player.data.player.puppets.items) |pup| {
        try pup.update(ctx);
    }
}

// ============================================================================
// UTILITY FUNCTIONS (Keep all your existing utility functions below)
// ============================================================================

pub fn deployPuppet(ctx: *Game.Context, pupId: u32) !void {
    const puppet = getPupById(ctx.player.data.player.puppets, pupId);
    if (puppet) |pup| {
        if (!pup.data.puppet.deployed) {
            if (ctx.gamestate.cursor) |curs| {
                pup.pos = curs;
                pup.data.puppet.deployed = true;
                pup.visible = true;
                ctx.gamestate.selectedPupId = null;
                return;
            }
        }
    }
}

pub fn canDeploy(player: *Entity.Entity, gamestate: *Gamestate.gameState, grid: []Level.Tile, entities: *std.ArrayList(*Entity.Entity)) bool {
    const deploy_pos = gamestate.cursor;
    if (deploy_pos) |dep_pos| {
        if (Types.vector2IntCompare(player.pos, dep_pos)) {
            return false;
        }

        const entity = getEntityByPos(entities.*, dep_pos);
        if (entity) |_| {
            return false;
        }
        const index = posToIndex(dep_pos);
        if (index) |idx| {
            const deploy_tile = grid[idx];
            if (deploy_tile.solid) {
                return false;
            }
            if (!deploy_tile.walkable) {
                return false;
            }
            if (gamestate.deployableCells) |deployable_cells| {
                if (!isDeployable(dep_pos, &deployable_cells)) {
                    return false;
                }
            }
            return true;
        }
    }
    return false;
}

pub fn isDeployable(pos: Types.Vector2Int, cells: []const ?Types.Vector2Int) bool {
    for (cells) |cell| {
        if (cell) |cell_| {
            if (Types.vector2IntCompare(pos, cell_)) {
                return true;
            }
        }
    }
    return false;
}

pub fn getEntityByPos(entities: std.ArrayList(*Entity.Entity), pos: Types.Vector2Int) ?*Entity.Entity {
    for (entities.items) |entity| {
        if (Types.vector2IntCompare(entity.pos, pos)) {
            return entity;
        }
    }
    return null;
}

pub fn getEntityById(entities: std.ArrayList(*Entity.Entity), id: u32) ?*Entity.Entity {
    for (entities.items) |entity| {
        if (entity.id == id) {
            return entity;
        }
    }
    return null;
}

pub fn calculateFOV(grid: *[]Level.Tile, center: Types.Vector2Int, radius: usize) void {
    var idx: usize = 0;
    while (idx < grid.len) : (idx += 1) {
        grid.*[idx].visible = false;
    }

    const rays = radius * 8;
    var i: i32 = 0;
    while (i < rays) : (i += 1) {
        const angle = @as(f32, @floatFromInt(i)) * (2.0 * std.math.pi) / @as(f32, @floatFromInt(rays));

        const target = Types.Vector2Int{
            .x = center.x + @as(i32, @intFromFloat(@cos(angle) * @as(f32, @floatFromInt(radius)))),
            .y = center.y + @as(i32, @intFromFloat(@sin(angle) * @as(f32, @floatFromInt(radius)))),
        };
        castRay(grid, center, target);
    }
}

pub fn castRay(grid: *[]Level.Tile, center: Types.Vector2Int, target: Types.Vector2Int) void {
    const dx = @as(i32, @intCast(@abs(target.x - center.x)));
    const dy = @as(i32, @intCast(@abs(target.y - center.y)));
    var current_pos = center;

    const x_inc: i32 = if (target.x > center.x) 1 else -1;
    const y_inc: i32 = if (target.y > center.y) 1 else -1;
    var err = dx - dy;

    while (true) {
        const tileIndex = posToIndex(current_pos);
        if (tileIndex) |tile_index| {
            grid.*[tile_index].visible = true;
            grid.*[tile_index].seen = true;

            if (grid.*[tile_index].solid == true) {
                break;
            }

            if (Types.vector2IntCompare(current_pos, target)) {
                break;
            }

            const e2 = 2 * err;
            if (e2 > -dy) {
                err -= dy;
                current_pos.x += x_inc;
            }
            if (e2 < dx) {
                err += dx;
                current_pos.y += y_inc;
            }
        }
    }
}

pub fn switchLevel(world: *World.World, levelID: u32) void {
    for (world.levels.items) |level| {
        if (level.id == levelID) {
            world.currentLevel = level;
        }
    }
}

pub fn highlightTile(gamestate: *Gamestate.gameState, pos: Types.Vector2Int) !void {
    try gamestate.highlightedTiles.append(Gamestate.highlight{
        .pos = pos,
        .type = .pup_deploy,
    });
}

pub fn drawGameState(gamestate: *Gamestate.gameState, currentLevel: *Level.Level) void {
    _ = currentLevel;
    if (gamestate.highlightedTiles.items.len > 0) {
        for (gamestate.highlightedTiles.items) |highlight| {
            var highlightColor = c.RED;

            if (highlight.type == .movable) {
                highlightColor = c.BLUE;
            }

            c.DrawRectangleLines(highlight.pos.x * Config.tile_width, highlight.pos.y * Config.tile_height, Config.tile_width, Config.tile_height, highlightColor);
        }
    }

    if (gamestate.highlightedEntity) |highlight| {
        if (highlight.type == .circle) {
            var highColor = c.RED;
            if (highlight.type == .entity) {
                highColor = c.YELLOW;
            }
            c.DrawCircleLines(highlight.pos.x * Config.tile_width + Config.tile_width / 2, highlight.pos.y * Config.tile_height + Config.tile_height / 2, Config.tile_width / 2, highColor);
        }
    }

    if (gamestate.cursor) |cur| {
        c.DrawRectangleLines(cur.x * Config.tile_width, cur.y * Config.tile_height, Config.tile_width, Config.tile_height, c.YELLOW);
    }
}

pub fn highlightEntity(gamestate: *Gamestate.gameState, pos: Types.Vector2Int) void {
    gamestate.highlightedEntity = Gamestate.highlight{
        .pos = pos,
        .type = .circle,
    };
}

pub fn isStaircase(world: *World.World, pos: Types.Vector2Int) bool {
    for (world.levelLinks.items) |levelLink| {
        if (levelLink.from.level == world.currentLevel.id and Types.vector2IntCompare(levelLink.from.pos, pos)) {
            return true;
        }
    }
    return false;
}

pub fn getStaircaseDestination(world: *World.World, pos: Types.Vector2Int) ?Level.Location {
    for (world.levelLinks.items) |levelLink| {
        if (levelLink.from.level == world.currentLevel.id and Types.vector2IntCompare(levelLink.from.pos, pos)) {
            return levelLink.to;
        }
    }
    return null;
}

pub fn canMove(grid: []Level.Tile, pos: Types.Vector2Int, entities: std.ArrayList(*Entity.Entity)) bool {
    const pos_index = posToIndex(pos);
    if (pos_index) |index| {
        if (index < grid.len) {
            if (grid[index].solid) {
                return false;
            }
        }
    }
    const entity = getEntityByPos(entities, pos);
    if (entity == null) {
        return true;
    }

    return false;
}

pub fn posToIndex(pos: Types.Vector2Int) ?usize {
    if (pos.x < 0 or pos.y < 0) {
        return null;
    }
    const result: usize = @intCast(pos.y * Config.level_width + pos.x);
    if (result >= Config.level_width * Config.level_height) {
        return null;
    }
    return result;
}

pub fn indexToPos(index: i32) Types.Vector2Int {
    const x = (index % Config.level_width);
    const y = (@divFloor(index, Config.level_width));
    return Types.Vector2Int.init(x, y);
}

pub fn indexToPixel(index: i32) c.Vector2 {
    const x = (index % Config.level_width) * Config.tile_width;
    const y = (@divFloor(index, Config.level_width)) * Config.tile_height;
    return c.Vector2{ .x = x, .y = y };
}

pub fn getTileIdx(grid: []Level.Tile, index: usize) ?Level.Tile {
    if (index < 0) {
        return null;
    }

    if (index >= grid.len) {
        return null;
    }
    return grid[index];
}

pub fn getTilePos(grid: []Level.Tile, pos: Types.Vector2Int) ?Level.Tile {
    const idx = posToIndex(pos);
    if (idx) |index| {
        return getTileIdx(grid, index);
    }
    return null;
}

pub fn neighboursAll(pos: Types.Vector2Int) [8]?Types.Vector2Int {
    var result: [8]?Types.Vector2Int = undefined;

    var count: usize = 0;
    const sides = [_]i32{ -1, 0, 1 };
    for (sides) |y_side| {
        for (sides) |x_side| {
            if (x_side == 0 and y_side == 0) {
                continue;
            }
            const dif_pos = Types.Vector2Int.init(x_side, y_side);
            const result_pos = Types.vector2IntAdd(pos, dif_pos);
            if (result_pos.x >= 0 and result_pos.y >= 0 and result_pos.x < Config.level_width and result_pos.y < Config.level_height) {
                result[count] = result_pos;
            }
            count += 1;
        }
    }
    return result;
}

pub fn neighboursDistance(pos: Types.Vector2Int, distance: u32, result: *std.ArrayList(Types.Vector2Int)) !void {
    const n = 2 * distance + 1;
    const start = Types.vector2IntSub(pos, Types.Vector2Int{ .x = @intCast(distance), .y = @intCast(distance) });
    var x: i32 = 0;
    var y: i32 = 0;

    while (y < n) : (y += 1) {
        while (x < n) : (x += 1) {
            if (x == distance and y == distance) {
                continue;
            }
            const newPos = Types.vector2IntAdd(start, Types.Vector2Int{ .x = x, .y = y });
            try result.append(newPos);
        }
        x = 0;
    }
}

pub fn checkCombatStart(player: *Entity.Entity, entities: *std.ArrayList(*Entity.Entity)) bool {
    for (entities.items) |entity| {
        if (entity.data == .enemy) {
            const distance = Types.vector2Distance(player.pos, entity.pos);
            if (distance < 3) {
                return true;
            }
        }
    }
    return false;
}

pub fn canEndCombat(player: *Entity.Entity, entities: *std.ArrayList(*Entity.Entity)) bool {
    _ = player;
    _ = entities;
    return true;
}

pub fn removeEntitiesType(entities: *std.ArrayList(*Entity.Entity), entityType: Entity.EntityType) void {
    var i = entities.items.len;
    while (i > 0) {
        i -= 1;
        if (entities.items[i].data == entityType) {
            if (entityType == .puppet) {
                entities.items[i].data.puppet.deployed = false;
            }
            _ = entities.swapRemove(i);
        }
    }
}

pub fn attack(ctx: *Game.Context, entity: *Entity.Entity, attackedEntity: ?*Entity.Entity) void {
    if (attackedEntity) |attacked_entity| {
        _ = ctx;
        _ = attacked_entity;
        _ = entity;
    }
}

pub fn getPupById(entities: std.ArrayList(*Entity.Entity), id: u32) ?*Entity.Entity {
    for (entities.items) |entity| {
        if (entity.id == id) {
            return entity;
        }
    }
    return null;
}
