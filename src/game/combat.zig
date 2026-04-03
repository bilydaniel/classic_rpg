const std = @import("std");
const Entity = @import("entity.zig");
const EntityManager = @import("entityManager.zig");
const World = @import("world.zig");
const Types = @import("../common/types.zig");
const Utils = @import("../common/utils.zig");
const rl = @import("raylib");

pub fn checkCombatStart(player: *Entity.Entity, entities: EntityManager.Entities) bool {
    var iterator = entities.constIterator(0);
    while (iterator.next()) |slot| {
        const e = slot.entity;
        if (e.data == .enemy) {
            //TODO: remove prints
            // std.debug.print("player: {}\n", .{player.worldPos});
            // std.debug.print("e: {}\n", .{e.worldPos});
            // std.debug.print("***************\n", .{});
            if (Types.vector3IntCompare(player.worldPos, e.worldPos)) {
                const distance = Types.vector2IntDistance(player.pos, e.pos);
                if (distance < 3) {
                    return true;
                }
            }
        }
    }
    return false;
}

pub fn attack(entity: *Entity.Entity, attackedEntity: ?*Entity.Entity) !void {
    if (attackedEntity) |attacked_entity| {
        try attacked_entity.damage(entity.attack);
    } else {}
}

pub fn canAttack(from: *Entity.Entity, to: *Entity.Entity) bool {
    const distance = Types.vector2IntDistance(from.pos, to.pos);
    if (distance <= from.attackDistance) {
        return true;
    }
    return false;
}

pub fn closestEntity(from: Types.Vector2Int, to: []*Entity.Entity) ?*Entity.Entity {
    var closestEnt: ?*Entity.Entity = null;
    var closestDistance: u32 = std.math.maxInt(u32);

    // std.debug.print("to_entities: {any}\n", .{to});
    // std.debug.print("to_entities_len: {any}\n", .{to.len});

    for (to) |toEntity| {
        //std.debug.print("toEntity: {s}\n", .{toEntity.name});
        const distance = Types.vector2IntDistance(from, toEntity.pos);
        //std.debug.print("distance: {}\n", .{distance});
        //std.debug.print("closest_distance: {}\n", .{closestDistance});
        if (distance < closestDistance) {
            closestDistance = distance;
            closestEnt = toEntity;
        }
    }

    return closestEnt;
}

//pub fn closestPos(from: Types.Vector2Int, to: []Types.Vector2Int) ?Types.Vector2Int {
// var closestEnt: ?*Entity.Entity = null;
// var closestDistance: u32 = std.math.maxInt(u32);

// std.debug.print("to_entities: {any}\n", .{to});
// std.debug.print("to_entities_len: {any}\n", .{to.len});

//for (to) |toEntity| {
//std.debug.print("toEntity: {s}\n", .{toEntity.name});
//const distance = Types.vector2IntDistance(from, toEntity.pos);
// std.debug.print("distance: {}\n", .{distance});
// std.debug.print("closest_distance: {}\n", .{closestDistance});
// if (distance < closestDistance) {
//     closestDistance = distance;
//     closestEnt = toEntity;
// }
//}

//return closestEnt;
//}

pub fn isLosFree(from: Types.Vector2Int, to: Types.Vector2Int, worldPos: Types.Vector3Int) bool {
    //TODO: debug this, no idea if it works
    const level = World.getLevelAt(worldPos) orelse return false;
    const grid = level.grid;

    var currentPos = from;
    const dPos = Types.Vector2Int.init(@intCast(@abs(to.x - currentPos.x)), @intCast(@abs(to.y - currentPos.y)));

    var stepX: i32 = 0;
    if (from.x < to.x) {
        stepX = 1;
    } else {
        stepX = -1;
    }

    var stepY: i32 = 0;
    if (from.y < to.y) {
        stepY = 1;
    } else {
        stepY = -1;
    }

    var e: i32 = 0;
    if (dPos.x > dPos.y) {
        e = @divTrunc(dPos.x, 2);
    } else {
        e = @divTrunc(-dPos.y, 2);
    }
    var e2: i32 = 0;

    while (true) {
        e2 = e;
        if (e2 > -dPos.x) {
            e -= @as(i32, @intCast(dPos.y));
            currentPos.x += stepX;
        }
        if (e2 < @as(i32, @intCast(dPos.x))) {
            e += @as(i32, @intCast(dPos.x));
            currentPos.y += stepY;
        }

        if (currentPos.x == to.x and currentPos.y == to.y) {
            return true;
        }

        const tileIndex = Utils.posToIndex(currentPos) orelse return false;

        if (grid[tileIndex].solid) {
            return false;
        }

        if (grid[tileIndex].entity != null) {
            return false;
        }
    }
}
