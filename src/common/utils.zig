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
