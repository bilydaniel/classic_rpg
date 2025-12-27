const std = @import("std");
const Game = @import("../game/game.zig");
const Entity = @import("../game/entity.zig");
const Window = @import("../game/window.zig");
const Types = @import("../common/types.zig");
const Utils = @import("../common/utils.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

var entity_allocator: std.mem.Allocator = undefined;
pub var entities: std.ArrayList(Entity.Entity) = undefined;

const PLAYER_INDEX = 0; //always 0

//TODO: switch to hash table?
//pub var entities: std.AutoHashMap(u32, *Entity.Entity) = undefined;
//nextEntityID: u32 = 0,
//TODO: no idea if needed

pub fn init(allocator: std.mem.Allocator) void {
    entity_allocator = allocator;
    entities = std.ArrayList(Entity.Entity).init(allocator);
}

// just a helper funciton, returns the player so it can be used to fill into context
pub fn fillEntities() !Entity.Entity {
    var playerData = try Entity.PlayerData.init(entity_allocator);

    const pup_pos = Types.Vector2Int{ .x = -1, .y = -1 };
    var puppet = try Entity.Entity.init(entity_allocator, pup_pos, 0, 1.0, Entity.EntityData{ .puppet = .{ .deployed = false } }, "&");
    puppet.visible = false;
    puppet.name = "Pamama";
    puppet.setTextureID(50);
    try playerData.puppets.append(puppet.id);

    var player = try Entity.Entity.init(entity_allocator, Types.Vector2Int{ .x = 3, .y = 2 }, 0, 1, Entity.EntityData{ .player = playerData }, "@");
    player.setTextureID(76);
    try addEntity(player);
    try addEntity(puppet);

    const pos = Types.Vector2Int{ .x = 5, .y = 5 };
    const enemy_tile = 55;
    const enemy_rect = Utils.makeSourceRect(enemy_tile);
    const enemy_goal = Types.Vector2Int.init(2, 2);

    var entity = try Entity.Entity.init(entity_allocator, pos, 0, 1.0, Entity.EntityData{ .enemy = .{ .asd = true } }, "r");
    entity.goal = enemy_goal;

    entity.textureID = enemy_tile;
    entity.sourceRect = enemy_rect;

    const pos2 = Types.Vector2Int{ .x = 6, .y = 6 };
    var entity2 = try Entity.Entity.init(entity_allocator, pos2, 0, 1.0, Entity.EntityData{ .enemy = .{ .asd = true } }, "r");
    entity2.textureID = enemy_tile;
    entity2.sourceRect = enemy_rect;

    const pos3 = Types.Vector2Int{ .x = 7, .y = 7 };
    var entity3 = try Entity.Entity.init(entity_allocator, pos3, 0, 1.0, Entity.EntityData{ .enemy = .{ .asd = true } }, "r");
    entity3.textureID = enemy_tile;
    entity3.sourceRect = enemy_rect;

    try addEntity(entity);
    try addEntity(entity2);
    try addEntity(entity3);

    return player;
}

pub fn addEntity(entity: Entity.Entity) !void {
    try entities.append(entity);
}

pub fn update(ctx: *Game.Game) !void {
    for (entities.items) |*entity| {
        entity.update(ctx);
    }

    //TODO: when to switch current_turn to enemy?
    //gonna have to be more complicated than this
    ctx.gamestate.currentTurn = .enemy;
}

pub fn getPlayer() *Entity.Entity {
    //always use this, dont acess directly entities[0], if something changes i can
    //iterate and find the player that way

    // for (entities.items) |entity| {
    //     if (entity.data == .player) {
    //         return entity;
    //     }
    // }
    return &entities.items[PLAYER_INDEX];
}

pub fn genEntityID(id: u32) ?*Entity.Entity {
    for (entities.items) |*entity| {
        if (entity.id == id) {
            return entity;
        }
    }
    return null;
}
