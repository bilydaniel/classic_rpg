const Config = @import("../common/config.zig");
const Utils = @import("../common/utils.zig");
const World = @import("world.zig");
const Entity = @import("entity.zig");
const Level = @import("level.zig");
const Types = @import("../common/types.zig");
const std = @import("std");
const Pathfinder = @import("../game/pathfinder.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub fn updatePlayer(player: *Entity.Entity, delta: f32, world: *World.World, camera: *c.Camera2D, pathfinder: *Pathfinder.Pathfinder, entities: *std.ArrayList(*Entity.Entity)) !void {
    const grid = world.currentLevel.grid;
    if (!player.data.player.inCombat) {
        //TODO: make movement better, feeld a bit off

        if (Config.mouse_mode) {
            //HOVER:
            const hover_win = c.GetMousePosition();
            const hover_texture = Utils.screenToRenderTextureCoords(hover_win);
            //TODO: no idea if I still need screenToRenderTextureCoords, i dont use the render texture
            //anymore
            const hover_world = c.GetScreenToWorld2D(hover_texture, camera.*);
            const hover_pos = Types.vector2ConvertWithPixels(hover_world);
            highlightTile(grid, hover_pos, c.GREEN);

            if (c.IsMouseButtonPressed(c.MOUSE_BUTTON_RIGHT)) {
                const destination = c.GetMousePosition();
                const renderDestination = Utils.screenToRenderTextureCoords(destination);
                const world_pos = c.GetScreenToWorld2D(renderDestination, camera.*);

                const player_dest = Utils.pixelToTile(world_pos);
                //player.dest = player_dest;
                //TODO: check for wron player_dest
                player.path = pathfinder.findPath(grid, player.pos, player_dest) catch null;
            }

            if (player.path) |path| {
                if (path.currIndex < path.nodes.items.len) {
                    //TODO: add player movement speed
                    if (player.movementCooldown > Config.turn_speed) {
                        player.pos = path.nodes.items[path.currIndex];
                        player.path.?.currIndex += 1;
                        player.movementCooldown = 0;
                    }
                } else {
                    player.path.?.deinit();
                    player.path = null;
                }
                player.movementCooldown += delta;
            }
        } else {
            //TODO: change this shit, change the input system to something better

            if (player.movementCooldown > 0.1) {
                var new_pos = player.pos;
                var moved = false;

                if (c.IsKeyDown(c.KEY_H)) {
                    new_pos.x -= 1;
                    moved = true;
                } else if (c.IsKeyDown(c.KEY_L)) {
                    new_pos.x += 1;
                    moved = true;
                } else if (c.IsKeyDown(c.KEY_J)) {
                    new_pos.y += 1;
                    moved = true;
                } else if (c.IsKeyDown(c.KEY_K)) {
                    new_pos.y -= 1;
                    moved = true;
                }

                if (c.IsKeyPressed(c.KEY_F)) {
                    try player.startCombat(entities, grid);
                }

                if (moved and canMove(world.currentLevel.grid, new_pos)) {
                    if (isStaircase(world, new_pos)) {
                        const levelLocation = getStaircaseDestination(world, new_pos);
                        if (levelLocation) |lvllocation| {
                            switchLevel(world, lvllocation.level);
                            new_pos = lvllocation.pos;
                        }
                    }
                    player.pos = new_pos;
                    player.movementCooldown = 0;
                    calculateFOV(&world.currentLevel.grid, new_pos, 8);
                    const combat = checkCombatStart(player, entities);
                    if (combat and !player.data.player.inCombat) {
                        try player.startCombat(entities, grid);
                    }
                }
            }
            player.movementCooldown += delta;
        }
    } else {
        if (player.data.player.deployingPuppets) {
            const neighbours = neighboursAll(player.pos);
            for (neighbours) |value| {
                if (value) |val| {
                    highlightTile(grid, val, c.BLUE);
                    if (player.data.player.deployingCursor == null) {
                        player.data.player.deployingCursor = player.pos;
                    }
                }
            }
        }
        if (player.data.player.deployingCursor) |cursor| {
            player.visible = false;
            highlightTile(grid, cursor, c.YELLOW);
            if (c.IsKeyPressed(c.KEY_H)) {
                player.data.player.deployingCursor.?.x -= 1;
            } else if (c.IsKeyPressed(c.KEY_L)) {
                player.data.player.deployingCursor.?.x += 1;
            } else if (c.IsKeyPressed(c.KEY_J)) {
                player.data.player.deployingCursor.?.y += 1;
            } else if (c.IsKeyPressed(c.KEY_K)) {
                player.data.player.deployingCursor.?.y -= 1;
            }
        }
        if (c.IsKeyPressed(c.KEY_F)) {
            if (canEndCombat(player, entities)) {
                player.endCombat(entities);
                player.visible = true;
                player.data.player.deployingCursor = null;
            }
        }
    }
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

//TODO: finish highlighting tiles that you can deploy to
pub fn highlightTile(grid: []Level.Tile, pos: Types.Vector2Int, color: c.Color) void {
    const pos_index = posToIndex(pos);
    if (pos_index) |index| {
        if (index >= 0 and index < grid.len) {
            var tile = &grid[index];
            tile.tempBackground = color;
        }
    }
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
    return @intCast(pos.y * Config.level_width + pos.x);
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

pub fn deployPuppets(puppets: *std.ArrayList(*Entity.Entity), entities: *std.ArrayList(*Entity.Entity), grid: []Level.Tile, pos: Types.Vector2Int) !void {
    for (puppets.items) |*entity| {
        //const pup_pos = findEmptyCloseCell(grid, entities, pos);
        _ = grid;
        _ = pos;
        try entities.append(entity);
    }
}

pub fn findEmptyCloseCell(grid: []Level.Tile, entities: *std.ArrayList(*Entity.Entity), pos: Types.Vector2Int) Types.Vector2Int {
    const neighbours = neighboursAll(pos);
    _ = neighbours;
    _ = grid;
    _ = entities;
}

pub fn returnPuppets(player: *Entity.Entity, entities: *std.ArrayList(*Entity.Entity)) !void {
    findEntitiesType(entities, &player.data.player.puppets, Entity.EntityType.puppet, true);
}

pub fn findEntitiesType(entities: *std.ArrayList(*Entity.Entity), result: *std.ArrayList(*Entity.Entity), entityType: Entity.EntityType, remove: bool) void {
    var i = entities.items.len;
    while (i > 0) {
        i -= 1;
        if (entities.items[i].data == entityType) {
            std.debug.print("FOUND \n", .{});
        }
        if (remove) {}
        _ = result;
    }
}
