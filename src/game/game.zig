const std = @import("std");
const World = @import("world.zig");
const Player = @import("../entities/player.zig");
const Assets = @import("../game/assets.zig");
const Config = @import("../common/config.zig");
const Screen = @import("../game/screen.zig");
const Enemy = @import("../entities/enemy.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const Game = struct {
    allocator: std.mem.Allocator,
    world: World.World,
    player: *Player.Player,
    assets: Assets.Assets,
    camera: c.Camera2D,
    screen: *Screen.Screen,
    enemy: *Enemy.Enemy,

    pub fn init(allocator: std.mem.Allocator) !*Game {
        const player = try Player.Player.init(allocator);
        const game = try allocator.create(Game);
        game.* = .{
            .allocator = allocator,
            .world = try World.World.init(),
            .player = player,
            .assets = Assets.Assets.init(),
            .camera = c.Camera2D{
                .offset = c.Vector2{ .x = @as(f32, @floatFromInt(Config.game_width / 2)), .y = @as(f32, @floatFromInt(Config.game_height / 2)) },
                .target = c.Vector2{ .x = @as(f32, @floatFromInt(player.x * Config.tile_width)), .y = @as(f32, @floatFromInt(player.y * Config.tile_height)) },
                .rotation = 0.0,
                //TODO: add zoom
                .zoom = 1.0,
            },
            .screen = try Screen.Screen.init(allocator),
            .enemy = try Enemy.Enemy.init(allocator),
        };
        return game;
    }

    pub fn deinit(this: *Game) void {
        this.player.deinit(this.allocator);
        this.world.deinit(this.allocator);
        this.assets.deinit(this.allocator);
        this.screen.deinit(this.allocator);
        this.allocator.destroy(this);
    }

    pub fn Update(this: @This()) void {
        this.screen.Update();
        this.player.Update();
    }

    pub fn Draw(this: *Game) !void {
        this.camera.target = c.Vector2{ .x = @as(f32, @floatFromInt(this.player.x * Config.tile_width)), .y = @as(f32, @floatFromInt(this.player.y * Config.tile_height)) };

        c.BeginTextureMode(this.screen.texture);
        c.BeginMode2D(this.camera);
        c.ClearBackground(c.BLACK);
        this.world.currentLevel.Draw();
        this.player.Draw(&this.assets);
        this.enemy.Draw(&this.assets);
        c.EndMode2D();
        c.EndTextureMode();

        c.BeginDrawing();
        c.DrawTexturePro(
            this.screen.texture.texture,
            c.Rectangle{ .x = 0, .y = 0, .width = @as(f32, Config.game_width), .height = @as(f32, -Config.game_height) },
            c.Rectangle{ .x = @as(f32, @floatFromInt(this.screen.offset_x)), .y = @as(f32, @floatFromInt(this.screen.offset_y)), .width = @as(f32, @floatFromInt(this.screen.scaled_width)), .height = @as(f32, @floatFromInt(this.screen.scaled_height)) },
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
};
