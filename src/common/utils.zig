const Window = @import("../game/window.zig");
const Config = @import("../common/config.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub fn screenToRenderTextureCoords(screen_pos: c.Vector2, window: Window.Window) c.Vector2 {
    return .{
        .x = (screen_pos.x - @as(f32, @floatFromInt(window.offsetx))) / window.scale,
        .y = (screen_pos.y - @as(f32, @floatFromInt(window.offsety))) / window.scale,
    };
}
