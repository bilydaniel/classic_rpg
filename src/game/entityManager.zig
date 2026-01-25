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

const PLAYER_INDEX = 0; //always 0

pub fn init(allocator: std.mem.Allocator) void {
    entity_allocator = allocator;
    entities = std.ArrayList(Entity.Entity).init(allocator);
}

// just a helper funciton, returns the player so it can be used to fill into context
pub fn fillEntities() !void {
    var playerData = try Entity.PlayerData.init(entity_allocator);

    const pup_pos = Types.Vector2Int{ .x = -1, .y = -1 };
    var puppet = try Entity.Entity.init(entity_allocator, pup_pos, 1.0, Entity.EntityData{ .puppet = .{ .deployed = false } }, "&");
    puppet.visible = false;
    puppet.name = "Pamama";
    puppet.setTextureID(50);
    try playerData.puppets.append(puppet.id);

    var player = try Entity.Entity.init(entity_allocator, Types.Vector2Int{ .x = 3, .y = 2 }, 1, Entity.EntityData{ .player = playerData }, "@");
    player.setTextureID(76);
    try addEntity(player);
    try addEntity(puppet);

    const pos = Types.Vector2Int{ .x = 5, .y = 15 };
    const enemy_tile = 55;
    const enemy_rect = Utils.makeSourceRect(enemy_tile);
    const enemy_goal = Types.Vector2Int.init(2, 2);

    var entity = try Entity.Entity.init(entity_allocator, pos, 1.0, Entity.EntityData{ .enemy = .{ .asd = true } }, "r");
    entity.goal = enemy_goal;

    entity.textureID = enemy_tile;
    entity.sourceRect = enemy_rect;

    const pos2 = Types.Vector2Int{ .x = 6, .y = 16 };
    var entity2 = try Entity.Entity.init(entity_allocator, pos2, 1.0, Entity.EntityData{ .enemy = .{ .asd = true } }, "r");
    entity2.textureID = enemy_tile;
    entity2.sourceRect = enemy_rect;

    const pos3 = Types.Vector2Int{ .x = 7, .y = 17 };
    var entity3 = try Entity.Entity.init(entity_allocator, pos3, 1.0, Entity.EntityData{ .enemy = .{ .asd = true } }, "r");
    entity3.textureID = enemy_tile;
    entity3.sourceRect = enemy_rect;

    try addEntity(entity);
    try addEntity(entity2);
    try addEntity(entity3);
}

pub fn addEntity(entity: Entity.Entity) !void {
    try entities.append(entity);
}

pub fn update(game: *Game.Game) !void {
    //TODO: make a turnManager??
    //TODO: order in combat
    //TODO: think combat updating through

    //TODO: when to switch current_turn to enemy?
    //gonna have to be more complicated than this
    if (Gamestate.currentTurn != .player and allEnemiesTurnTaken()) {
        Gamestate.switchTurn(.player);
        resetTurnFlags();
    }

    for (entities.items) |*entity| {
        try entity.update(game);
    }
}

pub fn draw() void {
    for (entities.items) |*e| {
        if (Types.vector3IntCompare(e.worldPos, World.currentLevel)) {
            e.draw();
        }
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
    return &entities.items[PLAYER_INDEX];
}

pub fn getEnemies() []*Entity.Entity {}

pub fn getPuppets() []*Entity.Entity {
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

pub fn getEntityByPos(pos: Types.Vector2Int, worldPos: Types.Vector3Int) ?*Entity.Entity {
    for (entities.items) |*e| {
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
    }
}
