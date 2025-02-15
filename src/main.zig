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
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    //const allocator = std.testing.allocator;
    const list = std.ArrayList(u8).init(allocator);
    defer list.deinit();
    std.debug.print("{}", .{list});

    c.InitWindow(window_width, window_height, "RPG");
    defer c.CloseWindow();

    const gameInstance = try game.Game.init();

    const screen = c.LoadRenderTexture(game_width, game_height);
    defer c.UnloadRenderTexture(screen);

    const screen_1 = c.LoadRenderTexture(game_width, game_height);
    defer c.UnloadRenderTexture(screen_1);

    const screen_2 = c.LoadRenderTexture(game_width, game_height);
    defer c.UnloadRenderTexture(screen_2);

    c.SetTextureFilter(screen.texture, c.TEXTURE_FILTER_POINT); //TODO:try TEXTURE_FILTER_BILINEAR for blurry effect
    c.SetTextureFilter(screen_1.texture, c.TEXTURE_FILTER_POINT); //TODO:try TEXTURE_FILTER_BILINEAR for blurry effect
    c.SetTextureFilter(screen_2.texture, c.TEXTURE_FILTER_POINT); //TODO:try TEXTURE_FILTER_BILINEAR for blurry effect
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
            c.Rectangle{ .x = offset_x, .y = offset_y, .width = @as(f32, scaled_width), .height = @as(f32, scaled_height) },
            c.Vector2{ .x = 0, .y = 0 },
            0.0,
            c.WHITE,
        );
        c.EndDrawing();
    }
}
