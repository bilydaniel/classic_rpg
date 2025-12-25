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
const InputManager = @import("inputManager.zig");
const ShaderManager = @import("shaderManager.zig");
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
    shaderManager: *ShaderManager.ShaderManager,
    uiManager: *UiManager.UiManager,
    inputManager: *InputManager.InputManager,
    uiCommand: UiManager.UiCommand = UiManager.UiCommand{},
    entityManager: *EntityManager.EntityManager,

    pub fn init(
        allocator: std.mem.Allocator,
        gamestate: *Gamestate.gameState,
        player: *Entity.Entity,
        delta: f32,
        world: *World.World,
        grid: *[]Level.Tile,
        cameraManager: *CameraManager.CamManager,
        pathfinder: *Pathfinder.Pathfinder,
        shadermanager: *ShaderManager.ShaderManager,
        uimanager: *UiManager.UiManager,
        inputManager: *InputManager.InputManager,
        entityManager: *EntityManager.EntityManager,
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
            .shaderManager = shadermanager,
            .uiManager = uimanager,
            .inputManager = inputManager,
            .entityManager = entityManager,
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
    inputManager: *InputManager.InputManager,
    shaderManager: *ShaderManager.ShaderManager,
    entityManager: *EntityManager.EntityManager,

    pub fn init(allocator: std.mem.Allocator) !*Game {
        //TODO: figure out instantiation of types of entities
        //probably a file with some sort of templates?

        const game = try allocator.create(Game);
        const gamestate = try Gamestate.gameState.init(allocator);

        const entitymanager = try EntityManager.EntityManager.init(allocator);
        const player = try entitymanager.fillEntities();

        const tilesetmanager = try TilesetManager.TilesetManager.init(allocator);
        const pathfinder = try Pathfinder.Pathfinder.init(allocator);
        const cameraManager = try CameraManager.CamManager.init(allocator, player);
        const world = try World.World.init(allocator);
        const shadermanager = try ShaderManager.ShaderManager.init(allocator);

        const uimanager = try UiManager.UiManager.init(allocator);
        const inputManager = try InputManager.InputManager.init(allocator);

        //TODO: refactor this, dont need game and context
        const context = try Context.init(
            allocator,
            gamestate,
            player,
            0,
            world,
            &world.currentLevel.grid,
            cameraManager,
            pathfinder,
            shadermanager,
            uimanager,
            inputManager,
            entitymanager,
        );

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
            .shaderManager = shadermanager,
            .inputManager = inputManager,
            .entityManager = entitymanager,
        };

        Systems.calculateFOV(&game.world.currentLevel.grid, player.pos, 8);
        return game;
    }

    pub fn Update(this: *Game) !void {
        const delta = c.GetFrameTime();
        this.context.delta = delta;
        //TODO: decide on a game loop, look into the book
        Window.updateWindow();

        //TODO: when i change the window size, clicking is not precise anymore
        //TODO: make a state machine for inputs

        //TODO: make uimanager retutn commands that get used in updateplayer etc.
        //TODO take UIintent out of this
        //uiintent = intent.init()
        //-> send &uiintent into uimanager.update, use it in update

        const uiCommand = try this.uiManager.update(this.context);
        this.context.uiCommand = uiCommand;
        //std.debug.print("ui_command: {}\n", .{uiCommand});

        this.cameraManager.Update(delta);
        this.gameState.update();

        this.shaderManager.update(delta);
    }

    pub fn Draw(this: *Game) void {
        c.BeginDrawing();
        c.ClearBackground(c.BLACK);
        c.DrawFPS(0, 0);
        c.BeginMode2D(this.cameraManager.camera.*);
        this.world.Draw(this.tilesetManager);
        this.player.Draw(this.tilesetManager);
        this.shaderManager.draw();

        //TODO: @conitnue put draw in gamestate
        Systems.drawGameState(this.gameState, this.world.currentLevel);

        c.EndMode2D();
        this.uiManager.draw();

        c.EndDrawing();
    }
};
