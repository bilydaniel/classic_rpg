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

//TODO: add an optiom to "look around", get info on enemies, etc.
pub fn updatePlayer(ctx: *Game.Context) !void {
    switch (ctx.player.data.player.state) {
        //TODO: go through everything, make more functions, messy
        //TODO: fix state management, state transitions(use funcitons?)
        .walking => {
            if (try preWalkingTransitions(ctx)) {
                return;
            }
            try handlePlayerWalking(ctx);
        },
        .deploying_puppets => {
            if (try preDeployingTransitions(ctx)) {
                return;
            }
            try handlePlayerDeploying(ctx);
        },
        .in_combat => {
            if (try preCombatTransitions(ctx)) {
                return;
            }
            try handlePlayerCombat(ctx);
        },
    }

    try ctx.player.update(ctx);
    for (ctx.player.data.player.puppets.items) |pup| {
        try pup.update(ctx);
    }
}

pub fn preWalkingTransitions(ctx: *Game.Context) !bool {
    if (ctx.uiCommand.combatToggle) {
        ctx.uiCommand.combatToggle = false;
        //TODO: check in enemies are around, if it makes sense to even go to combat
        try playerChangeState(ctx, .deploying_puppets);
        return true;
    }

    if (checkCombatStart(ctx.player, ctx.entities)) {
        try playerChangeState(ctx, .deploying_puppets);
        return true;
    }

    return false;
}

pub fn preDeployingTransitions(ctx: *Game.Context) !bool {
    if (ctx.uiCommand.combatToggle) {
        ctx.uiCommand.combatToggle = false;
        try playerChangeState(ctx, .walking);
        return true;
    }

    if (ctx.player.data.player.allPupsDeployed()) {
        try playerChangeState(ctx, .in_combat);
        return true;
    }

    return false;
}

pub fn preCombatTransitions(ctx: *Game.Context) !bool {
    if (ctx.uiCommand.combatToggle) {
        ctx.uiCommand.combatToggle = false;
        try playerChangeState(ctx, .walking);
        return true;
    }

    if (ctx.player.data.player.inCombatWith.items.len == 0) {
        try playerChangeState(ctx, .walking);
        return true;
    }
    return false;
}

