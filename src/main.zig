const std = @import("std");
const Game = @import("game/game.zig");
const Config = @import("common/config.zig");
const Window = @import("game/window.zig");
const rl = @import("raylib");

pub fn main() !void {
    rl.setConfigFlags(.{ .window_resizable = true });
    //c.SetConfigFlags(c.FLAG_FULLSCREEN_MODE);
    //c.ToggleFullscreen();

    rl.initWindow(Config.window_width, Config.window_height, "PuppetMasterRL");
    defer rl.closeWindow();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    //TODO: @check leaks
    //defer _ = gpa.deinit();

    Window.init();
    const game = try Game.Game.init(allocator);

    const running = true;
    while (!rl.WindowShouldClose() and running) {
        try game.update();
        try game.draw();
    }
}
