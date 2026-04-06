const std = @import("std");
const Entity = @import("entity.zig");
const EntityManager = @import("entityManager.zig");
const World = @import("world.zig");
const Types = @import("../common/types.zig");
const Utils = @import("../common/utils.zig");
const rl = @import("raylib");

pub fn checkCombatStart(player: *Entity.Entity) bool {
    var iterator = EntityManager.activeConstIterator(0);
    while (iterator.next()) |e| {
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

pub fn closestPos(from: Types.Vector2Int, to: []Types.Vector2Int) ?Types.Vector2Int {
    var closestTile: ?Types.Vector2Int = null;
    var closestDistance: u32 = std.math.maxInt(u32);

    for (to) |toPos| {
        const distance = Types.vector2IntDistance(from, toPos);
        if (distance < closestDistance) {
            closestDistance = distance;
            closestTile = toPos;
        }
    }

    return closestTile;
}

pub fn isLosFree(from: Types.Vector2Int, to: Types.Vector2Int, worldPos: Types.Vector3Int) bool {
    const level = World.getLevelAt(worldPos) orelse return false;
    const grid = level.grid;

    var currentPos = from;

    const dx = @as(i32, @intCast(@abs(to.x - from.x)));
    const dy = @as(i32, @intCast(@abs(to.y - from.y)));

    const stepX: i32 = if (from.x < to.x) 1 else if (from.x > to.x) -1 else 0;
    const stepY: i32 = if (from.y < to.y) 1 else if (from.y > to.y) -1 else 0;

    var err: i32 = dx - dy;

    while (true) {
        if (Types.vector2IntCompare(currentPos, to)) {
            return true;
        }

        const tile = Utils.getTilePos(grid, currentPos) orelse return false;

        if (tile.solid) {
            return false;
        }

        if (tile.entity != null and !Types.vector2IntCompare(currentPos, from)) {
            return false;
        }

        const e2 = err * 2;

        if (e2 > -dy) {
            err -= dy;
            currentPos.x += stepX;
        }

        if (e2 < dx) {
            err += dx;
            currentPos.y += stepY;
        }
    }
}
