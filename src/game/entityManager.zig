const std = @import("std");
const Game = @import("../game/game.zig");
const Entity = @import("../game/entity.zig");
const Window = @import("../game/window.zig");
const Types = @import("../common/types.zig");
const Utils = @import("../common/utils.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const EntityManager = struct {
    allocator: std.mem.Allocator,
    entities: std.AutoHashMap(u32, *Entity.Entity),
    //nextEntityID: u32 = 0,
    //TODO: no idea if needed

    pub fn init(allocator: std.mem.Allocator) !*EntityManager {
        const entitymanager = try allocator.create(EntityManager);
        const entities = std.AutoHashMap(u32, *Entity.Entity).init(allocator);
        entitymanager.* = .{
            .allocator = allocator,
            .entities = entities,
        };
        return entitymanager;
    }

    // just a helper funciton, returns the player so it can be used to fill into context
    pub fn fillEntities(this: *EntityManager) !*Entity.Entity {
        const playerData = try Entity.PlayerData.init(this.allocator);
        var player = try Entity.Entity.init(this.allocator, Types.Vector2Int{ .x = 3, .y = 2 }, 0, 1, Entity.EntityData{ .player = playerData }, "@");
        player.setTextureID(76);
        try this.addEntity(player);

        const pos = Types.Vector2Int{ .x = 5, .y = 5 };
        const enemy_tile = 55;
        const enemy_rect = Utils.makeSourceRect(enemy_tile);
        const enemy_goal = Types.Vector2Int.init(2, 2);

        const entity = try Entity.Entity.init(this.allocator, pos, 0, 1.0, Entity.EntityData{ .enemy = .{ .asd = true } }, "r");
        entity.goal = enemy_goal;

        entity.textureID = enemy_tile;
        entity.sourceRect = enemy_rect;

        const pos2 = Types.Vector2Int{ .x = 6, .y = 6 };
        const entity2 = try Entity.Entity.init(this.allocator, pos2, 0, 1.0, Entity.EntityData{ .enemy = .{ .asd = true } }, "r");
        entity2.textureID = enemy_tile;
        entity2.sourceRect = enemy_rect;

        const pos3 = Types.Vector2Int{ .x = 7, .y = 7 };
        const entity3 = try Entity.Entity.init(this.allocator, pos3, 0, 1.0, Entity.EntityData{ .enemy = .{ .asd = true } }, "r");
        entity3.textureID = enemy_tile;
        entity3.sourceRect = enemy_rect;

        try this.addEntity(entity);
        try this.addEntity(entity2);
        try this.addEntity(entity3);

        return player;
    }

    pub fn addEntity(this: *EntityManager, entity: *Entity.Entity) !void {
        try this.entities.put(entity.id, entity);
    }

    pub fn update(this: *EntityManager, ctx: *Game.Context) !void {
        const iterator = this.entities.iterator();
        for (iterator.next()) |entity| {
            entity.update(ctx);
        }
        //TODO: when to switch current_turn to enemy?
        //gonna have to be more complicated than this
        ctx.gamestate.currentTurn = .enemy;
    }
};
