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
const c = @cImport({
    @cInclude("raylib.h");
});

pub const playerUpdateContext = struct {
    gamestate: *Gamestate.gameState,
    player: *Entity.Entity,
    delta: f32,
    world: *World.World,
    grid: *[]Level.Tile,
    cameraManager: *CameraManager.CamManager,
    pathfinder: *Pathfinder.Pathfinder,
    entities: *std.ArrayList(*Entity.Entity),
};
pub fn updatePlayer(gamestate: *Gamestate.gameState, player: *Entity.Entity, delta: f32, world: *World.World, cameraManager: *CameraManager.CamManager, pathfinder: *Pathfinder.Pathfinder, entities: *std.ArrayList(*Entity.Entity)) !void {
    var ctx = playerUpdateContext{
        .gamestate = gamestate,
        .player = player,
        .delta = delta,
        .world = world,
        .grid = &world.currentLevel.grid, // for easier access
        .cameraManager = cameraManager,
        .pathfinder = pathfinder,
        .entities = entities,
    };
    //std.debug.print("STATE: {}\n", .{player.data.player.state});
    switch (player.data.player.state) {
        .walking => {
            try handlePlayerWalking(&ctx);
        },
        .deploying_puppets => {
            try handlePlayerDeploying(&ctx);
        },
        .in_combat => {
            try handlePlayerCombat(&ctx);
        },
    }
}

