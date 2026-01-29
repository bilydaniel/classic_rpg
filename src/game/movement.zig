const std = @import("std");
const Entity = @import("entity.zig");
const World = @import("world.zig");
const Level = @import("level.zig");
const Types = @import("../common/types.zig");
const Utils = @import("../common/utils.zig");
const EntityManager = @import("entityManager.zig");
const Config = @import("../common/config.zig");
const Game = @import("game.zig");
const Pathfinder = @import("../game/pathfinder.zig");

pub fn updateEntity(entity: *Entity.Entity, game: *Game.Game) !void {
    if (entity.path == null and entity.goal != null) {
        const newPath = try Pathfinder.findPath(entity.pos, entity.goal.?);
        if (newPath) |new_path| {
            entity.setNewPath(new_path);
            entity.stuck = 0;
        } else {
            entity.stuck += 1;
            return;
        }
    }

    if (entity.hasMoved or entity.path == null) {
        return;
    }

    if (entity.inCombat) {
        entity.movementCooldown += game.delta;
        if (entity.movementCooldown < Config.movement_animation_duration_in_combat) {
            return;
        }
        entity.movementCooldown = 0;
    }

    const path = &entity.path.?;
    const nextIndex = path.currIndex + 1;

    //TODO: @remove
    if (entity.data == .player) {
        std.debug.print("p: {?}\n", .{path.nodes.items.len});
        std.debug.print("i: {}\n", .{nextIndex});
        std.debug.print("g: {?}\n", .{entity.goal});
    }
    if (nextIndex >= path.nodes.items.len) {
        if (entity.data == .player) {
            std.debug.print("reseting...\n", .{});
        }
        entity.removePathGoal();
        entity.finishMovement();
        return;
    }

    const new_pos = path.nodes.items[nextIndex];
    const new_pos_entity = EntityManager.getEntityByPos(new_pos, World.currentLevel);

    // position has entity, recalculate
    if (new_pos_entity) |_| {
        entity.removePath();
        entity.stuck += 1;
        return;
    }

    entity.move(new_pos);
    entity.stuck = 0;
    path.currIndex = nextIndex;

    if (entity.inCombat) {
        entity.movedDistance += 1;
        if (entity.movedDistance >= entity.movementDistance) {
            entity.finishMovement();
            entity.removePath();
        }
    } else {
        entity.hasMoved = true;
    }
}

pub fn canMove(pos: Types.Vector2Int, grid: []Level.Tile, entitiesHash: *const std.AutoHashMap(Types.Vector2Int, usize)) bool {
    const pos_index = Utils.posToIndex(pos);
    if (pos_index) |index| {
        if (index < grid.len and grid[index].solid) {
            //TODO: probably gonna add something like walkable
            return false;
        }
    }

    const entityID = entitiesHash.get(pos);
    if (entityID == null) {
        return true;
    }

    return false;
}

pub fn getAvailableTileAround(pos: Types.Vector2Int, grid: []Level.Tile, entities: *const std.AutoHashMap(Types.Vector2Int, usize)) ?Types.Vector2Int {
    if (canMove(pos, grid, entities)) {
        return pos;
    }

    const neighbours = neighboursAll(pos);
    for (neighbours) |neighbor| {
        const neigh = neighbor orelse continue;
        if (canMove(neigh, grid, entities)) {
            return neigh;
        }
    }

    return null;
}

pub fn neighboursAll(pos: Types.Vector2Int) [8]?Types.Vector2Int {
    var result: [8]?Types.Vector2Int = undefined;

    var count: usize = 0;
    const sides = [_]i32{ -1, 0, 1 };
    for (sides) |y_side| {
        for (sides) |x_side| {
            if (x_side == 0 and y_side == 0) {
                continue;
            }
            const dif_pos = Types.Vector2Int.init(x_side, y_side);
            const result_pos = Types.vector2IntAdd(pos, dif_pos);
            if (result_pos.x >= 0 and result_pos.y >= 0 and result_pos.x < Config.level_width and result_pos.y < Config.level_height) {
                result[count] = result_pos;
            }
            count += 1;
        }
    }
    return result;
}
