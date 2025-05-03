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
    rect: c.Rectangle,
    rectDisplay: c.Rectangle,
    label: []const u8,
    data: ?*anyopaque = null,
    callback: ?*const fn (input: ?*anyopaque) ?*anyopaque,
    icon: ?*c.Texture2D = null,
    iconRect: ?c.Rectangle = null,

    pub fn initValues(this: *Button, rect: c.Rectangle, label: []const u8, data: *anyopaque, icon: ?*c.Texture2D, iconRect: ?c.Rectangle) void {
        this.rect = rect;
        this.rect.height = 16;
        this.rect.width = 16;
        if (label.len > 0) {
            this.label = label;
            this.rect.width = @floatFromInt(c.MeasureText(this.label.ptr, 5));
        } else {
            this.label = "\x00";
        }
        this.rectDisplay = this.rect;
        this.data = data;
        this.icon = icon;
        this.iconRect = iconRect;
        this.callback = defaultCallback;
    }

    pub fn Draw(this: @This()) !void {
        if (this.rectDisplay.y >= 0 and this.rectDisplay.y < Config.game_height) {
            var text_length = c.MeasureText(this.label.ptr, 5);
            if (text_length == 0) {
                text_length = 16;
            }
            var drawn = false;
            if (this.icon) |icon| {
                if (this.iconRect) |iconrect| {
                    drawn = true;
                    c.DrawTextureRec(icon.*, iconrect, c.Vector2{ .x = this.rectDisplay.x, .y = this.rectDisplay.y }, c.WHITE);
                } else {
                    c.DrawTexture(icon.*, @as(c_int, @intFromFloat(this.rectDisplay.x)), @as(c_int, @intFromFloat(this.rectDisplay.y)), c.WHITE);
                }
            }
            if (!drawn) {
                c.DrawRectangle(@intFromFloat(this.rectDisplay.x), @intFromFloat(this.rectDisplay.y), text_length, @intFromFloat(this.rect.height), c.RED);
            }
            var buffer: [64]u8 = undefined;
            var formatted = try std.fmt.bufPrint(&buffer, "{s}", .{this.label});
            formatted = try std.fmt.bufPrint(&buffer, "{d}:{d}\x00", .{ this.rectDisplay.x, this.rectDisplay.y });
            //c.DrawText(formatted.ptr, @intFromFloat(this.rectDisplay.x), @intFromFloat(this.rectDisplay.y), 5, c.YELLOW);
        }
    }

    pub fn Update(this: *Button, scroll: f32) ?*anyopaque {
        //TODO: promyslet button update, muzu udelat pres callback, mel jsem problem s vracenim hodnoty, muzu vratit pres input pointeru, doslo mi to az ted
        //nejlepsi asi bude pridat callback a pouzit ho kdyz nebude prazdny, jinak nechat jak je
        this.rectDisplay.y = this.rect.y - scroll;
        if (c.IsMouseButtonPressed(c.MOUSE_BUTTON_LEFT)) {
            const mouse = c.GetMousePosition();
            const renderDestination = Utils.screenToRenderTextureCoords(mouse);
            const world = c.GetScreenToWorld2D(renderDestination, Window.camera);

            const collision = c.CheckCollisionPointRec(world, this.rectDisplay);
            if (collision) {
                if (this.callback) |callback| {
                    return callback(this.data);
                }
            }
        }
        return null;
    }
};

pub fn defaultCallback(data: ?*anyopaque) ?*anyopaque {
    return data;
}
