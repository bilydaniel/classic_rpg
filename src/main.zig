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

    // std.SegmentedList(comptime T: type, comptime prealloc_item_count: usize);
    // https://gemini.google.com/app/492731873f4e47c6
    // TODO: figure out the lifetimes of evertything, do proper memory management
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    //TODO: @check leaks
    //defer _ = gpa.deinit();

    Window.init();
    const game = try Game.Game.init(allocator);

    const running = true;
    while (!rl.windowShouldClose() and running) {
        try game.update();
        try game.draw();
    }
}
