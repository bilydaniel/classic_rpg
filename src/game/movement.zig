const std = @import("std");
const Entity = @import("entity.zig");
const World = @import("world.zig");
const Level = @import("level.zig");
const Types = @import("../common/types.zig");
const Utils = @import("../common/utils.zig");
const EntityManager = @import("entityManager.zig");
const Config = @import("../common/config.zig");

pub fn canMove(pos: Types.Vector2Int, grid: []Level.Tile, entities: std.ArrayList(Entity.Entity)) bool {
    const pos_index = Utils.posToIndex(pos);
    if (pos_index) |index| {
        if (index < grid.len) {
            if (grid[index].solid) {
                //TODO: probably gonna add something like walkable
                return false;
            }
        }
    }

    const entity = EntityManager.filterEntityByPos(entities, pos, World.currentLevel);
    if (entity == null) {
        return true;
    }

    return false;
}

pub fn getAvailableTileAround(pos: Types.Vector2Int) ?Types.Vector2Int {
    if (canMove(pos)) {
        return pos;
    }

    const neighbours = neighboursAll(pos);
    for (neighbours) |neighbor| {
        const neigh = neighbor orelse continue;
        if (canMove(neigh)) {
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
