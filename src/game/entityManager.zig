const std = @import("std");
const Game = @import("../game/game.zig");
const AssetManager = @import("assetManager.zig");
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

pub var positionHash: Types.PositionHash = undefined;
pub var idHash: Types.IdHash = undefined;

pub var playerID: u32 = undefined;

pub var spawnQueue: std.ArrayList(Entity.Entity) = undefined;
pub var despawnQueue: std.ArrayList(u32) = undefined;

pub fn init(allocator: std.mem.Allocator) void {
    entity_allocator = allocator;

    entities = std.ArrayList(Entity.Entity).empty;

    positionHash = Types.PositionHash.init(allocator);
    idHash = Types.IdHash.init(allocator);

    spawnQueue = std.ArrayList(Entity.Entity).empty;
    despawnQueue = std.ArrayList(u32).empty;
    //TODO: uncomment, testing for now if dangling pointers happen
    //entities.ensureTotalCapacity(allocator, 256);
}

//TODO: @finish @continue
pub fn spawn() !void {}
pub fn despawn() !void {
    for (despawnQueue.items) |id| {
        _ = id;
    }
}

// just a helper funciton, returns the player so it can be used to fill into context
pub fn fillEntities() !void {
    const playerData = try Entity.PlayerData.init(entity_allocator);

    var player = try Entity.Entity.init(entity_allocator, Types.Vector2Int{ .x = 3, .y = 2 }, 1, Entity.EntityData{ .player = playerData });
    player.setTextureID(AssetManager.TileNames.player);
    playerID = player.id;

    const pup_pos = Types.Vector2Int{ .x = 1, .y = 1 };
    var puppet = try Entity.Entity.init(entity_allocator, pup_pos, 1.0, Entity.EntityData{ .puppet = .{ .deployed = false } });
    puppet.visible = false;
    puppet.name = "Pamama";
    puppet.setTextureID(AssetManager.TileNames.puppet_1);
    try player.data.player.puppets.append(entity_allocator, puppet.id);

    try addActiveEntity(player);
    try addInactiveEntity(puppet);

    const pos = Types.Vector2Int{ .x = 5, .y = 15 };
    const enemy_tile = AssetManager.TileNames.robot_1;
    const enemy_goal = Types.Vector2Int.init(2, 2);

    var entity = try Entity.Entity.init(entity_allocator, pos, 1.0, Entity.EntityData{ .enemy = .{ .asd = true } });
    entity.goal = enemy_goal;

    entity.setTextureID(enemy_tile);

    const pos2 = Types.Vector2Int{ .x = 6, .y = 16 };
    var entity2 = try Entity.Entity.init(entity_allocator, pos2, 1.0, Entity.EntityData{ .enemy = .{ .asd = true } });
    entity2.setTextureID(enemy_tile);

    const pos3 = Types.Vector2Int{ .x = 7, .y = 17 };
    var entity3 = try Entity.Entity.init(entity_allocator, pos3, 1.0, Entity.EntityData{ .enemy = .{ .asd = true } });
    entity3.setTextureID(enemy_tile);

    try addActiveEntity(entity);
    try addActiveEntity(entity2);
    try addActiveEntity(entity3);
}

pub fn addActiveEntity(entity: Entity.Entity) !void {
    var e = entity;
    e.active = true;
    try entities.append(entity_allocator, e);
    try idHash.put(entity.id, entities.items.len - 1);

    const location = Types.Location.init(e.worldPos, e.pos);
    try positionHash.put(location, entities.items.len - 1);
}

pub fn addInactiveEntity(entity: Entity.Entity) !void {
    var e = entity;
    e.active = false;
    try entities.append(entity_allocator, e);
    try idHash.put(entity.id, entities.items.len - 1);
}

pub fn activateEntity(id: u32) !void {
    const index = idHash.get(id) orelse return;
    const entity = getEntityIndex(index) orelse return;
    entity.active = true;

    const location = Types.Location.init(entity.worldPos, entity.pos);
    try positionHash.put(location, index);
}

pub fn deactivateEntity(id: u32) !void {
    const index = idHash.get(id) orelse return;
    const entity = getEntityIndex(index) orelse return;
    entity.active = false;
    //TODO: check this, not sure if correct, tired
    const location = Types.Location.init(entity.worldPos, entity.pos);
    _ = positionHash.remove(location);
}

pub fn removeEntityID(id: u32) !void {
    const entityIndex = idHash.get(id) orelse return;

    const entity = entities.swapRemove(entityIndex);
    const location = Types.Location.init(entity.worldPos, entity.pos);
    _ = positionHash.remove(location);
    _ = idHash.remove(entity.id);

    // if we swapremoved any elemnt other than the last
    if (entityIndex < entities.items.len) {
        const swappedEntity = entities.items[entityIndex];
        const swappedLocation = Types.Location.init(swappedEntity.worldPos, swappedEntity.pos);
        try positionHash.put(swappedLocation, entityIndex);
        try idHash.put(swappedEntity.id, entityIndex);
    }
}

pub fn moveEntityHash(from: Types.Location, to: Types.Location) !void {
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
    const player = getPlayer();
    if (player.inCombat) {
        return player.turnTaken and player.allPupsTurnTaken();
    } else {
        return player.turnTaken;
    }
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

pub fn getEntityByPos(pos: Types.Vector2Int, worldPos: Types.Vector3Int) ?*Entity.Entity {
    //TODO: check if correct
    const location = Types.Location.init(worldPos, pos);
    const index = positionHash.get(location) orelse return null;
    return &entities.items[index];
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
