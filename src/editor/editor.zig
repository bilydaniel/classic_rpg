const std = @import("std");
const World = @import("../game/world.zig");
const Player = @import("../entities/player.zig");
const Assets = @import("../game/assets.zig");
const Config = @import("../common/config.zig");
const Types = @import("../common/types.zig");
const Utils = @import("../common/utils.zig");
const Window = @import("../game/window.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const Editor = struct {
    allocator: std.mem.Allocator,
    world: World.World,
    assets: Assets.assets,
    camera: c.Camera2D,
    cameraManual: bool,
    cameraSpeed: f32,
    timeSinceTurn: f32,
    window: Window.Window,

    pub fn init(allocator: std.mem.Allocator) !*Editor {
        const editor = try allocator.create(Editor);
        editor.* = .{
            .allocator = allocator,
            .world = try World.World.init(),
            .assets = Assets.assets.init(),
            .camera = c.Camera2D{
                .offset = c.Vector2{ .x = 0, .y = 0 },
                .target = c.Vector2{ .x = 0, .y = 0 },
                .rotation = 0.0,
                .zoom = 1.0,
            },
            .cameraManual = false,
            .cameraSpeed = 128,
            .timeSinceTurn = 0,
            .window = Window.Window.init(),
        };
        return editor;
    }

    pub fn Update(this: *Editor) void {
        this.window.Update();
        const delta = c.GetFrameTime();
        this.timeSinceTurn += delta;
        //TODO: make a state machine for inputs

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
            const destination = c.GetMousePosition();
            const renderDestination = Utils.screenToRenderTextureCoords(destination, this.window);
            const world = c.GetScreenToWorld2D(renderDestination, this.camera);
            std.debug.print("WORLD: x: {d}, y: {d}\n", .{ world.x, world.y });
        }
    }

    pub fn Draw(this: *Editor, screen: c.RenderTexture2D) void {
        c.BeginTextureMode(screen);
        c.BeginMode2D(this.camera);
        c.ClearBackground(c.BLACK);
        this.world.currentLevel.Draw();
        c.EndMode2D();
        c.EndTextureMode();
    }
};
