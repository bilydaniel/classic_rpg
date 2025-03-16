const Window = @import("../game/window.zig");
const Config = @import("../common/config.zig");
const Types = @import("types.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub fn screenToRenderTextureCoords(screen_pos: c.Vector2, window: Window.Window) c.Vector2 {
    return .{
        .x = (screen_pos.x - @as(f32, @floatFromInt(window.offsetx))) / window.scale,
        .y = (screen_pos.y - @as(f32, @floatFromInt(window.offsety))) / window.scale,
    };
}

pub fn pixelToTile(pos: c.Vector2) Types.Vector2Int {
    return (Types.Vector2Int{ .x = @intFromFloat(pos.x / Config.tile_width), .y = @intFromFloat(pos.y / Config.tile_height) });
}
