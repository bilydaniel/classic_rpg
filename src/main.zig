const std = @import("std");
const game = @import("game/game.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

const game_width: i32 = 640;
const game_height: i32 = 360;
//TODO: make resizable
const window_width: i32 = game_width * 2;
const window_height: i32 = game_height * 2;

const tile_width: i32 = 16;
const tile_height: i32 = 24;

const Player = struct {
    x: i32,
    y: i32,
    speed: i32,

    pub fn init() Player {
        return Player{
            .x = 2,
            .y = 3,
            .speed = 1, //TODO: speed is going to be relative to te player, player always 1
        };
    }
};

const Coordinates = struct {
    x: i32,
    y: i32,
};

const Tile = struct {
    x: usize,
    y: usize,
    occupied: bool,
    items: []Item,
};

const Item = union(enum) {};

pub fn main() !void {
    const gameInstance = game.Game.init();

    c.InitWindow(window_width, window_height, "RPG");
    defer c.CloseWindow();

    const screen = c.LoadRenderTexture(game_width, game_height);
    defer c.UnloadRenderTexture(screen);

    c.SetTextureFilter(screen.texture, c.TEXTURE_FILTER_POINT);
    c.SetTargetFPS(60);

    var player = Player.init();

    const scale = @min(
        @as(f32, window_width) / @as(f32, game_width),
        @as(f32, window_height) / @as(f32, game_height),
    );

    const scaled_width = @as(i32, @intFromFloat(@as(f32, game_width) * scale));
    const scaled_height = @as(i32, @intFromFloat(@as(f32, game_height) * scale));
    const offset_x = (window_width - scaled_width) / 2;
    const offset_y = (window_height - scaled_height) / 2;

    const tile_texture = c.LoadTexture("assets/base_tile.png");
    defer c.UnloadTexture(tile_texture);
    const player_texture = c.LoadTexture("assets/random_character.png");
    defer c.UnloadTexture(player_texture);

    var timer = try std.time.Timer.start();
    timer.reset();

    while (!c.WindowShouldClose()) {
        //TODO: make a proper updating/rendering system, I think I had a thread on chatgpt or cluade

        //TODO: make a context dependent input system, ideally with a queue
        if (timer.read() > 150_000_000) {
            if (c.IsKeyDown(c.KEY_W)) {
                player.y -= player.speed;
                timer.reset();
            }
            if (c.IsKeyDown(c.KEY_S)) {
                player.y += player.speed;
                timer.reset();
            }
            if (c.IsKeyDown(c.KEY_A)) {
                player.x -= player.speed;
                timer.reset();
            }
            if (c.IsKeyDown(c.KEY_D)) {
                player.x += player.speed;
                timer.reset();
            }
        }

        c.BeginTextureMode(screen);
        //TODO: DRAW LEVEL

        gameInstance.world.currentLevel.Draw();

        c.ClearBackground(c.BLACK);

        c.DrawRectangle(
            @as(c_int, @intCast(player.x * tile_width)),
            @as(c_int, @intCast(player.y * tile_height)),
            16,
            24,
            c.YELLOW,
        );

        c.DrawTexture(player_texture, @as(c_int, @intCast(player.x * tile_width)), @as(c_int, @intCast(player.y * tile_height)), c.WHITE);

        c.EndTextureMode();

        c.BeginDrawing();
        c.ClearBackground(c.BLACK);

        //const scaled_player_width = 16;
        //const scaled_player_height = 24;
        //c.DrawTexturePro(player_texture, c.Rectangle{ .x = 0, .y = 0, .width = @as(f32, @floatFromInt(player_texture.width)), .height = @as(f32, @floatFromInt(player_texture.height)) }, c.Rectangle{ .x = @as(f32, @floatFromInt(player.x * tile_width)), .y = @as(f32, @floatFromInt(player.y * tile_height)), .width = @as(f32, scaled_player_width), .height = @as(f32, scaled_player_height) }, c.Vector2{ .x = 0, .y = 0 }, 0.0, c.WHITE);

        c.DrawTexturePro(
            screen.texture,
            c.Rectangle{ .x = 0, .y = 0, .width = @as(f32, game_width), .height = @as(f32, -game_height) },
            c.Rectangle{ .x = offset_x, .y = offset_y, .width = @as(f32, scaled_width), .height = @as(f32, scaled_height) },
            c.Vector2{ .x = 0, .y = 0 },
            0.0,
            c.WHITE,
        );

        c.EndDrawing();
    }
}
