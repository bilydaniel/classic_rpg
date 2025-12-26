const std = @import("std");
const Game = @import("game/game.zig");
const Config = @import("common/config.zig");
const Window = @import("game/window.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub fn main() !void {
    //TODO: !!! do an overall refactor !!!
    c.SetConfigFlags(c.FLAG_WINDOW_RESIZABLE);
    //c.SetConfigFlags(c.FLAG_FULLSCREEN_MODE);
    c.InitWindow(Config.window_width, Config.window_height, "PuppetMasterRL");
    defer c.CloseWindow();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    Window.init();
    const game = try Game.Game.init(allocator);

    const running = true;
    while (!c.WindowShouldClose() and running) {
        try game.Update();
        game.Draw();
    }
}
