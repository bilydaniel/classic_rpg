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

    const screen = c.LoadRenderTexture(Config.game_width, Config.game_height);
    defer c.UnloadRenderTexture(screen);

    c.SetTextureFilter(screen.texture, c.TEXTURE_FILTER_POINT); //TODO:try TEXTURE_FILTER_BILINEAR for blurry effect
    c.SetTargetFPS(60);

    const tile_texture = c.LoadTexture("assets/base_tile.png");
    defer c.UnloadTexture(tile_texture);

    var scale = @min(
        @as(f32, @floatFromInt(Config.window_width)) / @as(f32, Config.game_width),
        @as(f32, @floatFromInt(Config.window_height)) / @as(f32, Config.game_height),
    );

    var scaled_width = @as(i32, @intFromFloat(@as(f32, Config.game_width) * scale));
    var scaled_height = @as(i32, @intFromFloat(@as(f32, Config.game_height) * scale));
    var offset_x = @divFloor(Config.window_width - scaled_width, 2);
    var offset_y = @divFloor(Config.window_height - scaled_height, 2);

    const running = true;
    while (!c.WindowShouldClose() and running) {
        game.Update();

        Config.window_width = c.GetScreenWidth();
        Config.window_height = c.GetScreenHeight();

        scale = @min(
            @as(f32, @floatFromInt(Config.window_width)) / @as(f32, Config.game_width),
            @as(f32, @floatFromInt(Config.window_height)) / @as(f32, Config.game_height),
        );

        scaled_width = @as(i32, @intFromFloat(@as(f32, Config.game_width) * scale));
        scaled_height = @as(i32, @intFromFloat(@as(f32, Config.game_height) * scale));
        offset_x = @divFloor(Config.window_width - scaled_width, 2);
        offset_y = @divFloor(Config.window_height - scaled_height, 2);

        game.Draw(screen);

        c.BeginDrawing();
        c.DrawTexturePro(
            screen.texture,
            c.Rectangle{ .x = 0, .y = 0, .width = @as(f32, Config.game_width), .height = @as(f32, -Config.game_height) },
            c.Rectangle{ .x = @as(f32, @floatFromInt(offset_x)), .y = @as(f32, @floatFromInt(offset_y)), .width = @as(f32, @floatFromInt(scaled_width)), .height = @as(f32, @floatFromInt(scaled_height)) },
            c.Vector2{ .x = 0, .y = 0 },
            0.0,
            c.WHITE,
        );
        c.DrawFPS(0, 0);
        var buffer: [32]u8 = undefined;
        const num = c.GetFrameTime();
        const formatted = try std.fmt.bufPrint(&buffer, "{d}", .{num});
        c.DrawText(formatted.ptr, 100, 100, 20, c.WHITE);
        c.EndDrawing();
    }
}
