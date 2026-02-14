const std = @import("std");
const Game = @import("../game/game.zig");
const Entity = @import("../game/entity.zig");
const Window = @import("../game/window.zig");
const Types = @import("../common/types.zig");
const Utils = @import("../common/utils.zig");
const Gamestate = @import("gamestate.zig");
const World = @import("world.zig");
const Systems = @import("Systems.zig");
const CameraManager = @import("cameraManager.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

var entity_allocator: std.mem.Allocator = undefined;

pub var entities: std.ArrayList(Entity.Entity) = undefined;
pub var inactiveEntities: std.ArrayList(Entity.Entity) = undefined;

pub var positionHash: std.AutoHashMap(Types.Vector2Int, usize) = undefined;
pub var idHash: std.AutoHashMap(u32, usize) = undefined;
pub var idInactiveHash: std.AutoHashMap(u32, usize) = undefined;

pub var playerID: u32 = undefined;

//TODO: add a hash map position => index into entities, gonna have to keep the indexes correct when removing from entities
//

pub fn init(allocator: std.mem.Allocator) void {
    entity_allocator = allocator;
    entities = std.ArrayList(Entity.Entity).init(allocator);
    inactiveEntities = std.ArrayList(Entity.Entity).init(allocator);
    positionHash = std.AutoHashMap(Types.Vector2Int, usize).init(allocator);
    idHash = std.AutoHashMap(u32, usize).init(allocator);
    idInactiveHash = std.AutoHashMap(u32, usize).init(allocator);
}

// just a helper funciton, returns the player so it can be used to fill into context
pub fn fillEntities() !void {
    const playerData = try Entity.PlayerData.init(entity_allocator);

    var player = try Entity.Entity.init(entity_allocator, Types.Vector2Int{ .x = 3, .y = 2 }, 1, Entity.EntityData{ .player = playerData });
    player.setTextureID(206);
    playerID = player.id;

    const pup_pos = Types.Vector2Int{ .x = 1, .y = 1 };
    var puppet = try Entity.Entity.init(entity_allocator, pup_pos, 1.0, Entity.EntityData{ .puppet = .{ .deployed = false } });
    puppet.visible = false;
    puppet.name = "Pamama";
    puppet.setTextureID(50);
    try player.data.player.puppets.append(puppet.id);

    try addActiveEntity(player);
    try addInactiveEntity(puppet);

    const pos = Types.Vector2Int{ .x = 5, .y = 15 };
    const enemy_tile = 55;
    const enemy_rect = Utils.makeSourceRect(enemy_tile);
    const enemy_goal = Types.Vector2Int.init(2, 2);

    var entity = try Entity.Entity.init(entity_allocator, pos, 1.0, Entity.EntityData{ .enemy = .{ .asd = true } });
    entity.goal = enemy_goal;

    entity.textureID = enemy_tile;
    entity.sourceRect = enemy_rect;

    const pos2 = Types.Vector2Int{ .x = 6, .y = 16 };
    var entity2 = try Entity.Entity.init(entity_allocator, pos2, 1.0, Entity.EntityData{ .enemy = .{ .asd = true } });
    entity2.textureID = enemy_tile;
    entity2.sourceRect = enemy_rect;

    const pos3 = Types.Vector2Int{ .x = 7, .y = 17 };
    var entity3 = try Entity.Entity.init(entity_allocator, pos3, 1.0, Entity.EntityData{ .enemy = .{ .asd = true } });
    entity3.textureID = enemy_tile;
    entity3.sourceRect = enemy_rect;

    try addActiveEntity(entity);
    try addActiveEntity(entity2);
    try addActiveEntity(entity3);
}

pub fn addActiveEntity(entity: Entity.Entity) !void {
    try entities.append(entity);
    try positionHash.put(entity.pos, entities.items.len - 1);
    try idHash.put(entity.id, entities.items.len - 1);
}

pub fn addInactiveEntity(entity: Entity.Entity) !void {
    try inactiveEntities.append(entity);
    try idInactiveHash.put(entity.id, inactiveEntities.items.len - 1);
}

pub fn activateEntity(id: u32) !void {
    const index = idInactiveHash.get(id) orelse return;

    const entity = getInactiveEntityIndex(index) orelse return;
    try removeInactiveEntity(id);
    try addActiveEntity(entity.*);
}

pub fn deactivateEntity(id: u32) !void {
    const index = idHash.get(id) orelse return;
    const entity = getEntityIndex(index) orelse return;
    try removeEntityID(id);
    try addInactiveEntity(entity.*);
}

pub fn removeEntityID(id: u32) !void {
    const entityIndex = idHash.get(id) orelse return;

    const entity = entities.swapRemove(entityIndex);
    _ = positionHash.remove(entity.pos);
    _ = idHash.remove(entity.id);

    // if we swapremoved any elemnt other than the last
    if (entityIndex < entities.items.len) {
        const swappedEntity = entities.items[entityIndex];
        try positionHash.put(swappedEntity.pos, entityIndex);
        try idHash.put(swappedEntity.id, entityIndex);
    }
}

pub fn removeInactiveEntity(id: u32) !void {
    const entityIndex = idInactiveHash.get(id) orelse return;

    const entity = inactiveEntities.swapRemove(entityIndex);
    _ = idInactiveHash.remove(entity.id);

    // if we swapremoved any elemnt other than the last
    if (entityIndex < inactiveEntities.items.len) {
        const swappedEntity = inactiveEntities.items[entityIndex];
        try idInactiveHash.put(swappedEntity.id, entityIndex);
    }
}

pub fn moveEntityHash(from: Types.Vector2Int, to: Types.Vector2Int) !void {
    const keyValue = positionHash.fetchRemove(from);
    if (keyValue) |kv| {
        try positionHash.put(to, kv.value);
    }
}

pub fn draw() void {
    for (entities.items) |*e| {
        if (Types.vector3IntCompare(e.worldPos, World.currentLevel)) {
            e.draw();
        }
    }
}

pub fn allPlayerUnitsTurnTaken() bool {
    var turnTaken = true;
    for (entities.items) |e| {
        if (e.data == .player or e.data == .puppet) {
            if (!e.turnTaken) {
                turnTaken = false;
            }
        }
    }
    return turnTaken;
}

pub fn allEnemiesTurnTaken() bool {
    var turnTaken = true;
    for (entities.items) |entity| {
        if (entity.data == .enemy and !entity.turnTaken) {
            turnTaken = false;
        }
    }
    return turnTaken;
}

pub fn getPlayer() *Entity.Entity {
    const playerIndex = idHash.get(playerID) orelse unreachable;
    return &entities.items[playerIndex];
}

pub fn getEnemies() []*Entity.Entity {}

pub fn getPuppets() []*Entity.Entity {
    //return &entities.items[PLAYER_INDEX];
}

pub fn getEntityID(id: u32) ?*Entity.Entity {
    const entityIndex = idHash.get(id) orelse return null;
    return &entities.items[entityIndex];
}

pub fn getInactiveEntityID(id: u32) ?*Entity.Entity {
    const entityIndex = idInactiveHash.get(id) orelse return null;
    return &inactiveEntities.items[entityIndex];
}

pub fn getEntityByPos(pos: Types.Vector2Int, worldPos: Types.Vector3Int) ?*Entity.Entity {
    for (entities.items) |*e| {
        if (Types.vector2IntCompare(e.pos, pos) and Types.vector3IntCompare(e.worldPos, worldPos)) {
            return e;
        }
    }
    return null;
}

pub fn filterEntityByPos(entities_: std.ArrayList(Entity.Entity), pos: Types.Vector2Int, worldPos: Types.Vector3Int) ?*Entity.Entity {
    for (entities_.items) |*e| {
        if (Types.vector2IntCompare(e.pos, pos) and Types.vector3IntCompare(e.worldPos, worldPos)) {
            return e;
        }
    }
    return null;
}

pub fn resetTurnFlags() void {
    for (entities.items) |*entity| {
        entity.hasMoved = false;
        entity.hasAttacked = false;
        entity.turnTaken = false;
        entity.movedDistance = 0;
    }
}

pub fn deactivatePuppets() !void {
    const player = getPlayer();
    for (player.data.player.puppets.items) |id| {
        try deactivateEntity(id);
    }
}

pub fn getEntityIndex(index: usize) ?*Entity.Entity {
    if (index >= entities.items.len) {
        return null;
    }

    return &entities.items[index];
}

pub fn getInactiveEntityIndex(index: usize) ?*Entity.Entity {
    if (index >= inactiveEntities.items.len) {
        return null;
    }

    return &inactiveEntities.items[index];
}
