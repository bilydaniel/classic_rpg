const std = @import("std");
const Types = @import("../common/types.zig");
const Config = @import("../common/config.zig");
const c = @cImport({
    @cInclude("raylib.h");
});
pub const Button = struct {
    pos: Types.Vector2Int,
    posDisplay: Types.Vector2Int,
    height: i32,
    width: i32,
    label: []const u8,

    pub fn initValues(this: *Button, pos: Types.Vector2Int, label: []const u8) void {
        std.debug.print("BUTTON_LABEL: {s}\n", .{label});
        this.pos = pos;
        this.height = 16;
        this.width = 16;
        this.label = label;
    }

    pub fn Draw(this: @This(), scroll: f32) void {
        // Calculate display position with scroll offset
        const displayY = this.pos.y - @as(i32, @intFromFloat(scroll));

        // Only draw if visible on screen
        if (displayY >= 0 and displayY < Config.game_height) {
            c.DrawRectangle(@intCast(this.pos.x), displayY, this.width, this.height, c.RED);
            c.DrawText(this.label.ptr, this.pos.x, displayY, 5, c.YELLOW);
        }
    }

    pub fn Update(this: *Button) void {
        if (c.IsMouseButtonPressed(c.MOUSE_BUTTON_LEFT)) {}
        std.debug.print("(button)x: {d}, y: {d}\n", .{ this.pos.x, this.pos.y });
        const mouse_pos = c.GetMousePosition();
        std.debug.print("(mouse)x: {d}, y: {d}\n", .{ mouse_pos.x, mouse_pos.y });
    }
};
