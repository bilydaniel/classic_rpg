const std = @import("std");
const Game = @import("game/game.zig");
const Config = @import("common/config.zig");
const Window = @import("game/window.zig");
const rl = @import("raylib");
const Profiler = @import("common/profiler.zig");
const Allocators = @import("common/allocators.zig");

pub fn main() !void {
    rl.setConfigFlags(.{ .window_resizable = true });
    //c.SetConfigFlags(c.FLAG_FULLSCREEN_MODE);
    //c.ToggleFullscreen();

    rl.initWindow(Config.window_width, Config.window_height, "PuppetMasterRL");
    defer rl.closeWindow();

    // std.SegmentedList(comptime T: type, comptime prealloc_item_count: usize);
    // https://gemini.google.com/app/492731873f4e47c6
    // TODO: @memory figure out the lifetimes of evertything, do proper memory management
    Allocators.init();
    defer Allocators.deinit();

    try Window.init();

    const game = try Game.Game.init(Allocators.persistent);
    defer game.deinit();

    const running = true;

    Profiler.map = std.AutoHashMap(u64, u32).init(Allocators.persistent);
    defer Profiler.map.deinit();

    Profiler.BeginProfile();

    while (!rl.windowShouldClose() and running) {
        try game.update();

        try game.draw();
    }

    Profiler.EndProfile();
}
