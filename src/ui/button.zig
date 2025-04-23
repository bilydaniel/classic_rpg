const std = @import("std");
const Types = @import("../common/types.zig");
const Config = @import("../common/config.zig");
const Menu = @import("menu.zig");
const c = @cImport({
    @cInclude("raylib.h");
});
pub const Button = struct {
    pos: Types.Vector2Int,
    posDisplay: Types.Vector2Int,
    height: i32,
    width: i32,
    label: []const u8,
    callback: ?*const fn (menu: *Menu.Menu, data: ?*anyopaque) void = null,
    data: *anyopaque = null,

    pub fn initValues(this: *Button, pos: Types.Vector2Int, label: []const u8, data: *anyopaque) void {
        this.pos = pos;
        this.posDisplay = pos;
        this.height = 16;
        this.width = 16;
        this.label = label;
        this.data = data;
    }

    pub fn Draw(this: @This()) !void {
        if (this.posDisplay.y >= 0 and this.posDisplay.y < Config.game_height) {
            const text_length = c.MeasureText(this.label.ptr, 5);
            c.DrawRectangle(@intCast(this.pos.x), this.posDisplay.y, text_length, this.height, c.RED);
            //c.DrawText(this.label.ptr, this.pos.x, displayY, 5, c.YELLOW);
            var buffer: [64]u8 = undefined;
            const formatted = try std.fmt.bufPrint(&buffer, "{d}", .{this.posDisplay.y});
            c.DrawText(formatted.ptr, this.pos.x, this.posDisplay.y, 5, c.YELLOW);
        }
    }

    pub fn Update(this: *Button, scroll: f32) ?*anyopaque {
        this.posDisplay.y = this.pos.y - @as(i32, @intFromFloat(scroll));
        if (c.IsMouseButtonPressed(c.MOUSE_BUTTON_LEFT)) {
            const mouse_pos = c.GetMousePosition();
            const collision = c.CheckCollisionPointRec(mouse_pos, c.Rectangle{ .x = @floatFromInt(this.posDisplay.x), .y = @floatFromInt(this.posDisplay.y), .width = @floatFromInt(this.width), .height = @floatFromInt(this.height) });
            if (collision) {
                return this.data;
            }
        }
        return null;
    }
};
