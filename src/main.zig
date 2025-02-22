const std = @import("std");
const Game = @import("game/game.zig");
const Player = @import("entities/player.zig");
const Config = @import("common/config.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub fn main() !void {
    c.SetConfigFlags(c.FLAG_WINDOW_RESIZABLE);
    c.InitWindow(Config.window_width, Config.window_height, "RPG");
    defer c.CloseWindow();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const game = try Game.Game.init(allocator);
    defer game.deinit();

    c.SetTargetFPS(60);

    const running = true;
    while (!c.WindowShouldClose() and running) {
        game.Update();
        try game.Draw();
    }
}
