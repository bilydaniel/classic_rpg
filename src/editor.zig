const std = @import("std");
const Editor = @import("editor/editor.zig");
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

    const editor = try Editor.Editor.init(allocator);

    const running = true;
    while (!c.WindowShouldClose() and running) {
        editor.Update();

        editor.Draw(editor.window.screen);

        c.BeginDrawing();
        c.DrawTexturePro(
            game.window.screen.texture,
            c.Rectangle{ .x = 0, .y = 0, .width = @as(f32, Config.game_width), .height = @as(f32, -Config.game_height) },
            c.Rectangle{ .x = @as(f32, @floatFromInt(game.window.offsetx)), .y = @as(f32, @floatFromInt(game.window.offsety)), .width = @as(f32, @floatFromInt(game.window.scaledWidth)), .height = @as(f32, @floatFromInt(game.window.scaledHeight)) },
            c.Vector2{ .x = 0, .y = 0 },
            0.0,
            c.WHITE,
        );
        c.DrawFPS(0, 0);
        var buffer: [32]u8 = undefined;
        const num = c.GetFrameTime();
        const formatted = try std.fmt.bufPrint(&buffer, "{d}", .{num});
        c.DrawText(formatted.ptr, 0, 0, 20, c.WHITE);
        c.EndDrawing();
    }
}
