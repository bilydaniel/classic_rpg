const std = @import("std");
const Game = @import("../game/game.zig");
const Entity = @import("../game/entity.zig");
const Window = @import("../game/window.zig");
const Types = @import("../common/types.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const EntityManager = struct {
    allocator: std.mem.Allocator,
    entities: std.AutoHashMap(u32, *Entity.Entity),
    nextEntityID: u32 = 0,

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

        return player;
    }

    pub fn addEntity(this: *EntityManager, entity: *Entity.Entity) !void {
        try this.entities.put(this.nextEntityID, entity);
        this.nextEntityID += 1;
    }
};
