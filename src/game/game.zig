const std = @import("std");
const World = @import("world.zig");
const Systems = @import("Systems.zig");
const Gamestate = @import("gamestate.zig");
const Entity = @import("entity.zig");
const Assets = @import("../game/assets.zig");
const Tileset = @import("../game/tileset.zig");
const Window = @import("../game/window.zig");
const Config = @import("../common/config.zig");
const Types = @import("../common/types.zig");
const Utils = @import("../common/utils.zig");
const Pathfinder = @import("../game/pathfinder.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const Game = struct {
    allocator: std.mem.Allocator,
    gameState: *Gamestate.gameState,
    world: *World.World,
    player: *Entity.Entity,
    assets: Assets.Assets,
    camera: *c.Camera2D,
    cameraManual: bool,
    cameraSpeed: f32,
    timeSinceTurn: f32,
    pathfinder: *Pathfinder.Pathfinder,

    pub fn init(allocator: std.mem.Allocator) !*Game {
        const gamestate = try Gamestate.gameState.init(allocator);
        const playerData = try Entity.PlayerData.init(allocator);
        const player = try Entity.Entity.init(
            allocator,
            Types.Vector2Int{ .x = 3, .y = 2 },
            1,
            Entity.EntityData{
                .player = playerData,
            },
            "@",
        );
        const game = try allocator.create(Game);
        const camera = try allocator.create(c.Camera2D);
        var tileset = Tileset.Tileset.init(allocator);
        try tileset.loadTileset(Config.tileset_path);
        const pathfinder = try Pathfinder.Pathfinder.init(allocator);
        //TODO: second camera is in window.zig
        // fix it, have just one, cleanup
        camera.* = .{
            .offset = c.Vector2{ .x = 0, .y = 0 },
            .target = c.Vector2{ .x = 0, .y = 0 },
            .rotation = 0.0,
            .zoom = Config.camera_zoom,
        };

        game.* = .{
            .allocator = allocator,
            .gameState = gamestate,
            .world = try World.World.init(allocator, tileset.source),
            .player = player,
            .assets = Assets.Assets.init(allocator),
            .camera = camera,
            .cameraManual = false,
            .cameraSpeed = 128,
            .timeSinceTurn = 0,
            .pathfinder = pathfinder,
        };
        Systems.calculateFOV(&game.world.currentLevel.grid, player.pos, 8);
        return game;
    }

    pub fn Update(this: *Game) !void {
        //TODO: decide on a game loop, look into the book
        Window.UpdateWindow();
        //TODO: when i change the window size, clicking is not precise anymore
        const delta = c.GetFrameTime();
        this.timeSinceTurn += delta;
        //TODO: make a state machine for inputs

        //TODO: change to look mode
        if (c.IsKeyDown(c.KEY_W)) {
            this.camera.target.y -= this.cameraSpeed * delta;
        }
        if (c.IsKeyDown(c.KEY_S)) {
            this.camera.target.y += this.cameraSpeed * delta;
        }
        if (c.IsKeyDown(c.KEY_A)) {
            this.camera.target.x -= this.cameraSpeed * delta;
        }
        if (c.IsKeyDown(c.KEY_D)) {
            this.camera.target.x += this.cameraSpeed * delta;
        }
        if (c.IsKeyDown(c.KEY_DELETE)) {
            if (this.camera.zoom < 3.0) {
                this.camera.zoom += 0.25;
            }
        }
        if (c.IsKeyDown(c.KEY_INSERT)) {
            if (this.camera.zoom > 1.0) {
                this.camera.zoom -= 0.25;
            }
        }

        try Systems.updatePlayer(this.gameState, this.player, delta, this.world, this.camera, this.pathfinder, &this.world.entities);
        this.camera.target.x = @floor(@as(f32, @floatFromInt(this.player.pos.x * Config.tile_width)) - Config.game_width_half / this.camera.zoom);
        this.camera.target.y = @floor(@as(f32, @floatFromInt(this.player.pos.y * Config.tile_height)) - Config.game_height_half / this.camera.zoom);
        this.world.Update();
    }

    pub fn Draw(this: *Game) void {
        //this.camera.target = c.Vector2{ .x = @as(f32, @floatFromInt(this.player.x * Config.tile_width)), .y = @as(f32, @floatFromInt(this.player.y * Config.tile_height)) };

        //        c.BeginTextureMode(Window.screen);
        //        c.BeginMode2D(this.camera.*);
        //        c.ClearBackground(c.BLACK);
        //        this.world.Draw();
        //        this.player.Draw(&this.assets);
        //        c.EndMode2D();
        //        c.EndTextureMode();
        c.BeginDrawing();
        c.ClearBackground(c.BLACK);
        c.DrawFPS(0, 0);
        c.BeginMode2D(this.camera.*);
        this.world.Draw();
        this.player.Draw();
        c.EndMode2D();
        c.EndDrawing();
    }
};
