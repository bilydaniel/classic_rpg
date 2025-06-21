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
