const std = @import("std");
const World = @import("world.zig");
const Player = @import("../entities/player.zig");
const Assets = @import("../game/assets.zig");
const Config = @import("../common/config.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const Game = struct {
    allocator: std.mem.Allocator,
    world: World.World,
    player: *Player.Player,
    assets: Assets.assets,
    camera: c.Camera2D,

    pub fn init(allocator: std.mem.Allocator) !*Game {
        const player = try Player.Player.init(allocator);
        const game = try allocator.create(Game);
        game.* = .{
            .allocator = allocator,
            .world = try World.World.init(),
            .player = player,
            .assets = Assets.assets.init(),
            .camera = c.Camera2D{
                .offset = c.Vector2{ .x = @as(f32, @floatFromInt(Config.game_width / 2)), .y = @as(f32, @floatFromInt(Config.game_height / 2)) },
                .target = c.Vector2{ .x = @as(f32, @floatFromInt(player.x * Config.tile_width)), .y = @as(f32, @floatFromInt(player.y * Config.tile_height)) },
                .rotation = 0.0,
                //TODO: add zoom
                .zoom = 1.0,
            },
        };
        return game;
    }

    pub fn Update(this: @This()) void {
        this.player.Update();
    }

    pub fn Draw(this: *Game, screen: c.RenderTexture2D) void {
        this.camera.target = c.Vector2{ .x = @as(f32, @floatFromInt(this.player.x * Config.tile_width)), .y = @as(f32, @floatFromInt(this.player.y * Config.tile_height)) };

        c.BeginTextureMode(screen);
        c.BeginMode2D(this.camera);
        c.ClearBackground(c.BLACK);
        this.world.currentLevel.Draw();
        this.player.Draw(&this.assets);
        c.EndMode2D();
        c.EndTextureMode();
    }
};
