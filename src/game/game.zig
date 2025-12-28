const std = @import("std");
const World = @import("world.zig");
const Level = @import("level.zig");
const Systems = @import("Systems.zig");
const CameraManager = @import("cameraManager.zig");
const TilesetManager = @import("tilesetManager.zig");
const Gamestate = @import("gamestate.zig");
const Entity = @import("entity.zig");
const EntityManager = @import("entityManager.zig");
const Tileset = @import("../game/tileset.zig");
const Window = @import("../game/window.zig");
const Config = @import("../common/config.zig");
const Types = @import("../common/types.zig");
const Utils = @import("../common/utils.zig");
const Pathfinder = @import("../game/pathfinder.zig");
const UiManager = @import("../ui/uiManager.zig");
const ShaderManager = @import("shaderManager.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const Game = struct {
    delta: f32,
    allocator: std.mem.Allocator,
    player: *Entity.Entity,
    pathfinder: *Pathfinder.Pathfinder,
    tilesetManager: *TilesetManager.TilesetManager,
    uiManager: *UiManager.UiManager,
    shaderManager: *ShaderManager.ShaderManager,
    uiCommand: UiManager.UiCommand = UiManager.UiCommand{},

    pub fn init(allocator: std.mem.Allocator) !*Game {
        //TODO: figure out instantiation of types of entities
        //probably a file with some sort of templates?

        const game = try allocator.create(Game);
        Gamestate.init(allocator);

        EntityManager.init(allocator);
        var player = try EntityManager.fillEntities();

        const tilesetmanager = try TilesetManager.TilesetManager.init(allocator);
        const pathfinder = try Pathfinder.Pathfinder.init(allocator);
        try CameraManager.init(allocator, player.id);
        try World.init(allocator);
        const shadermanager = try ShaderManager.ShaderManager.init(allocator);

        const uimanager = try UiManager.UiManager.init(allocator);

        game.* = .{
            .delta = 0,
            .allocator = allocator,
            .player = &player,
            .pathfinder = pathfinder,
            .tilesetManager = tilesetmanager,
            .uiManager = uimanager,
            .shaderManager = shadermanager,
        };

        Systems.calculateFOV(player.pos, 8);
        return game;
    }

    pub fn update(this: *Game) !void {
        const delta = c.GetFrameTime();
        this.player = EntityManager.getPlayer();
        this.delta = delta;
        //TODO: decide on a game loop, look into the book
        Window.updateWindow();

        //TODO: when i change the window size, clicking is not precise anymore
        //TODO: make a state machine for inputs

        //TODO: make uimanager retutn commands that get used in updateplayer etc.
        //TODO take UIintent out of this
        //uiintent = intent.init()
        //-> send &uiintent into uimanager.update, use it in update

        try this.uiManager.update(this);
        this.uiCommand = UiManager.uiCommand;
        //std.debug.print("ui_command: {}\n", .{uiCommand});
        //this.world.update(this.context);
        try EntityManager.update(this);

        CameraManager.update(delta);
        Gamestate.update();

        this.shaderManager.update(delta);
    }

    pub fn draw(this: *Game) void {
        c.BeginDrawing();
        c.ClearBackground(c.BLACK);
        c.DrawFPS(0, 0);
        c.BeginMode2D(CameraManager.camera.*);
        World.draw(this.tilesetManager);
        this.player.draw(this.tilesetManager);
        this.shaderManager.draw();

        //TODO: @conitnue put draw in gamestate
        Gamestate.draw();

        c.EndMode2D();
        this.uiManager.draw();

        c.EndDrawing();
    }
};
