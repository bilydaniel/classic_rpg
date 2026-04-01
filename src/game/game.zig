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
const Movement = @import("movement.zig");
const Config = @import("../common/config.zig");
const rl = @import("raylib");
const Profiler = @import("../common/profiler.zig");

pub const Game = struct {
    delta: f32,
    allocator: std.mem.Allocator,
    player: *Entity.Entity,

    pub fn init(allocator: std.mem.Allocator) !*Game {
        //TODO: figure out instantiation of types of entities
        //probably a file with some sort of templates?

        const game = try allocator.create(Game);

        Entity.init(allocator);
        Movement.init(allocator);
        Systems.init(allocator);
        PlayerController.init(allocator);
        Gamestate.init(allocator);

        try World.init(allocator);
        EntityManager.init(allocator);

        try EntityManager.fillEntities();
        const player = EntityManager.getPlayer();

        TurnManager.init(allocator);

        try TilesetManager.init();
        try Pathfinder.init(allocator);
        try CameraManager.init(allocator, EntityManager.playerHandle);
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

    pub fn deinit(this: *Game) void {
        Gamestate.deinit();
        EntityManager.deinit();

        TurnManager.deinit();
        TilesetManager.deinit();
        CameraManager.deinit(this.allocator);
        World.deinit(this.allocator);
        try ShaderManager.deinit();
        //try UiManager.init(allocator);

        this.allocator.destroy(this);
    }

    pub fn update(this: *Game) !void {
        const updateProfile = Profiler.TimeBlock("update", @src());
        const delta = rl.getFrameTime();

        //
        // draw to the buffer
        //
        UiManager.readInput(this);

        this.player = EntityManager.getPlayer();
        this.delta = delta;
        //TODO: decide on a game loop, look into the book
        Window.updateWindow();

        try PlayerController.update(this);
        //try EntityManager.update(this);
        try TurnManager.update(this);

        CameraManager.update(delta);
        Gamestate.update();

        ShaderManager.update(delta);

        try EntityManager.despawnEntities();
        try EntityManager.spawnEntities();
        updateProfile.end();
    }

    pub fn draw(this: *Game) !void {
        const drawProfile = Profiler.TimeBlock("draw", @src());

        UiManager.drawToBuffer();
        UiManager.draw(this);
        rl.drawFPS(0, 0);
        UiManager.stopDrawingToBuffer();

        // First pass: render game into Window.screen
        rl.beginTextureMode(Window.screen);
        rl.clearBackground(rl.Color.black);
        rl.beginMode2D(CameraManager.camera.*);
        World.draw();
        this.player.draw();
        EntityManager.draw();
        ShaderManager.draw();
        try Gamestate.draw();

        rl.endMode2D();

        UiManager.drawBufferToWindow();
        rl.endTextureMode();

        //
        //SHADER PASS
        //
        rl.beginDrawing();
        rl.clearBackground(rl.Color.black);

        const t: f32 = @floatCast(rl.getTime());
        rl.setShaderValue(ShaderManager.crtShader.source, ShaderManager.crtShader.timeLoc, &t, .float);

        const res = [2]f32{
            @floatFromInt(Window.scaledWidth),
            @floatFromInt(Window.scaledHeight),
        };
        rl.setShaderValue(ShaderManager.crtShader.source, ShaderManager.crtShader.resolutionLoc, &res, .vec2);

        //rl.beginShaderMode(ShaderManager.crtShader.source);
        rl.drawTexturePro(
            Window.screen.texture,
            .{ .x = 0, .y = 0, .width = Config.game_width, .height = -Config.game_height },
            .{ .x = @floatFromInt(Window.offsetx), .y = @floatFromInt(Window.offsety), .width = @floatFromInt(Window.scaledWidth), .height = @floatFromInt(Window.scaledHeight) },
            .{ .x = 0, .y = 0 },
            0.0,
            rl.Color.white,
        );

        //rl.endShaderMode();

        drawProfile.end();

        rl.endDrawing();
    }
};
