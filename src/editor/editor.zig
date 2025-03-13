const std = @import("std");
const World = @import("world.zig");
const Player = @import("../entities/player.zig");
const Assets = @import("../game/assets.zig");
const Config = @import("../common/config.zig");
const Types = @import("../common/types.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const Editor = struct {
    allocator: std.mem.Allocator,
    world: World.World,
    player: *Player.Player,
    assets: Assets.assets,
    camera: c.Camera2D,
    cameraManual: bool,
    cameraSpeed: f32,
    timeSinceTurn: f32,

    pub fn init(allocator: std.mem.Allocator) !*Editor {
        const player = try Player.Player.init(allocator);
        const editor = try allocator.create(Editor);
        editor.* = .{
            .allocator = allocator,
            .world = try World.World.init(),
            .player = player,
            .assets = Assets.assets.init(),
            .camera = c.Camera2D{
                .offset = c.Vector2{ .x = 0, .y = 0 },
                .target = c.Vector2{ .x = 0, .y = 0 },
                .rotation = 0.0,
                //TODO: add zoom
                .zoom = 1.0,
            },
            .cameraManual = false,
            .cameraSpeed = 128,
            .timeSinceTurn = 0,
        };
        return game;
    }

    pub fn Update(this: *Game) void {
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
            const world = c.GetScreenToWorld2D(destination, this.camera);
            //TODO: fix this. Divna funkctionalita mezi targetem a coordinacemi
            std.debug.print("x: {d}, y: {d}\n", .{ world.x, world.y });

            //this.player.destination = destination;
        }

        if (this.timeSinceTurn > 0.15) {
            this.player.Update();
        }
    }

    pub fn Draw(this: *Game, screen: c.RenderTexture2D) void {
        //this.camera.target = c.Vector2{ .x = @as(f32, @floatFromInt(this.player.x * Config.tile_width)), .y = @as(f32, @floatFromInt(this.player.y * Config.tile_height)) };

        c.BeginTextureMode(screen);
        c.BeginMode2D(this.camera);
        c.ClearBackground(c.BLACK);
        this.world.currentLevel.Draw();
        this.player.Draw(&this.assets);
        c.EndMode2D();
        c.EndTextureMode();
    }
};
