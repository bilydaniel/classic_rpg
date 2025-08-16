const std = @import("std");
const World = @import("world.zig");
const Systems = @import("Systems.zig");
const CameraManager = @import("cameraManager.zig");
const TilesetManager = @import("tilesetManager.zig");
const Gamestate = @import("gamestate.zig");
const Entity = @import("entity.zig");
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
    cameraManager: CameraManager.CamManager,
    pathfinder: *Pathfinder.Pathfinder,
    tilesetManager: *TilesetManager.TilesetManager,

    pub fn init(allocator: std.mem.Allocator) !*Game {
        //TODO: figure out instantiation of types of entities
        //probably a file with some sort of templates?

        const game = try allocator.create(Game);
        const gamestate = try Gamestate.gameState.init(allocator);
        const playerData = try Entity.PlayerData.init(allocator);
        var player = try Entity.Entity.init(allocator, Types.Vector2Int{ .x = 3, .y = 2 }, 1, Entity.EntityData{ .player = playerData }, "@");
        player.setTextureID(76);
        const tilesetmanager = try TilesetManager.TilesetManager.init(allocator);
        const pathfinder = try Pathfinder.Pathfinder.init(allocator);
        const cameraManager = try CameraManager.CamManager.init(allocator, player);

        game.* = .{
            .allocator = allocator,
            .gameState = gamestate,
            .world = try World.World.init(allocator),
            .player = player,
            .pathfinder = pathfinder,
            .tilesetManager = tilesetmanager,
            .cameraManager = cameraManager,
        };

        Systems.calculateFOV(&game.world.currentLevel.grid, player.pos, 8);
        return game;
    }

    pub fn Update(this: *Game) !void {
        const delta = c.GetFrameTime();
        //TODO: decide on a game loop, look into the book
        Window.UpdateWindow();
        this.cameraManager.Update(delta);

        //TODO: when i change the window size, clicking is not precise anymore
        //TODO: make a state machine for inputs

        try Systems.updatePlayer(this.gameState, this.player, delta, this.world, &this.cameraManager, this.pathfinder, &this.world.entities);
        this.world.Update();
    }

    pub fn Draw(this: *Game) void {
        c.BeginDrawing();
        c.ClearBackground(c.BLACK);
        c.DrawFPS(0, 0);
        c.BeginMode2D(this.cameraManager.camera.*);
        this.world.Draw(this.tilesetManager);
        this.player.Draw(this.tilesetManager);
        Systems.drawGameState(this.gameState, this.world.currentLevel);
        c.EndMode2D();
        c.EndDrawing();
    }
};
