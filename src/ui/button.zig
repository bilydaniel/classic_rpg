const std = @import("std");
const Types = @import("../common/types.zig");
const Config = @import("../common/config.zig");
const Menu = @import("menu.zig");
const Utils = @import("../common/utils.zig");
const Window = @import("../game/window.zig");
const c = @cImport({
    @cInclude("raylib.h");
});
pub const Button = struct {
    //TODO:
    rect: c.Rectangle, //TODO: use this instead of pos
    rectDisplay: c.Rectangle,
    //TODO:

    pos: Types.Vector2Int,
    posDisplay: Types.Vector2Int,
    label: []const u8,
    data: ?*anyopaque = null,
    icon: ?*c.Texture2D = null,
    iconRect: ?*c.Rectangle = null,

    pub fn initValues(this: *Button, rect: c.Rectangle, label: []const u8, data: *anyopaque, icon: ?*c.Texture2D, iconRect: ?*c.Rectangle) void {
        this.rect = rect;
        this.rect.height = 16;
        this.rect.width = 16;
        if (label.len > 0) {
            this.label = label;
            this.rect.width = c.MeasureText(this.label.ptr, 5);
        } else {
            this.label = "\x00";
        }
        this.rectDisplay = rect;
        this.data = data;
        this.icon = icon;
        this.iconRect = iconRect;
    }

    pub fn Draw(this: @This()) !void {
        if (this.posDisplay.y >= 0 and this.posDisplay.y < Config.game_height) {
            var text_length = c.MeasureText(this.label.ptr, 5);
            if (text_length == 0) {
                text_length = 16;
            }
            var drawn = false;
            if (this.icon) |icon| {
                if (this.iconRect) |iconrect| {
                    drawn = true;
                    c.DrawTextureRec(icon.*, iconrect.*, this.rectDisplay, c.WHITE);
                } else {
                    c.DrawTexture(icon, @as(c_int, @intFromFloat(this.rectDisplay.x)), @as(c_int, @intFromFloat(this.rectDisplay.y)), c.WHITE);
                }
            }
            if (!drawn) {
                c.DrawRectangle(@intCast(this.pos.x), this.posDisplay.y, text_length, this.height, c.RED);
            }
            var buffer: [64]u8 = undefined;
            var formatted = try std.fmt.bufPrint(&buffer, "{s}", .{this.label});
            formatted = try std.fmt.bufPrint(&buffer, "{d}:{d}", .{ this.posDisplay.x, this.posDisplay.y });
            c.DrawText(formatted.ptr, this.pos.x, this.posDisplay.y, 5, c.YELLOW);
        }
    }

    pub fn Update(this: *Button, scroll: f32) ?*anyopaque {
        this.posDisplay.y = this.pos.y - @as(i32, @intFromFloat(scroll));
        if (c.IsMouseButtonPressed(c.MOUSE_BUTTON_LEFT)) {
            const mouse = c.GetMousePosition();
            const renderDestination = Utils.screenToRenderTextureCoords(mouse);
            const world = c.GetScreenToWorld2D(renderDestination, Window.camera);

            const collision = c.CheckCollisionPointRec(world, c.Rectangle{ .x = @floatFromInt(this.posDisplay.x), .y = @floatFromInt(this.posDisplay.y), .width = @floatFromInt(this.width), .height = @floatFromInt(this.height) });
            if (collision) {
                return this.data;
            }
        }
        return null;
    }
};
