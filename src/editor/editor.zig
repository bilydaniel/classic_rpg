const std = @import("std");
const World = @import("../game/world.zig");
const Player = @import("../entities/player.zig");
const Assets = @import("../game/assets.zig");
const Config = @import("../common/config.zig");
const Types = @import("../common/types.zig");
const Utils = @import("../common/utils.zig");
const Window = @import("../game/window.zig");
const Menu = @import("../ui/menu.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const Editor = struct {
    allocator: std.mem.Allocator,
    world: *World.World,
    camera: c.Camera2D,
    cameraManual: bool,
    cameraSpeed: f32,
    timeSinceTurn: f32,
    window: Window.Window,
    assetMenu: Menu.Menu,
    //TODO: rename into assetmetu, special menu thats gonna return the picked texture, use that to do stuff, make this into the game too? not sure if I want building in the game? -> probably yes
    assets: Assets.Assets,
    pickedAsset: ?*Assets.Node = null,
    //TODO: separate tiles and entities, open tile menu with different key

    pub fn init(allocator: std.mem.Allocator) !*Editor {
        var editor = try allocator.create(Editor);
        const assets = Assets.Assets.init(allocator);
        editor.assets = assets;
        try editor.assets.loadFromDir("assets");
        const assetMenu = try Menu.Menu.initAssetMenu(allocator, editor.assets);
        editor.* = .{
            .allocator = allocator,
            .world = try World.World.init(allocator),
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
            .assets = assets,
            .assetMenu = assetMenu,
        };
        return editor;
    }

    pub fn Update(this: *Editor) void {
        this.window.Update();
        const delta = c.GetFrameTime();
        this.timeSinceTurn += delta;
        //TODO: make a state machine for inputs

        if (!this.assetMenu.isOpen) {
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
        }

        if (c.IsKeyPressed(c.KEY_Q)) {
            this.assetMenu.isOpen = !this.assetMenu.isOpen;
        }

        if (c.IsMouseButtonPressed(c.MOUSE_BUTTON_RIGHT)) {
            this.pickedAsset = null;
        }

        //TODO: switch to a state machine??
        const picked_asset: ?*Assets.Node = @ptrCast(@alignCast(this.assetMenu.Update())); //TODO: this will return the picked asset to use for building
        if (picked_asset) |asset| {
            this.assetMenu.isOpen = false;
            this.pickedAsset = asset;
            std.debug.print("picked_asset: {}", .{asset});
        }

        if (this.pickedAsset) |asset| {
            if (c.IsMouseButtonPressed(c.MOUSE_BUTTON_LEFT)) {
                std.debug.print("asset: {}", .{asset});
            }
        }
    }

    pub fn DrawEditor(this: *Editor) void {
        if (this.pickedAsset) |asset| {
            const mouse = c.GetMousePosition();
            const renderDestination = Utils.screenToRenderTextureCoords(mouse, this.window);
            const world = c.GetScreenToWorld2D(renderDestination, this.camera);

            c.DrawTexture(asset.texture, @as(c_int, @intFromFloat(world.x)), @as(c_int, @intFromFloat(world.y)), c.WHITE);
        }
    }

    pub fn Draw(this: *Editor, screen: c.RenderTexture2D) !void {
        c.BeginTextureMode(screen);
        c.BeginMode2D(this.camera);
        c.ClearBackground(c.BLACK);
        this.world.Draw();
        this.DrawEditor();
        c.EndMode2D();
        c.BeginScissorMode(0, 0, Config.game_width, Config.game_height);
        try this.assetMenu.Draw();
        c.EndScissorMode();
        c.EndTextureMode();
    }
};
