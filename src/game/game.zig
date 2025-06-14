const std = @import("std");
const World = @import("world.zig");
const Player = @import("../entities/player.zig");
const Assets = @import("../game/assets.zig");
const Tileset = @import("../game/tileset.zig");
const Window = @import("../game/window.zig");
const Config = @import("../common/config.zig");
const Types = @import("../common/types.zig");
const Utils = @import("../common/utils.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const Game = struct {
    allocator: std.mem.Allocator,
    world: *World.World,
    player: *Player.Player,
    assets: Assets.Assets,
    camera: *c.Camera2D,
    cameraManual: bool,
    cameraSpeed: f32,
    timeSinceTurn: f32,

    pub fn init(allocator: std.mem.Allocator) !*Game {
        const player = try Player.Player.init(allocator);
        const game = try allocator.create(Game);
        const camera = try allocator.create(c.Camera2D);
        var tileset = Tileset.Tileset.init(allocator);
        try tileset.loadTileset(Config.tileset_path);
        camera.* = .{
            .offset = c.Vector2{ .x = 0, .y = 0 },
            .target = c.Vector2{ .x = 0, .y = 0 },
            .rotation = 0.0,
            .zoom = 1.0,
        };

        game.* = .{
            .allocator = allocator,
            .world = try World.World.init(allocator, tileset.source),
            .player = player,
            .assets = Assets.Assets.init(allocator),
            .camera = camera,
            .cameraManual = false,
            .cameraSpeed = 128,
            .timeSinceTurn = 0,
        };
        return game;
    }

    pub fn Update(this: *Game) void {
        Window.UpdateWindow();
        const delta = c.GetFrameTime();
        this.timeSinceTurn += delta;
        //TODO: make a state machine for inputs
        //this.player.Update();

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

        if (c.IsMouseButtonPressed(c.MOUSE_BUTTON_RIGHT)) {
            //var destination: Types.Vector2Int = undefined;
            //destination.x = c.GetMouseX(); //@divFloor(c.GetMouseX(), 16);
            //destination.y = c.GetMouseY(); //@divFloor(c.GetMouseY(), 24);

            const destination = c.GetMousePosition();
            const renderDestination = Utils.screenToRenderTextureCoords(destination);
            const world = c.GetScreenToWorld2D(renderDestination, this.camera.*);
            std.debug.print("WORLD: x: {d}, y: {d}\n", .{ world.x, world.y });

            this.player.destination = Utils.pixelToTile(world);
        }

        if (this.timeSinceTurn > 0.25) {
            this.player.Update();
            this.timeSinceTurn = 0;
        }

        this.world.Update();
    }

    pub fn Draw(this: *Game) void {
        //this.camera.target = c.Vector2{ .x = @as(f32, @floatFromInt(this.player.x * Config.tile_width)), .y = @as(f32, @floatFromInt(this.player.y * Config.tile_height)) };

        c.BeginTextureMode(Window.screen);
        c.BeginMode2D(this.camera.*);
        c.ClearBackground(c.BLACK);
        this.world.Draw();
        this.player.Draw(&this.assets);
        c.EndMode2D();
        c.EndTextureMode();
    }
};
