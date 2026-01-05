const std = @import("std");
const Game = @import("../game/game.zig");
const Entity = @import("../game/entity.zig");
const Window = @import("../game/window.zig");
const Types = @import("../common/types.zig");
const Utils = @import("../common/utils.zig");
const Gamestate = @import("gamestate.zig");
const Systems = @import("Systems.zig");
const CameraManager = @import("cameraManager.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

var entity_allocator: std.mem.Allocator = undefined;
pub var entities: std.ArrayList(Entity.Entity) = undefined;
pub var walkingEntity: ?*Entity.Entity = null;

const PLAYER_INDEX = 0; //always 0

//TODO: switch to hash table?
//pub var entities: std.AutoHashMap(u32, *Entity.Entity) = undefined;
//nextEntityID: u32 = 0,
//TODO: no idea if needed

pub fn init(allocator: std.mem.Allocator) void {
    entity_allocator = allocator;
    entities = std.ArrayList(Entity.Entity).init(allocator);
}

pub fn setWalkingEntity(entity: *Entity.Entity) void {
    walkingEntity = entity;
    CameraManager.targetEntity = entity.id;
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

    const pos = Types.Vector2Int{ .x = 5, .y = 15 };
    const enemy_tile = 55;
    const enemy_rect = Utils.makeSourceRect(enemy_tile);
    const enemy_goal = Types.Vector2Int.init(2, 2);

    var entity = try Entity.Entity.init(entity_allocator, pos, 0, 1.0, Entity.EntityData{ .enemy = .{ .asd = true } }, "r");
    entity.goal = enemy_goal;

    entity.textureID = enemy_tile;
    entity.sourceRect = enemy_rect;

    const pos2 = Types.Vector2Int{ .x = 6, .y = 16 };
    var entity2 = try Entity.Entity.init(entity_allocator, pos2, 0, 1.0, Entity.EntityData{ .enemy = .{ .asd = true } }, "r");
    entity2.textureID = enemy_tile;
    entity2.sourceRect = enemy_rect;

    const pos3 = Types.Vector2Int{ .x = 7, .y = 17 };
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

pub fn update(game: *Game.Game) !void {
    if (walkingEntity) |entity| {
        try Systems.updateEntityMovement(entity, game);
        if (entity.path == null) {
            walkingEntity = null;
        }
        return;
    }

    for (entities.items) |*entity| {
        //TODO: probably should refactor AI, the state management is horrible
        // so many bugs
        //https://claude.ai/chat/5e92415c-8474-4796-9b8b-9c25062e0525 ,might help
        try entity.update(game);
    }

    var allEnemiesMoved = true;
    for (entities.items) |entity| {
        if (entity.data == .enemy and !entity.hasMoved) {
            allEnemiesMoved = false;
        }
    }

    //TODO: when to switch current_turn to enemy?
    //gonna have to be more complicated than this
    if (Gamestate.currentTurn != .player and allEnemiesMoved) {
        Gamestate.switchTurn(.player);
        resetHasMoved();
    }
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

pub fn getEntityID(id: u32) ?*Entity.Entity {
    for (entities.items) |*entity| {
        if (entity.id == id) {
            return entity;
        }
    }
    return null;
}

pub fn getEntityByPos(pos: Types.Vector2Int) ?*Entity.Entity {
    for (entities.items) |*entity| {
        if (Types.vector2IntCompare(entity.pos, pos)) {
            return entity;
        }
    }
    return null;
}

pub fn resetHasMoved() void {
    for (entities.items) |*entity| {
        entity.hasMoved = false;
    }
}
