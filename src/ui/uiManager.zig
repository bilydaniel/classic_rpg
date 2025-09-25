const std = @import("std");
const Game = @import("../game/game.zig");
const Window = @import("../game/window.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const UiManager = struct {
    allocator: std.mem.Allocator,
    ctx: *Game.Context,

    pub fn init(allocator: std.mem.Allocator, ctx: *Game.Context) !*UiManager {
        const uimanager = try allocator.create(UiManager);
        uimanager.* = .{
            .allocator = allocator,
            .ctx = ctx,
        };
        return uimanager;
    }
    pub fn update(this: *UiManager, ctx: *Game.Context) void {
        _ = this;
        _ = ctx;
    }
    pub fn draw(this: *UiManager) void {
        _ = this;
        std.debug.print("width: {}\n", .{Window.windowWidth});
        std.debug.print("height: {}\n", .{Window.windowHeight});
        std.debug.print("********************\n", .{});
        const rectHeight = Window.windowHeight;
        const rectWidth = @divFloor(Window.windowWidth, 10);

        c.DrawRectangle(0, 0, rectWidth, rectHeight, c.ORANGE);
    }
};
