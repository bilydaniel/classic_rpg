const Level = @import("level.zig");
const Pathfinder = @import("pathfinder.zig");
const Entity = @import("entity.zig");
const TilesetManager = @import("tilesetManager.zig");
const std = @import("std");
const Game = @import("game.zig");
const Types = @import("../common/types.zig");
const Utils = @import("../common/utils.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const World = struct {
    allocator: std.mem.Allocator,
    currentLevel: *Level.Level,
    levels: std.ArrayList(*Level.Level),
    levelLinks: std.ArrayList(Level.Link),
    entities: std.ArrayList(*Entity.Entity),

    //TODO: https://claude.ai/chat/8b0e4ed0-f114-4284-8f99-4b344afaedcb
    //https://chatgpt.com/c/68091cb1-4588-8004-afb8-f2154206753d
    //https://claude.ai/chat/5b723b6b-7166-4163-a2d2-379478335455

    pub fn init(allocator: std.mem.Allocator) !*World {
        const world = try allocator.create(World);
        var levels = std.ArrayList(*Level.Level).init(allocator);
        var entities = std.ArrayList(*Entity.Entity).init(allocator);

        const pos = Types.Vector2Int{ .x = 5, .y = 5 };
        const enemy_tile = 55;
        const enemy_rect = Utils.makeSourceRect(enemy_tile);
        const enemy_goal = Types.Vector2Int.init(2, 2);

        const entity = try Entity.Entity.init(allocator, pos, 0, 1.0, Entity.EntityData{ .enemy = .{ .goal = enemy_goal } }, "r");
        entity.textureID = enemy_tile;
        entity.sourceRect = enemy_rect;

        const pos2 = Types.Vector2Int{ .x = 6, .y = 6 };
        const entity2 = try Entity.Entity.init(allocator, pos2, 0, 1.0, Entity.EntityData{ .enemy = .{ .goal = enemy_goal } }, "r");
        entity2.textureID = enemy_tile;
        entity2.sourceRect = enemy_rect;

        const pos3 = Types.Vector2Int{ .x = 7, .y = 7 };
        const entity3 = try Entity.Entity.init(allocator, pos3, 0, 1.0, Entity.EntityData{ .enemy = .{ .goal = enemy_goal } }, "r");
        entity3.textureID = enemy_tile;
        entity3.sourceRect = enemy_rect;

        try entities.append(entity);
        try entities.append(entity2);
        try entities.append(entity3);

        var level1 = try Level.Level.init(allocator, 0);
        level1.generateInterestingLevel();
        var level2 = try Level.Level.init(allocator, 1);
        level2.generateInterestingLevel2();
        try levels.append(level1);
        try levels.append(level2);

        var levelLinks = std.ArrayList(Level.Link).init(allocator);
        const link1 = Level.Link{
            .from = Level.Location{
                .level = 0,
                .pos = Types.Vector2Int.init(22, 18),
            },
            .to = Level.Location{
                .level = 1,
                .pos = Types.Vector2Int.init(3, 6),
            },
        };

        const link2 = Level.Link{
            .from = Level.Location{
                .level = 1,
                .pos = Types.Vector2Int.init(3, 6),
            },
            .to = Level.Location{
                .level = 0,
                .pos = Types.Vector2Int.init(22, 18),
            },
        };

        try levelLinks.append(link1);
        try levelLinks.append(link2);

        world.* = .{
            .currentLevel = level1,
            .allocator = allocator,
            .levels = levels,
            .entities = entities,
            .levelLinks = levelLinks,
        };

        return world;
    }

    pub fn Draw(this: *World, tilesetManager: *TilesetManager.TilesetManager) void {
        this.currentLevel.Draw(this.entities, tilesetManager);
    }

    pub fn Update(this: *World, ctx: *Game.Context) !void {
        //TODO: how do I want the order of the update?
        //std.debug.print("current_turn: {}\n", .{ctx.gamestate.currentTurn});

        if (ctx.gamestate.currentTurn == .enemy) {
            for (this.entities.items) |entity| {
                if (entity.data == .enemy) {
                    try entity.update(ctx);
                }
            }
            ctx.gamestate.currentTurn = .player;
        }
        for (this.levels.items) |lvl| {
            lvl.Update(ctx.pathfinder);
        }
    }
};
