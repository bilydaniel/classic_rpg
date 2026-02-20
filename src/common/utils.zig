const Window = @import("../game/window.zig");
const Level = @import("../game/level.zig");
const Config = @import("../common/config.zig");
const Types = @import("types.zig");
const std = @import("std");
const rl = @import("raylib");

pub fn screenToRenderTextureCoords(screen_pos: rl.Vector2) rl.Vector2 {
    return .{
        .x = (screen_pos.x - @as(f32, @floatFromInt(Window.offsetx))) / Window.scale,
        .y = (screen_pos.y - @as(f32, @floatFromInt(Window.offsety))) / Window.scale,
    };
}

pub fn pixelToTile(pos: rl.Vector2) Types.Vector2Int {
    return (Types.Vector2Int{ .x = @intFromFloat(pos.x / Config.tile_width), .y = @intFromFloat(pos.y / Config.tile_height) });
}

pub fn toNullTerminated(allocator: std.mem.Allocator, string: []u8) ![]u8 {
    const newString = try std.fmt.allocPrint(allocator, "{s}\x00", .{string});
    return (newString);
}

pub fn vector2Subtract(a: rl.Vector2, b: rl.Vector2) rl.Vector2 {
    return rl.Vector2{
        .x = a.x - b.x,
        .y = a.y - b.y,
    };
}
pub fn vector2Add(a: rl.Vector2, b: rl.Vector2) rl.Vector2 {
    return rl.Vector2{
        .x = a.x + b.x,
        .y = a.y + b.y,
    };
}
pub fn vector2Normalize(a: rl.Vector2) rl.Vector2 {
    const len = vector2Len(a);
    if (len == 0) {
        return a;
    }
    return rl.Vector2{
        .x = a.x / len,
        .y = a.y / len,
    };
}
pub fn vector2Len(a: rl.Vector2) f32 {
    const x2 = a.x * a.x;
    const y2 = a.y * a.y;
    const len = std.math.sqrt(x2 + y2);
    return len;
}
pub fn vector2Scale(a: rl.Vector2, con: f32) rl.Vector2 {
    return rl.Vector2{
        .x = a.x * con,
        .y = a.y * con,
    };
}

pub fn vector2TileToPixel(a: rl.Vector2) rl.Vector2 {
    return rl.Vector2{
        .x = a.x * Config.tile_width,
        .y = a.y * Config.tile_height,
    };
}

pub fn vector2Cmp(a: rl.Vector2, b: rl.Vector2) bool {
    return a.x == b.x and a.y == b.y;
}

pub fn makeSourceRect(id: i32) rl.Rectangle {
    const column = @mod(id, Config.tileset_width);
    const row = @divFloor(id, Config.tileset_width);

    const x: f32 = @floatFromInt(Config.tileset_margin + (column * Config.tileset_stride));
    const y: f32 = @floatFromInt(Config.tileset_margin + (row * Config.tileset_stride));

    return rl.Rectangle{
        .x = x,
        .y = y,
        .width = @floatFromInt(Config.tile_width),
        .height = @floatFromInt(Config.tile_height),
    };
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

pub fn indexToPixel(index: i32) rl.Vector2 {
    const x = (index % Config.level_width) * Config.tile_width;
    const y = (@divFloor(index, Config.level_width)) * Config.tile_height;
    return rl.Vector2{ .x = x, .y = y };
}

pub fn getTileIdx(grid: Types.Grid, index: usize) ?Level.Tile {
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
