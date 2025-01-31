const std = @import("std");
//const ray = @import("raylib");
const c = @cImport({
    @cInclude("raylib.h");
});

const game_width: i32 = 640;
const game_height: i32 = 360;
//TODO: make resizable
const window_width: i32 = game_width * 2;
const window_height: i32 = game_height * 2;

const Player = struct {
    x: f32,
    y: f32,
    speed: f32,

    pub fn init() Player {
        return Player{
            .x = 100,
            .y = 100,
            .speed = 3,
        };
    }
};

const Level = struct {
    grid: [][]Tile,
    width: usize,
    height: usize,
};

const Tile = struct {
    x: usize,
    y: usize,
};

pub fn main() !void {
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

    while (!c.WindowShouldClose()) {
        //TODO: make a proper updating/rendering system, I think I had a thread on chatgpt or cluade
        if (c.IsKeyDown(c.KEY_W)) {
            player.y -= player.speed;
        }
        if (c.IsKeyDown(c.KEY_S)) {
            player.y += player.speed;
        }
        if (c.IsKeyDown(c.KEY_A)) {
            player.x -= player.speed;
        }
        if (c.IsKeyDown(c.KEY_D)) {
            player.x += player.speed;
        }

        c.BeginTextureMode(screen);
        c.ClearBackground(c.BLACK);
        //TODO: draw player
        c.DrawRectangle(
            @as(c_int, @intFromFloat(player.x)),
            @as(c_int, @intFromFloat(player.y)),
            16,
            16,
            c.YELLOW,
        );
        c.EndTextureMode();

        c.BeginDrawing();
        c.ClearBackground(c.BLACK);

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
