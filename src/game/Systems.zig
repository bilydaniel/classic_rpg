const Player = @import("../entities/player.zig");
const Config = @import("../common/config.zig");
const Utils = @import("../common/utils.zig");
const World = @import("world.zig");
const Level = @import("level.zig");
const Types = @import("../common/types.zig");
const std = @import("std");
const Pathfinder = @import("../game/pathfinder.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub fn updatePlayer(player: *Player.Player, delta: f32, world: *World.World, camera: *c.Camera2D, pathfinder: *Pathfinder.Pathfinder) void {
    //TODO: make movement better, feeld a bit off
    const grid = world.currentLevel.grid;

    if (Config.mouse_mode) {
        //HOVER:
        const hover_win = c.GetMousePosition();
        const hover_texture = Utils.screenToRenderTextureCoords(hover_win);
        //TODO: no idea if I still need screenToRenderTextureCoords, i dont use the render texture
        //anymore
        const hover_world = c.GetScreenToWorld2D(hover_texture, camera.*);
        const hover_pos = Types.vector2ConvertWithPixels(hover_world);
        highlightTile(grid, hover_pos);

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

        if (player.dest) |destination| {
            highlightTile(grid, destination);
            if (player.movementCooldown > 0.1) {
                const dest = Types.vector2IntConvert(destination);
                const player_pos = Types.vector2IntConvert(player.pos);

                const direction = Utils.vector2Subtract(Utils.vector2TileToPixel(dest), Utils.vector2TileToPixel(player_pos));
                if (Utils.vector2Cmp(direction, .{ .x = 0, .y = 0 })) {
                    player.dest = null;
                }

                const normalized = Utils.vector2Normalize(direction);
                var movement = Utils.vector2Scale(normalized, @floatFromInt(player.speed));
                if (movement.x > 0 and movement.x < 1) {
                    movement.x = 1;
                }

                if (movement.y > 0 and movement.y < 1) {
                    movement.y = 1;
                }
                player.pos = Types.vector2Convert(Utils.vector2Add(player_pos, movement));
                calculateFOV(&world.currentLevel.grid, player.pos, 8);
                player.movementCooldown = 0;
                if (isStaircase(world, player.pos)) {
                    const levelLocation = getStaircaseDestination(world, player.pos);
                    if (levelLocation) |lvllocation| {
                        switchLevel(world, lvllocation.level);
                        player.pos = lvllocation.pos;
                        player.dest = null;
                    }
                }
            }
            player.movementCooldown += delta;
        }
    } else {
        player.keyWasPressed = false;

        if (player.movementCooldown > 0.1) {
            var new_pos = player.pos;
            var moved = false;

            if (!player.keyWasPressed) {
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
                    player.keyWasPressed = true;
                    calculateFOV(&world.currentLevel.grid, new_pos, 8);
                }
            }

            // Reset flag when keys are released
            if (!c.IsKeyDown(c.KEY_H) and
                !c.IsKeyDown(c.KEY_L) and
                !c.IsKeyDown(c.KEY_J) and
                !c.IsKeyDown(c.KEY_K))
            {
                player.keyWasPressed = false;
            }
        }
        player.movementCooldown += delta;
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

pub fn highlightTile(grid: []Level.Tile, pos: Types.Vector2Int) void {
    const pos_index = posToIndex(pos);
    if (pos_index) |index| {
        if (index >= 0 and index < grid.len) {
            var tile = &grid[index];
            tile.tempBackground = c.GREEN;
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
            result[count] = result_pos;
            count += 1;
        }
    }
    return result;
}
