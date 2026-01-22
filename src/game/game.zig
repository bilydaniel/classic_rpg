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

    pub fn init(allocator: std.mem.Allocator) !*Game {
        //TODO: figure out instantiation of types of entities
        //probably a file with some sort of templates?

        const game = try allocator.create(Game);

        Gamestate.init(allocator);
        EntityManager.init(allocator);

        try EntityManager.fillEntities();
        const player = EntityManager.getPlayer();

        TilesetManager.init();
        try Pathfinder.init(allocator);
        try CameraManager.init(allocator, player.id);
        try World.init(allocator);
        try ShaderManager.init(allocator);

        try UiManager.init(allocator);

        game.* = .{
            .delta = 0,
            .allocator = allocator,
            .player = player,
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

        try UiManager.update(this);
        try EntityManager.update(this);

        CameraManager.update(delta);
        Gamestate.update();

        ShaderManager.update(delta);
    }

    pub fn draw(this: *Game) !void {
        c.BeginDrawing();
        c.ClearBackground(c.BLACK);
        c.DrawFPS(0, 0);
        c.BeginMode2D(CameraManager.camera.*);
        World.draw();
        this.player.draw();
        EntityManager.draw();
        ShaderManager.draw();

        try Gamestate.draw();

        c.EndMode2D();
        try UiManager.draw();

        c.EndDrawing();
    }
};
