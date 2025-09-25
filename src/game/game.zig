const std = @import("std");
const World = @import("world.zig");
const Level = @import("level.zig");
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
const UiManager = @import("../ui/uiManager.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const Context = struct {
    gamestate: *Gamestate.gameState,
    player: *Entity.Entity,
    delta: f32,
    world: *World.World,
    grid: *[]Level.Tile,
    cameraManager: *CameraManager.CamManager,
    pathfinder: *Pathfinder.Pathfinder,
    entities: *std.ArrayList(*Entity.Entity),

    pub fn init(
        allocator: std.mem.Allocator,
        gamestate: *Gamestate.gameState,
        player: *Entity.Entity,
        delta: f32,
        world: *World.World,
        grid: *[]Level.Tile,
        cameraManager: *CameraManager.CamManager,
        pathfinder: *Pathfinder.Pathfinder,
        entities: *std.ArrayList(*Entity.Entity),
    ) !*Context {
        const context = try allocator.create(Context);
        context.* = .{
            .gamestate = gamestate,
            .player = player,
            .delta = delta,
            .world = world,
            .grid = grid,
            .cameraManager = cameraManager,
            .pathfinder = pathfinder,
            .entities = entities,
        };
        return context;
    }
};

pub const Game = struct {
    allocator: std.mem.Allocator,
    gameState: *Gamestate.gameState,
    player: *Entity.Entity,
    world: *World.World,
    cameraManager: *CameraManager.CamManager,
    pathfinder: *Pathfinder.Pathfinder,
    tilesetManager: *TilesetManager.TilesetManager,
    context: *Context,
    uiManager: *UiManager.UiManager,

    pub fn init(allocator: std.mem.Allocator) !*Game {
        //TODO: figure out instantiation of types of entities
        //probably a file with some sort of templates?

        const game = try allocator.create(Game);
        const gamestate = try Gamestate.gameState.init(allocator);
        const playerData = try Entity.PlayerData.init(allocator);
        var player = try Entity.Entity.init(allocator, Types.Vector2Int{ .x = 3, .y = 2 }, 0, 1, Entity.EntityData{ .player = playerData }, "@");
        player.setTextureID(76);
        const tilesetmanager = try TilesetManager.TilesetManager.init(allocator);
        const pathfinder = try Pathfinder.Pathfinder.init(allocator);
        const cameraManager = try CameraManager.CamManager.init(allocator, player);
        const world = try World.World.init(allocator);
        try world.entities.append(player);
        for (player.data.player.puppets.items) |pup| {
            try world.entities.append(pup);
        }

        const context = try Context.init(
            allocator,
            gamestate,
            player,
            0,
            world,
            &world.currentLevel.grid,
            cameraManager,
            pathfinder,
            &world.entities,
        );

        const uimanager = try UiManager.UiManager.init(allocator, context);
        game.* = .{
            .allocator = allocator,
            .gameState = gamestate,
            .world = world,
            .player = player,
            .pathfinder = pathfinder,
            .tilesetManager = tilesetmanager,
            .cameraManager = cameraManager,
            .context = context,
            .uiManager = uimanager,
        };

        Systems.calculateFOV(&game.world.currentLevel.grid, player.pos, 8);
        return game;
    }

    pub fn Update(this: *Game) !void {
        const delta = c.GetFrameTime();
        this.context.delta = delta;
        //TODO: decide on a game loop, look into the book
        Window.UpdateWindow();

        //TODO: when i change the window size, clicking is not precise anymore
        //TODO: make a state machine for inputs

        try Systems.updatePlayer(this.context);
        try this.world.Update(this.context);
        this.cameraManager.Update(delta);

        this.uiManager.update(this.context);
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
        this.uiManager.draw();

        c.EndDrawing();
    }
};
