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

    const running = true;
    while (!c.WindowShouldClose() and running) {
        game.Update();

        scale = @min(
            @as(f32, @floatFromInt(Config.window_width)) / @as(f32, Config.game_width),
            @as(f32, @floatFromInt(Config.window_height)) / @as(f32, Config.game_height),
        );

        scaled_width = @as(i32, @intFromFloat(@as(f32, Config.game_width) * scale));
        scaled_height = @as(i32, @intFromFloat(@as(f32, Config.game_height) * scale));
        offset_x = @divFloor(Config.window_width - scaled_width, 2);
        offset_y = @divFloor(Config.window_height - scaled_height, 2);
        std.debug.print("offset_x: {d}, offset_y : {d}\n", .{ offset_x, offset_y });

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
        c.DrawText(formatted.ptr, 0, 0, 20, c.WHITE);
        c.EndDrawing();
    }
}
