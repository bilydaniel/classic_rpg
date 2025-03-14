const c = @cImport({
    @cInclude("raylib.h");
});

pub fn screenToRenderTextureCoords(screen_pos: c.Vector2, offset_x: i32, offset_y: i32, scaled_width: i32, scaled_height: i32, game_width: f32, game_height: f32) c.Vector2 {
    return .{
        .x = (screen_pos.x - @as(f32, @floatFromInt(offset_x))) / @as(f32, @floatFromInt(scaled_width)) * game_width,
        .y = (screen_pos.y - @as(f32, @floatFromInt(offset_y))) / @as(f32, @floatFromInt(scaled_height)) * game_height,
    };
}
