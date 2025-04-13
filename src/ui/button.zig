const std = @import("std");
const Types = @import("../common/types.zig");
const Config = @import("../common/config.zig");
const c = @cImport({
    @cInclude("raylib.h");
});
pub const Button = struct {
    pos: Types.Vector2Int,
    height: i32,
    width: i32,
    label: []const u8,

    pub fn initValues(this: *Button, pos: Types.Vector2Int, label: []const u8) void {
        this.pos = pos;
        this.height = 16;
        this.width = 16;
        this.label = label;
    }

    pub fn Draw(this: @This(), scroll: f32) void {
        //c.DrawTexture(texture: Texture2D, posX: c_int, posY: c_int, tint: Color)
        if (this.pos.y > @as(i32, @intFromFloat(scroll)) and this.pos.y < Config.game_height + @as(i32, @intFromFloat(scroll))) {
            c.DrawRectangle(@intCast(this.pos.x), this.pos.y, this.width, this.height, c.RED);
            c.DrawText(this.label.ptr, this.pos.x, this.pos.y, 5, c.YELLOW);
        }
    }

    pub fn Update(this: *Button) void {
        std.debug.print("(button)x: {d}, y: {d}\n", .{ this.pos.x, this.pos.y });
        const mouse_pos = c.GetMousePosition();
        std.debug.print("(mouse)x: {d}, y: {d}\n", .{ mouse_pos.x, mouse_pos.y });
    }
};