pub fn deployPuppet(ctx: *Game.Context, pupId: u32) !void {
    const puppet = getPupById(ctx.player.data.player.puppets, pupId);
    if (puppet) |pup| {
        if (!pup.data.puppet.deployed) {
            if (ctx.gamestate.cursor) |curs| {
                pup.pos = curs;
                pup.data.puppet.deployed = true;
                pup.visible = true;
                ctx.gamestate.selectedPupId = null; //TODO: maybe wrong, check
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

            // Check if we've reached the end point
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

pub fn old_highlightTile(grid: []Level.Tile, pos: Types.Vector2Int, color: c.Color) void {
    const pos_index = posToIndex(pos);
    if (pos_index) |index| {
        if (index >= 0 and index < grid.len) {
            var tile = &grid[index];
            tile.tempBackground = color;
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
            //c.DrawEllipseLines(highlight.pos.x * Config.tile_width + Config.tile_width / 2, highlight.pos.y * Config.tile_height + Config.tile_height, Config.tile_width / 2, Config.tile_height / 3, highlight.color);
            //TODO: figure out the elipse, circle for now
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
    //TODO: probably should add a check for the tile type
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
                //TODO: probably gonna add something like walkable
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
    //TODO: end of combat rules
    return true;
}

pub fn findEmptyCloseCell(grid: []Level.Tile, entities: *std.ArrayList(*Entity.Entity), pos: Types.Vector2Int) Types.Vector2Int {
    const neighbours = neighboursAll(pos);
    _ = neighbours;
    _ = grid;
    _ = entities;
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

pub fn handlePlayerWalking(ctx: *Game.Context) !void {
    ctx.player.movementCooldown += ctx.delta;
    if (ctx.player.movementCooldown < Config.movement_animation_duration) {
        return;
    }

    const moveDelta = ctx.inputManager.takePositionInput() orelse return;

    var new_pos = Types.vector2IntAdd(ctx.player.pos, moveDelta);
    if (!canMove(ctx.grid.*, new_pos, ctx.entities.*)) {
        return;
    }

    new_pos = staircaseTransition(ctx, new_pos);

    ctx.player.move(new_pos, ctx.grid);
    ctx.player.movementCooldown = 0;
    ctx.gamestate.currentTurn = .enemy;
}
pub fn handlePlayerDeploying(ctx: *Game.Context) !void {
    try puppetSelection(ctx);
    try puppetDeployment(ctx);
}
pub fn handlePlayerCombat(ctx: *Game.Context) !void {
    switch (ctx.gamestate.currentTurn) {
        .player => {
            entitySelect(ctx);
            try entityAction(ctx);
            resolveTurnTaken(ctx);
        },
        .enemy => {},
    }
}

pub fn entitySelect(ctx: *Game.Context) void {
    const entityIndex = ctx.uiCommand.quickSelect orelse return;

    ctx.gamestate.resetMovementHighlight();
    //TODO: make a menu for swapping puppets in the array(different index => different keybind)
    if (entityIndex == 0) {
        //Player
        ctx.gamestate.selectedEntity = ctx.player;
    } else {
        if (ctx.player.data.player.puppets.items.len >= entityIndex) {
            ctx.gamestate.selectedEntity = ctx.player.data.player.puppets.items[entityIndex - 1];
        }
    }

    if (ctx.gamestate.selectedEntity) |selected_entity| {
        ctx.cameraManager.targetEntity = selected_entity;
        ctx.gamestate.removeCursor();
        ctx.gamestate.selectedEntityMode = .none;
        highlightEntity(ctx.gamestate, selected_entity.pos);
    }
}
pub fn entityAction(ctx: *Game.Context) !void {
    if (ctx.gamestate.selectedEntity) |entity| {
        if (ctx.gamestate.selectedAction == null) {
            ctx.gamestate.showMenu = .action_select;

            if (ctx.uiCommand.menuSelect) |menu_item| {
                switch (menu_item) {
                    .puppet_id => {
                        std.debug.print("menu_item is .puppet_id instead of .action", .{});
                    },
                    .action => |action| {
                        ctx.gamestate.selectedAction = action;
                    },
                }
            }
        }

        switch (ctx.gamestate.selectedEntityMode) {
            .none => {
                if (!entity.hasMoved and c.IsKeyPressed(c.KEY_Q)) {
                    ctx.gamestate.selectedEntityMode = .moving;
                    if (ctx.gamestate.selectedEntity) |selected_entity| {
                        ctx.gamestate.makeCursor(selected_entity.pos);
                    }
                } else if (c.IsKeyPressed(c.KEY_W)) {
                    ctx.gamestate.selectedEntityMode = .attacking;
                    if (ctx.gamestate.selectedEntity) |selected_entity| {
                        ctx.gamestate.makeCursor(selected_entity.pos);
                    }
                }
            },
            .moving => {
                if (c.IsKeyPressed(c.KEY_Q)) {
                    ctx.gamestate.selectedEntityMode = .none;
                    ctx.gamestate.removeCursor();
                    ctx.gamestate.resetMovementHighlight();
                }
            },
            .attacking => {
                //TODO: finish
                if (c.IsKeyPressed(c.KEY_W)) {
                    ctx.gamestate.selectedEntityMode = .none;
                    ctx.gamestate.removeCursor();
                    //TODO: attack highlight?
                    ctx.gamestate.resetAttackHighlight();
                }
            },
        }
        switch (ctx.gamestate.selectedEntityMode) {
            .none => {
                if (!entity.hasMoved and c.IsKeyPressed(c.KEY_Q)) {
                    ctx.gamestate.selectedEntityMode = .moving;
                    if (ctx.gamestate.selectedEntity) |selected_entity| {
                        ctx.gamestate.makeCursor(selected_entity.pos);
                    }
                } else if (c.IsKeyPressed(c.KEY_W)) {
                    ctx.gamestate.selectedEntityMode = .attacking;
                    if (ctx.gamestate.selectedEntity) |selected_entity| {
                        ctx.gamestate.makeCursor(selected_entity.pos);
                    }
                }
            },
            .moving => {
                if (c.IsKeyPressed(c.KEY_Q)) {
                    ctx.gamestate.selectedEntityMode = .none;
                    ctx.gamestate.removeCursor();
                    ctx.gamestate.resetMovementHighlight();
                }
            },
            .attacking => {
                //TODO: finish
                if (c.IsKeyPressed(c.KEY_W)) {
                    ctx.gamestate.selectedEntityMode = .none;
                    ctx.gamestate.removeCursor();
                    //TODO: attack highlight?
                    ctx.gamestate.resetAttackHighlight();
                }
            },
        }

        if (ctx.gamestate.selectedEntityMode == .moving) {
            ctx.gamestate.updateCursor();
            try selectedEntityMove(ctx, entity);
            if (c.IsKeyPressed(c.KEY_SPACE)) {
                skipMovement(ctx);
            }
        } else if (ctx.gamestate.selectedEntityMode == .attacking) {
            ctx.gamestate.updateCursor();
            try selectedEntityAttack(ctx, entity);
            if (c.IsKeyPressed(c.KEY_SPACE)) {
                skipAttack(ctx);
            }
        }

        if (entity.hasMoved and !entity.canAttack(ctx)) {
            //TODO:
        }

        if (entity.hasMoved and entity.hasAttacked) {
            entity.turnTaken = true;
        }
    }
}

pub fn resolveTurnTaken(ctx: *Game.Context) void {
    if (ctx.player.data.player.inCombatWith.items.len > 0) {
        if (ctx.player.turnTaken or ctx.player.allPupsTurnTaken()) {
            // finished turn
            ctx.gamestate.currentTurn = .enemy;
            ctx.player.resetTurnTakens();
        }
    }
}

pub fn skipMovement(ctx: *Game.Context) void {
    if (ctx.gamestate.selectedEntity) |entity| {
        entity.hasMoved = true;
    }
    ctx.gamestate.selectedEntityMode = .none;
    ctx.gamestate.resetMovementHighlight();
    ctx.gamestate.removeCursor();
}

pub fn skipAttack(ctx: *Game.Context) void {
    if (ctx.gamestate.selectedEntity) |entity| {
        entity.hasAttacked = true;
    }
    ctx.gamestate.selectedEntityMode = .none;
    ctx.gamestate.resetAttackHighlight();
    ctx.gamestate.removeCursor();
}

pub fn selectedEntityMove(ctx: *Game.Context, entity: *Entity.Entity) !void {
    try ctx.gamestate.highlightMovement(entity);

    if (c.IsKeyPressed(c.KEY_A)) {
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
}
pub fn selectedEntityAttack(ctx: *Game.Context, entity: *Entity.Entity) !void {
    try ctx.gamestate.highlightAttack(entity);

    if (c.IsKeyPressed(c.KEY_A)) {
        if (ctx.gamestate.cursor) |cur| {
            //try ctx.shaderManager.spawnSlash(entity.pos, cur);
            //try ctx.shaderManager.spawnExplosion(entity.pos);
            //try ctx.shaderManager.spawnImpact(cur);
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
}
pub fn attack(ctx: *Game.Context, entity: *Entity.Entity, attackedEntity: ?*Entity.Entity) void {
    if (attackedEntity) |attacked_entity| {
        _ = ctx;
        _ = attacked_entity;
        _ = entity;
    } else {}
}

pub fn getPupById(entities: std.ArrayList(*Entity.Entity), id: u32) ?*Entity.Entity {
    for (entities.items) |entity| {
        if (entity.id == id) {
            return entity;
        }
    }

    return null;
}

pub fn puppetSelection(ctx: *Game.Context) !void {
    if (ctx.gamestate.selectedPupId == null) {
        ctx.gamestate.showMenu = .puppet_select;

        if (ctx.uiCommand.menuSelect) |menu_item| {
            switch (menu_item) {
                .puppet_id => |pid| {
                    ctx.gamestate.selectedPupId = pid;
                },
                .action => {
                    std.debug.print("menu_item is .action instead of .puppet_id", .{});
                },
            }
        }
    }
}

pub fn puppetDeployment(ctx: *Game.Context) !void {
    if (ctx.gamestate.selectedPupId) |selected_pup| {
        ctx.gamestate.showMenu = .none;
        ctx.gamestate.makeUpdateCursor(ctx.player.pos);

        //TODO: put deploycells / highlight  into function
        if (ctx.gamestate.deployableCells == null) {
            const neighbours = neighboursAll(ctx.player.pos);
            ctx.gamestate.deployableCells = neighbours;
        }
        if (ctx.gamestate.deployableCells) |cells| {
            if (!ctx.gamestate.deployHighlighted) {
                for (cells) |value| {
                    if (value) |val| {
                        try highlightTile(ctx.gamestate, val);
                        ctx.gamestate.deployHighlighted = true;
                    }
                }
            }
        }
        if (ctx.uiCommand.confirm) {
            if (canDeploy(ctx.player, ctx.gamestate, ctx.grid.*, ctx.entities)) {
                try deployPuppet(ctx, selected_pup);
            }
        }
    }
}

pub fn staircaseTransition(ctx: *Game.Context, newPos: Types.Vector2Int) Types.Vector2Int {
    if (!isStaircase(ctx.world, newPos)) {
        return newPos;
    }

    if (getStaircaseDestination(ctx.world, newPos)) |lvllocation| {
        switchLevel(ctx.world, lvllocation.level);
        return lvllocation.pos;
    }

    return newPos;
}

//TODO: maybe add more states to the enum?
//should things like picking a puppet from the menu has its own state?
pub fn playerChangeState(ctx: *Game.Context, newState: Entity.playerStateEnum) !void {
    const oldState = ctx.player.data.player.state;
    if (oldState == newState) {
        //state is the same
        return;
    }

    //exit previous state
    switch (oldState) {
        .walking => try exitWalking(ctx),
        .deploying_puppets => try exitDeployingPuppets(ctx),
        .in_combat => try exitCombat(ctx),
    }

    //change state
    //TODO: should I first switch the state or call enter and then switch?
    ctx.player.data.player.state = newState;

    //enter new state
    switch (newState) {
        .walking => try enterWalking(ctx),
        .deploying_puppets => try enterDeployingPuppets(ctx),
        .in_combat => try enterCombat(ctx),
    }
}

pub fn enterWalking(ctx: *Game.Context) !void {
    if (canEndCombat(ctx.player, ctx.entities)) {
        ctx.gamestate.reset(); //TODO: make more reset functions depending on the state?
        ctx.player.endCombat();
        ctx.gamestate.showMenu = .none;
    }
}
pub fn exitWalking(ctx: *Game.Context) !void {
    _ = ctx;
    //TODO:
}
pub fn enterDeployingPuppets(ctx: *Game.Context) !void {
    //TODO: filter out entities that are supposed to be in the combat
    // could be some mechanic around attention/stealth
    // smarter entities shout at other to help etc...

    ctx.player.inCombat = true;

    for (ctx.entities.items) |entity| {
        try ctx.player.data.player.inCombatWith.append(entity);
        entity.resetPathing();
        entity.inCombat = true;
    }
}
pub fn exitDeployingPuppets(ctx: *Game.Context) !void {
    _ = ctx;
}
pub fn enterCombat(ctx: *Game.Context) !void {
    ctx.gamestate.reset();
    ctx.gamestate.showMenu = .none;
}
pub fn exitCombat(ctx: *Game.Context) !void {
    _ = ctx;
    //TODO:
}
