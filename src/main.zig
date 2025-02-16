const std = @import("std");
const Game = @import("game/game.zig");
const Player = @import("entities/player.zig");
const Config = @import("common/config.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub fn main() !void {
    //var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    //const allocator = gpa.allocator();

    c.SetConfigFlags(c.FLAG_WINDOW_RESIZABLE);
    c.InitWindow(Config.window_width, Config.window_height, "RPG");
    defer c.CloseWindow();

    const gameInstance = try Game.Game.init();

    const screen = c.LoadRenderTexture(Config.game_width, Config.game_height);
    defer c.UnloadRenderTexture(screen);

    const screen_1 = c.LoadRenderTexture(game_width, game_height);
    defer c.UnloadRenderTexture(screen_1);

    const screen_2 = c.LoadRenderTexture(game_width, game_height);
    defer c.UnloadRenderTexture(screen_2);

    c.SetTextureFilter(screen.texture, c.TEXTURE_FILTER_POINT); //TODO:try TEXTURE_FILTER_BILINEAR for blurry effect
    c.SetTextureFilter(screen_1.texture, c.TEXTURE_FILTER_POINT); //TODO:try TEXTURE_FILTER_BILINEAR for blurry effect
    c.SetTextureFilter(screen_2.texture, c.TEXTURE_FILTER_POINT); //TODO:try TEXTURE_FILTER_BILINEAR for blurry effect
    c.SetTargetFPS(60);

    var player = Player.Player.init();

    const tile_texture = c.LoadTexture("assets/base_tile.png");
    defer c.UnloadTexture(tile_texture);

    const player_texture = c.LoadTexture("assets/random_character.png");
    defer c.UnloadTexture(player_texture);

    var scale = @min(
        @as(f32, @floatFromInt(window_width)) / @as(f32, game_width),
        @as(f32, @floatFromInt(window_height)) / @as(f32, game_height),
    );

    var scaled_width = @as(i32, @intFromFloat(@as(f32, game_width) * scale));
    var scaled_height = @as(i32, @intFromFloat(@as(f32, game_height) * scale));
    var offset_x = @divFloor(window_width - scaled_width, 2);
    var offset_y = @divFloor(window_height - scaled_height, 2);

    var timer = try std.time.Timer.start();
    timer.reset();
    var timeSinceInput: f32 = 0;

    const running = true;
    while (!c.WindowShouldClose() and running) {
        timeSinceInput += c.GetFrameTime();
        window_width = c.GetScreenWidth();
        window_height = c.GetScreenHeight();
        scale = @min(
            @as(f32, @floatFromInt(window_width)) / @as(f32, game_width),
            @as(f32, @floatFromInt(window_height)) / @as(f32, game_height),
        );

        scaled_width = @as(i32, @intFromFloat(@as(f32, game_width) * scale));
        scaled_height = @as(i32, @intFromFloat(@as(f32, game_height) * scale));
        offset_x = @divFloor(window_width - scaled_width, 2);
        offset_y = @divFloor(window_height - scaled_height, 2);

        //TODO: make a proper updating/rendering system, I think I had a thread on chatgpt or cluade

        //TODO: make a context dependent input system, ideally with a queue
        //TODO: maybe use getframetime here too??
        if (timeSinceInput > 0.15) {
            if (c.IsKeyDown(c.KEY_S)) {
                //TODO: wait
                timer.reset();
                timeSinceInput = 0;
            }
            if (c.IsKeyDown(c.KEY_W)) {
                player.y -= player.speed;
                timer.reset();
                timeSinceInput = 0;
            }
            if (c.IsKeyDown(c.KEY_X)) {
                player.y += player.speed;
                timer.reset();
                timeSinceInput = 0;
            }
            if (c.IsKeyDown(c.KEY_A)) {
                player.x -= player.speed;
                timer.reset();
                timeSinceInput = 0;
            }
            if (c.IsKeyDown(c.KEY_D)) {
                player.x += player.speed;
                timer.reset();
                timeSinceInput = 0;
            }
            if (c.IsKeyDown(c.KEY_Q)) {
                player.y -= player.speed;
                player.x -= player.speed;
                timer.reset();
                timeSinceInput = 0;
            }
            if (c.IsKeyDown(c.KEY_E)) {
                player.y -= player.speed;
                player.x += player.speed;
                timer.reset();
                timeSinceInput = 0;
            }
            if (c.IsKeyDown(c.KEY_Z)) {
                player.y += player.speed;
                player.x -= player.speed;
                timer.reset();
                timeSinceInput = 0;
            }
            if (c.IsKeyDown(c.KEY_C)) {
                player.x += player.speed;
                player.y += player.speed;
                timer.reset();
                timeSinceInput = 0;
            }
        }

        //        c.ClearBackground(c.BLACK);
        gameInstance.world.currentLevel.Draw(screen_2);

        c.BeginTextureMode(screen_1);
        c.ClearBackground(c.BLANK);
        c.DrawTexture(player_texture, @as(c_int, @intCast(player.x * tile_width)), @as(c_int, @intCast(player.y * tile_height)), c.WHITE);
        c.EndTextureMode();

        c.BeginTextureMode(screen);
        c.DrawTexture(screen_2.texture, 0, 0, c.WHITE);
        c.DrawTexture(screen_1.texture, 0, 0, c.WHITE);
        c.EndTextureMode();

        c.BeginDrawing();
        c.DrawTexturePro(
            screen.texture,
            c.Rectangle{ .x = 0, .y = 0, .width = @as(f32, game_width), .height = @as(f32, game_height) },
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
