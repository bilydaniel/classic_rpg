const std = @import("std");
const Game = @import("game/game.zig");
const Config = @import("common/config.zig");
const Window = @import("game/window.zig");
const rl = @import("raylib");
const Profiler = @import("common/profiler.zig");

pub fn main() !void {
    rl.setConfigFlags(.{ .window_resizable = true });
    //c.SetConfigFlags(c.FLAG_FULLSCREEN_MODE);
    //c.ToggleFullscreen();

    rl.initWindow(Config.window_width, Config.window_height, "PuppetMasterRL");
    defer rl.closeWindow();

    // std.SegmentedList(comptime T: type, comptime prealloc_item_count: usize);
    // https://gemini.google.com/app/492731873f4e47c6
    // TODO: @memory figure out the lifetimes of evertything, do proper memory management
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    //TODO: @memory @check leaks
    defer _ = gpa.deinit();

    try Window.init();
    const game = try Game.Game.init(allocator);
    defer game.deinit();

    const running = true;

    Profiler.map = std.AutoHashMap(u64, u32).init(allocator);
    defer Profiler.map.deinit();

    Profiler.BeginProfile();

    while (!rl.windowShouldClose() and running) {
        const updateProfile = Profiler.TimeBlock("update", @src());
        try game.update();
        updateProfile.end();

        const drawProfile = Profiler.TimeBlock("draw", @src());
        try game.draw();
        drawProfile.end();
    }

    Profiler.EndProfile();
}
