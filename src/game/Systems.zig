const Player = @import("../entities/player.zig");
const Config = @import("../common/config.zig");
const World = @import("world.zig");
const Level = @import("level.zig");
const Types = @import("../common/types.zig");
const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});
pub fn updatePlayer(player: *Player.Player, delta: f32, world: *World.World) void {
    //TODO: make movement better, feeld a bit off
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
        grid.*[tileIndex].visible = true;
        grid.*[tileIndex].seen = true;

        if (grid.*[tileIndex].solid == true) {
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

pub fn switchLevel(world: *World.World, levelID: u32) void {
    for (world.levels.items) |level| {
        if (level.id == levelID) {
            world.currentLevel = level;
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
    const index = posToIndex(pos);
    if (index < grid.len) {
        return !grid[index].solid;
    }
    return false;
}

pub fn posToIndex(pos: Types.Vector2Int) usize {
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