pub fn deployPuppet(player: *Entity.Entity, gamestate: *Gamestate.gameState, entities: *std.ArrayList(*Entity.Entity)) !void {
    const puppets = &player.data.player.puppets;
    for (puppets.items) |pup| {
        if (!pup.data.puppet.deployed) {
            if (gamestate.cursor) |curs| {
                pup.pos = curs;
                pup.data.puppet.deployed = true;
                try entities.append(pup);
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

        const entity = getEntityByPos(entities, dep_pos);
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

pub fn getEntityByPos(entities: *std.ArrayList(*Entity.Entity), pos: Types.Vector2Int) ?*Entity.Entity {
    for (entities.items) |entity| {
        if (Types.vector2IntCompare(entity.pos, pos)) {
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
        .color = c.YELLOW,
        .type = .pup_deploy,
    });
}

pub fn drawCursor(gridLen: usize, pos: Types.Vector2Int) void {
    const pos_index = posToIndex(pos);
    if (pos_index) |index| {
        if (index >= 0 and index < gridLen) {
            //TODO: debug why the box doesent fit
            //c.DrawRectangleLines(pos.x * Config.tile_width + 1, pos.y * Config.tile_height + 1, Config.tile_width, Config.tile_height, c.YELLOW);
        }
    }
}

pub fn drawGameState(gamestate: *Gamestate.gameState, currentLevel: *Level.Level) void {
    _ = currentLevel;
    if (gamestate.highlightedTiles.items.len > 0) {
        for (gamestate.highlightedTiles.items) |highlight| {
            c.DrawRectangleLines(highlight.pos.x * Config.tile_width, highlight.pos.y * Config.tile_height, Config.tile_width, Config.tile_height, c.BLUE);
        }
    }

    if (gamestate.highlightedEntity) |highlight| {
        if (highlight.type == .circle) {
            c.DrawCircleLines(highlight.pos.x * Config.tile_width + Config.tile_width / 2, highlight.pos.y * Config.tile_height + Config.tile_height / 2, Config.tile_width / 2, highlight.color);
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
        .color = c.YELLOW,
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

pub fn canMove(grid: []Level.Tile, pos: Types.Vector2Int) bool {
    const pos_index = posToIndex(pos);
    if (pos_index) |index| {
        if (index < grid.len) {
            return !grid[index].solid;
        }
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
        const distance = Types.vector2Distance(player.pos, entity.pos);
        if (distance < 3) {
            return true;
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

pub fn returnPuppets(entities: *std.ArrayList(*Entity.Entity)) !void {
    removeEntitiesType(entities, Entity.EntityType.puppet);
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

pub fn handlePlayerWalking(ctx: *playerUpdateContext) !void {
    ctx.player.movementCooldown += ctx.delta;
    //TODO: test the movement duration value
    if (ctx.player.movementCooldown < Config.movement_animation_duration) {
        return;
    }
    var new_pos = ctx.player.pos;
    var moved = false;

    moved = InputManager.takePositionInput(&new_pos);

    if (c.IsKeyPressed(c.KEY_F)) {
        try ctx.player.startCombatSetup(ctx.entities, ctx.grid.*);
    }

    if (moved and canMove(ctx.world.currentLevel.grid, new_pos)) {
        if (isStaircase(ctx.world, new_pos)) {
            const levelLocation = getStaircaseDestination(ctx.world, new_pos);
            if (levelLocation) |lvllocation| {
                switchLevel(ctx.world, lvllocation.level);
                new_pos = lvllocation.pos;
            }
        }
        ctx.player.pos = new_pos;
        ctx.player.movementCooldown = 0;

        calculateFOV(&ctx.world.currentLevel.grid, new_pos, 8);

        const combat = checkCombatStart(ctx.player, ctx.entities);
        if (combat and ctx.player.data.player.state != .in_combat) {
            try ctx.player.startCombatSetup(ctx.entities, ctx.grid.*);
        }
    }
}
pub fn handlePlayerDeploying(ctx: *playerUpdateContext) !void {
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

    ctx.gamestate.makeCursor(ctx.player.pos);
    ctx.gamestate.updateCursor();
    if (c.IsKeyPressed(c.KEY_D)) {
        if (canDeploy(ctx.player, ctx.gamestate, ctx.grid.*, ctx.entities)) {
            try deployPuppet(ctx.player, ctx.gamestate, ctx.entities);
        }
    }

    //all puppets deployed
    if (ctx.player.data.player.allPupsDeployed()) {
        ctx.gamestate.resetDeploy();
        ctx.player.data.player.state = .in_combat;
    }
    //TODO: maybe remove?
    if (c.IsKeyPressed(c.KEY_F)) {
        if (canEndCombat(ctx.player, ctx.entities)) {
            ctx.gamestate.resetDeploy();
            ctx.player.endCombat(ctx.entities);
        }
    }
}
pub fn handlePlayerCombat(ctx: *playerUpdateContext) !void {
    switch (ctx.gamestate.currentTurn) {
        .none => {
            ctx.gamestate.currentTurn = .player; //player always starts, for now
        },
        .player => {
            try playerCombatTurn(ctx);

            if (ctx.gamestate.cursor != null) {
                //TODO: make this code general, just spawn and use the value from cursor where you need
                if (c.IsKeyPressed(c.KEY_H)) {
                    ctx.gamestate.cursor.?.x -= 1;
                } else if (c.IsKeyPressed(c.KEY_L)) {
                    ctx.gamestate.cursor.?.x += 1;
                } else if (c.IsKeyPressed(c.KEY_J)) {
                    ctx.gamestate.cursor.?.y += 1;
                } else if (c.IsKeyPressed(c.KEY_K)) {
                    ctx.gamestate.cursor.?.y -= 1;
                }
            }
            if (c.IsKeyPressed(c.KEY_F)) {
                // forcing end of combat for testing, REMOVE
                ctx.player.endCombat(ctx.entities);
                std.debug.print("F\n", .{});
                return;
            }

            if (ctx.player.data.player.inCombatWith.items.len == 0) {
                // everyone is dead
                ctx.gamestate.currentTurn = .none;
                ctx.player.data.player.state = .walking;
            } else {
                if (ctx.player.turnTaken or ctx.player.allPupsTurnTaken()) {
                    // finished turn
                    ctx.gamestate.currentTurn = .enemy;
                    std.debug.print("turn_done\n", .{});
                }
            }
        },
        .enemy => {},
    }
}

pub fn playerCombatTurn(ctx: *playerUpdateContext) !void {
    // take input, pick who you want to move => move/attack
    // after you moved all pices, end
    // you can either player master or all puppets

    entitySelect(ctx);
    try selectedEntityAction(ctx);
}

pub fn entitySelect(ctx: *playerUpdateContext) void {
    if (c.IsKeyPressed(c.KEY_ONE)) {
        ctx.gamestate.selectedEntity = ctx.player;
    } else if (c.IsKeyPressed(c.KEY_TWO)) {
        if (ctx.player.data.player.puppets.items.len > 0) {
            ctx.gamestate.selectedEntity = ctx.player.data.player.puppets.items[0];
            ctx.cameraManager.targetEntity = ctx.player.data.player.puppets.items[0];
        }
    } else if (c.IsKeyPressed(c.KEY_THREE)) {
        if (ctx.player.data.player.puppets.items.len > 1) {
            ctx.gamestate.selectedEntity = ctx.player.data.player.puppets.items[1];
            ctx.cameraManager.targetEntity = ctx.player.data.player.puppets.items[1];
        }
    } else if (c.IsKeyPressed(c.KEY_FOUR)) {
        if (ctx.player.data.player.puppets.items.len > 2) {
            ctx.gamestate.selectedEntity = ctx.player.data.player.puppets.items[2];
            ctx.cameraManager.targetEntity = ctx.player.data.player.puppets.items[2];
        }
    } else if (c.IsKeyPressed(c.KEY_FIVE)) {
        if (ctx.player.data.player.puppets.items.len > 3) {
            ctx.gamestate.selectedEntity = ctx.player.data.player.puppets.items[3];
            ctx.cameraManager.targetEntity = ctx.player.data.player.puppets.items[3];
        }
    }
}
pub fn selectedEntityAction(ctx: *playerUpdateContext) !void {
    if (ctx.gamestate.selectedEntity) |entity| {
        //TODO: move camera to the selected entity,
        //how do I highlight the selected entity?
        //probaly should try a blink, give a duration to highlight
        //could try to do a circle highlight

        highlightEntity(ctx.gamestate, entity.pos);

        if (c.IsKeyPressed(c.KEY_Q)) {
            ctx.gamestate.selectedEntityMode = .moving;
        } else if (c.IsKeyPressed(c.KEY_W)) {
            ctx.gamestate.selectedEntityMode = .attacking;
        }

        if (ctx.gamestate.selectedEntityMode == .moving) {
            std.debug.print("entity_move \n", .{});
            try selectedEntityMove(ctx, entity);
        } else if (ctx.gamestate.selectedEntityMode == .attacking) {
            try selectedEntityAttack(ctx, entity);
            std.debug.print("attacking...\n", .{});
        }
    }
}
pub fn selectedEntityMove(ctx: *playerUpdateContext, entity: *Entity.Entity) !void {
    if (ctx.gamestate.movableTiles.items.len == 0) {
        try neighboursDistance(entity.pos, 2, &ctx.gamestate.movableTiles);
    }
    if (ctx.gamestate.movableTiles.items.len > 0) {
        if (!ctx.gamestate.movementHighlighted) {
            for (ctx.gamestate.movableTiles.items) |item| {
                //TODO: highlight only valid tiles
                try highlightTile(ctx.gamestate, item);
                ctx.gamestate.cursor = ctx.player.pos;
                //TODO: make a spawn and remove cursor func
                //make an update function for cursor, probably for the whole game state struct
            }

            std.debug.print("high {}\n", .{ctx.gamestate.highlightedTiles.items.len});
        }
        ctx.gamestate.movementHighlighted = true;
    }
    if (c.IsKeyPressed(c.KEY_A)) {
        //TODO: move to cursor
        //TODO: add checks to valid places

        if (ctx.gamestate.cursor) |cur| {
            ctx.player.path = try ctx.pathfinder.findPath(ctx.grid.*, ctx.player.pos, cur);
        }
    }
    ctx.player.makeCombatStep(ctx.delta, ctx.entities);
}
pub fn selectedEntityAttack(ctx: *playerUpdateContext, entity: *Entity.Entity) !void {
    //TODO: continue
    _ = ctx;
    _ = entity;
}
