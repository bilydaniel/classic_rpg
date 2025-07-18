const std = @import("std");
const World = @import("../game/world.zig");
const Assets = @import("../game/assets.zig");
const Tileset = @import("../game/tileset.zig");
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
    cameraManual: bool,
    cameraSpeed: f32,
    deltaTime: f32,
    assetMenu: Menu.Menu,
    //TODO: rename into assetmetu, special menu thats gonna return the picked texture, use that to do stuff, make this into the game too? not sure if I want building in the game? -> probably yes
    assets: Assets.Assets,
    pickedAsset: ?*Assets.Node = null,
    pickedTile: ?*Tileset.TileNode = null,
    //TODO: separate tiles and entities, open tile menu with different key
    tilesetMenu: Menu.Menu,
    tileset: Tileset.Tileset,

    pub fn init(allocator: std.mem.Allocator) !*Editor {
        var editor = try allocator.create(Editor);
        const assets = Assets.Assets.init(allocator);
        var tileset = Tileset.Tileset.init(allocator);
        editor.assets = assets;
        try editor.assets.loadFromDir("assets");
        try tileset.loadTileset(Config.tileset_path);
        //std.debug.print("loaded_tileset: {}", .{editor.tileset.source});
        const assetMenu = try Menu.Menu.initAssetMenu(allocator, editor.assets);
        const tilesetMenu = try Menu.Menu.initTilesetMenu(allocator, tileset);
        editor.* = .{
            .allocator = allocator,
            .world = try World.World.init(allocator, tileset.source),
            .cameraManual = false,
            .cameraSpeed = 128,
            .deltaTime = 0,
            .assets = assets,
            .assetMenu = assetMenu,
            .tileset = tileset,
            .tilesetMenu = tilesetMenu,
        };
        return editor;
    }

    pub fn Update(this: *Editor) void {
        Window.UpdateWindow();
        const delta = c.GetFrameTime();
        this.deltaTime += delta;
        //TODO: make a state machine for inputs

        if (!this.assetMenu.isOpen) {
            if (c.IsKeyDown(c.KEY_W)) {
                Window.camera.target.y -= this.cameraSpeed * delta;
            }
            if (c.IsKeyDown(c.KEY_S)) {
                Window.camera.target.y += this.cameraSpeed * delta;
            }
            if (c.IsKeyDown(c.KEY_A)) {
                Window.camera.target.x -= this.cameraSpeed * delta;
            }
            if (c.IsKeyDown(c.KEY_D)) {
                Window.camera.target.x += this.cameraSpeed * delta;
            }
        }

        if (c.IsKeyPressed(c.KEY_Q)) {
            this.assetMenu.isOpen = !this.assetMenu.isOpen;
        }

        if (c.IsKeyPressed(c.KEY_E)) {
            //TODO: dont want to be able to have both menus open, fix later
            this.tilesetMenu.isOpen = !this.tilesetMenu.isOpen;
        }

        if (c.IsMouseButtonPressed(c.MOUSE_BUTTON_RIGHT)) {
            this.pickedAsset = null;
        }

        //TODO: switch to a state machine??
        const picked_asset: ?*Assets.Node = @ptrCast(@alignCast(this.assetMenu.Update())); //TODO: this will return the picked asset to use for building
        if (picked_asset) |asset| {
            this.assetMenu.isOpen = false;
            this.pickedAsset = asset;
        }

        //TODO: probably a better way to do this
        const picked_tile: ?*Tileset.TileNode = @ptrCast(@alignCast(this.tilesetMenu.Update()));
        if (picked_tile) |tile| {
            this.tilesetMenu.isOpen = false;
            this.pickedTile = tile;
        }

        if (this.pickedAsset) |asset| {
            if (c.IsMouseButtonPressed(c.MOUSE_BUTTON_LEFT)) {
                std.debug.print("asset: {?}", .{asset});
            }
        }

        if (this.pickedTile) |tile| {
            if (c.IsMouseButtonPressed(c.MOUSE_BUTTON_LEFT)) {
                const mouse = c.GetMousePosition();
                const renderDestination = Utils.screenToRenderTextureCoords(mouse);
                const world = c.GetScreenToWorld2D(renderDestination, Window.camera);
                const tileCoords = Types.Vector2Int{ .x = @intFromFloat(world.x / 16), .y = @intFromFloat(world.y / 16) };
                std.debug.print("rect: {}\n", .{tile});
                std.debug.print("mouse: {}\n", .{tileCoords});

                //TODO: add tile into level

                this.world.currentLevel.SetTile(tileCoords, tile);
            }
        }
    }

    pub fn DrawEditor(this: *Editor) void {
        if (this.pickedAsset) |asset| {
            const mouse = c.GetMousePosition();
            const renderDestination = Utils.screenToRenderTextureCoords(mouse);
            const world = c.GetScreenToWorld2D(renderDestination, Window.camera);

            c.DrawTexture(asset.texture.*, @as(c_int, @intFromFloat(world.x)), @as(c_int, @intFromFloat(world.y)), c.WHITE);
        }

        if (this.pickedTile) |rect| {
            //std.debug.print("picked_rect {}\n", .{rect});
            //std.debug.print("source: {}\n", .{this.tileset.source});
            const mouse = c.GetMousePosition();
            const renderDestination = Utils.screenToRenderTextureCoords(mouse);
            const world = c.GetScreenToWorld2D(renderDestination, Window.camera);

            if (this.tileset.source) |source| {
                c.DrawTextureRec(source.*, rect.rect, world, c.WHITE);
            }
        }
    }

    pub fn Draw(this: *Editor) !void {
        c.BeginTextureMode(Window.screen);
        c.BeginMode2D(Window.camera);
        c.ClearBackground(c.BLACK);
        this.world.Draw();
        this.DrawEditor();
        c.EndMode2D();
        c.BeginScissorMode(0, 0, Config.game_width, Config.game_height);
        try this.assetMenu.Draw();
        try this.tilesetMenu.Draw();

        c.EndScissorMode();
        c.EndTextureMode();
    }
};
