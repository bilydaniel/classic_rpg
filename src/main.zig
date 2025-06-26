const std = @import("std");
const Game = @import("game/game.zig");
const Player = @import("entities/player.zig");
const Config = @import("common/config.zig");
const Window = @import("game/window.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub fn main() !void {
    c.SetConfigFlags(c.FLAG_WINDOW_RESIZABLE);
    c.InitWindow(Config.window_width, Config.window_height, "RPG");
    defer c.CloseWindow();

    c.SetTextureFilter(Window.screen.texture, c.TEXTURE_FILTER_POINT);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    Window.init();
    const game = try Game.Game.init(allocator);

    const running = true;
    while (!c.WindowShouldClose() and running) {
        game.Update();

        game.Draw();
        //TODO: https://claude.ai/chat/91026e1b-d185-4b62-b01e-cd0d430a697f

        //        c.BeginDrawing();
        //        c.DrawTexturePro(
        //            Window.screen.texture,
        //            c.Rectangle{ .x = 0, .y = 0, .width = @as(f32, Config.game_width), .height = @as(f32, -Config.game_height) },
        //            c.Rectangle{ .x = @as(f32, @floatFromInt(Window.offsetx)), .y = @as(f32, @floatFromInt(Window.offsety)), .width = @as(f32, @floatFromInt(Window.scaledWidth)), .height = @as(f32, @floatFromInt(Window.scaledHeight)) },
        //            c.Vector2{ .x = 0, .y = 0 },
        //            0.0,
        //            c.WHITE,
        //        );
        //        c.EndDrawing();
    }
}
