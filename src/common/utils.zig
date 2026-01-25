const Window = @import("../game/window.zig");
const Config = @import("../common/config.zig");
const Types = @import("types.zig");
const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

pub fn screenToRenderTextureCoords(screen_pos: c.Vector2) c.Vector2 {
    return .{
        .x = (screen_pos.x - @as(f32, @floatFromInt(Window.offsetx))) / Window.scale,
        .y = (screen_pos.y - @as(f32, @floatFromInt(Window.offsety))) / Window.scale,
    };
}

pub fn pixelToTile(pos: c.Vector2) Types.Vector2Int {
    return (Types.Vector2Int{ .x = @intFromFloat(pos.x / Config.tile_width), .y = @intFromFloat(pos.y / Config.tile_height) });
}

pub fn toNullTerminated(allocator: std.mem.Allocator, string: []u8) ![]u8 {
    const newString = try std.fmt.allocPrint(allocator, "{s}\x00", .{string});
    return (newString);
}

pub fn vector2Subtract(a: c.Vector2, b: c.Vector2) c.Vector2 {
    return c.Vector2{
        .x = a.x - b.x,
        .y = a.y - b.y,
    };
}
pub fn vector2Add(a: c.Vector2, b: c.Vector2) c.Vector2 {
    return c.Vector2{
        .x = a.x + b.x,
        .y = a.y + b.y,
    };
}
pub fn vector2Normalize(a: c.Vector2) c.Vector2 {
    const len = vector2Len(a);
    if (len == 0) {
        return a;
    }
    return c.Vector2{
        .x = a.x / len,
        .y = a.y / len,
    };
}
pub fn vector2Len(a: c.Vector2) f32 {
    const x2 = a.x * a.x;
    const y2 = a.y * a.y;
    const len = std.math.sqrt(x2 + y2);
    return len;
}
pub fn vector2Scale(a: c.Vector2, con: f32) c.Vector2 {
    return c.Vector2{
        .x = a.x * con,
        .y = a.y * con,
    };
}

pub fn vector2TileToPixel(a: c.Vector2) c.Vector2 {
    return c.Vector2{
        .x = a.x * Config.tile_width,
        .y = a.y * Config.tile_height,
    };
}

pub fn vector2Cmp(a: c.Vector2, b: c.Vector2) bool {
    return a.x == b.x and a.y == b.y;
}

pub fn makeSourceRect(id: i32) c.Rectangle {
    const x: f32 = @floatFromInt(@mod((id * Config.tile_width), (Config.tileset_width * Config.tile_width)));
    const y: f32 = @floatFromInt(@divFloor((id * Config.tile_width), (Config.tileset_width)));
    return c.Rectangle{
        .x = x,
        .y = y,
        .width = Config.tile_width,
        .height = Config.tile_height,
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
