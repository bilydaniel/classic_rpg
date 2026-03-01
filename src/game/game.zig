const std = @import("std");
const World = @import("world.zig");
const Systems = @import("Systems.zig");
const CameraManager = @import("cameraManager.zig");
const TilesetManager = @import("assetManager.zig");
const Gamestate = @import("gamestate.zig");
const Entity = @import("entity.zig");
const EntityManager = @import("entityManager.zig");
const TurnManager = @import("turnManager.zig");
const Window = @import("../game/window.zig");
const Pathfinder = @import("../game/pathfinder.zig");
const UiManager = @import("../ui/uiManager.zig");
const ShaderManager = @import("shaderManager.zig");
const PlayerController = @import("playerController.zig");
const rl = @import("raylib");

pub const Game = struct {
    delta: f32,
    allocator: std.mem.Allocator,
    player: *Entity.Entity,

    pub fn init(allocator: std.mem.Allocator) !*Game {
        //TODO: figure out instantiation of types of entities
        //probably a file with some sort of templates?

        const game = try allocator.create(Game);

        Systems.init(allocator);
        PlayerController.init(allocator);
        Gamestate.init(allocator);
        EntityManager.init(allocator);

        try EntityManager.fillEntities();
        const player = EntityManager.getPlayer();

        TurnManager.init(allocator);

        try TilesetManager.init();
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
        const delta = rl.getFrameTime();
        this.player = EntityManager.getPlayer();
        this.delta = delta;
        //TODO: decide on a game loop, look into the book
        Window.updateWindow();

        try PlayerController.update(this);
        try UiManager.update(this);
        //try EntityManager.update(this);
        try TurnManager.update(this);

        CameraManager.update(delta);
        Gamestate.update();

        ShaderManager.update(delta);

        try EntityManager.despawn();
        try EntityManager.spawn();
    }

    pub fn draw(this: *Game) !void {
        rl.beginDrawing();
        rl.clearBackground(rl.Color.black);
        rl.drawFPS(0, 0);
        rl.beginMode2D(CameraManager.camera.*);
        World.draw();
        this.player.draw();
        EntityManager.draw();
        ShaderManager.draw();

        try Gamestate.draw();

        rl.endMode2D();
        try UiManager.draw();

        rl.endDrawing();
    }
};
