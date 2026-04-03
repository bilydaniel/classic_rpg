const std = @import("std");
const Entity = @import("entity.zig");
const World = @import("world.zig");
const Level = @import("level.zig");
const Types = @import("../common/types.zig");
const Utils = @import("../common/utils.zig");
const EntityManager = @import("entityManager.zig");
const TurnManager = @import("turnManager.zig");
const Config = @import("../common/config.zig");
const Game = @import("game.zig");
const Combat = @import("combat.zig");
const Pathfinder = @import("../game/pathfinder.zig");

var allocator: std.mem.Allocator = undefined;

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
}

pub fn updateEntity(entity: *Entity.Entity, game: *Game.Game, level: *Level.Level) !void {
    //TODO: @fix entities dont move when they cant find a path somewhere but they arent really blocked, its blocked very far away from them
    //TODO: @continue @fix @finish, remove entities from findPath, handle entities bumping into each other here
    //TODO: https://claude.ai/chat/dfcf88fa-e705-4d82-b2a0-dc0d537b938c
    const grid = level.grid;
    if (entity.path == null and entity.goal != null) {
        const newPath = try Pathfinder.findPath(entity.pos, entity.goal.?.pos, level);
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

    if (nextIndex >= path.nodes.items.len) {
        entity.removePathGoal();
        entity.finishMovement();
        TurnManager.updatingEntity = null;
        return;
    }

    const new_pos = path.nodes.items[nextIndex];

    const tileIndex = Utils.posToIndex(new_pos);
    if (tileIndex) |tile_index| {
        const new_pos_entity = grid[tile_index].entity;

        // position has entity, recalculate
        if (new_pos_entity) |_| {
            //TODO: @continu, wait or sidestep
            entity.removePath();
            entity.stuck += 1;
            return;
        }
    }

    try entity.move(level, new_pos);
    entity.stuck = 0;
    path.currIndex = nextIndex;

    if (entity.inCombat) {
        entity.movedDistance += 1;
        if (entity.movedDistance >= entity.movementDistance) {
            entity.finishMovement();
            entity.removePath();
            TurnManager.updatingEntity = null;
        }
    } else {
        entity.hasMoved = true;
    }
}

pub fn canMove(pos: Types.Vector2Int, grid: []Level.Tile) bool {
    const pos_index = Utils.posToIndex(pos);
    if (pos_index) |index| {
        if (grid[index].solid) {
            //TODO: probably gonna add something like walkable
            return false;
        }

        if (grid[index].entity != null) {
            return false;
        }
    }
    return true;
}

pub fn tilesAround(alloc: std.mem.Allocator, pos: Types.Vector2Int, distance: u32) !std.ArrayList(Types.Vector2Int) {
    //TODO: use arena
    var result: std.ArrayList(Types.Vector2Int) = .empty;

    const dist: i32 = @intCast(distance);
    var xOffset = -dist;
    var yOffset = -dist;
    while (yOffset <= distance) : (yOffset += 1) {
        xOffset = -dist;
        while (xOffset <= distance) : (xOffset += 1) {
            // ignore center
            if (yOffset == 0 and xOffset == 0) {
                continue;
            }

            const newPos = Types.Vector2Int.init(pos.x + xOffset, pos.y + yOffset);
            if (newPos.x > 0 and newPos.y > 0 and newPos.x < Config.level_width and newPos.y < Config.level_height) {
                try result.append(alloc, newPos);
            }
        }
    }

    return result;
}

pub fn getClosestAttackPositionAround(alloc: std.mem.Allocator, attackingEntity: *Entity.Entity, attackedLocation: Types.Location, grid: Level.Grid) !?Types.Vector2Int {
    var tiles = try tilesAround(alloc, attackedLocation.pos, attackingEntity.attackDistance);
    for (tiles.items, 0..) |tile, i| {
        if (!canMove(tile, grid)) {
            _ = tiles.swapRemove(i);
        }

        if (!Combat.isLosFree(tile, attackedLocation.pos, attackedLocation.worldPos)) {
            _ = tiles.swapRemove(i);
        }
    }

    //TODO: @finish @continue
    //const resultTile = Combat.closestPos(attackingEntity.pos, tiles.items);

    //std.debug.print("tiles: {}\n", .{resultTile});

    //return resultTile;
    return null;
}

pub fn getAvailableTileAround(location: Types.Location, grid: []Level.Tile, entities: Types.PositionHash) ?Types.Vector2Int {
    if (canMove(location, grid, entities)) {
        std.debug.print("CAN_MOVE\n", .{});
        return location.pos;
    }

    const neighbours = neighboursAll(location.pos);
    for (neighbours) |neighbor| {
        const neigh = neighbor orelse continue;
        std.debug.print("neigh: {}\n", .{neigh});
        const loc = Types.Location.init(location.worldPos, neigh);
        if (canMove(loc, grid, entities)) {
            std.debug.print("returning: {}\n", .{loc});
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
            } else {
                result[count] = null;
            }
            count += 1;
        }
    }
    return result;
}

pub fn boundryTransition(currentLocation: Types.Location, newLocation: Types.Location) Types.Location {
    //TODO: no transitins during combat
    var tmpLocation = newLocation;
    var locationResult = newLocation;
    const pos = newLocation.pos;

    if (pos.x < 0) {
        tmpLocation.worldPos.x -= 1;
        const level = World.getLevelAt(tmpLocation.worldPos);
        if (level) |_| {
            tmpLocation.pos.x = Config.level_width - 1;
            locationResult = tmpLocation;
        } else {
            locationResult = currentLocation;
        }
    }

    if (pos.x >= Config.level_width) {
        tmpLocation.worldPos.x += 1;
        const level = World.getLevelAt(tmpLocation.worldPos);
        if (level) |_| {
            tmpLocation.pos.x = 0;
            locationResult = tmpLocation;
        } else {
            locationResult = currentLocation;
        }
    }

    if (pos.y < 0) {
        tmpLocation.worldPos.y += 1;
        const level = World.getLevelAt(tmpLocation.worldPos);
        if (level) |_| {
            tmpLocation.pos.y = Config.level_height - 1;
            locationResult = tmpLocation;
        } else {
            locationResult = currentLocation;
        }
    }

    if (pos.y >= Config.level_height) {
        tmpLocation.worldPos.y -= 1;
        const level = World.getLevelAt(tmpLocation.worldPos);
        if (level) |_| {
            tmpLocation.pos.y = 0;
            locationResult = tmpLocation;
        } else {
            locationResult = currentLocation;
        }
    }

    return locationResult;
}

pub fn staircaseTransition(newLocation: Types.Location, level: *Level.Level) Types.Location {
    //TODO: no transitins during combat
    const tile = Utils.getTilePos(level.grid, newLocation.pos);
    var zDelta: i32 = 0;
    if (tile) |t| {
        switch (t.tileType) {
            .staircase_up => {
                zDelta = 1;
            },
            .staircase_down => {
                zDelta = -1;
            },
            else => {
                return newLocation;
            },
        }
    }
    const worldPosDelta = Types.Vector3Int.init(0, 0, zDelta);

    var tmpLocation = newLocation;

    const player = EntityManager.getPlayer();

    tmpLocation.worldPos = Types.vector3IntAdd(player.worldPos, worldPosDelta);

    const newLevel = World.getLevelAt(tmpLocation.worldPos);
    if (newLevel == null) {
        //TODO: put a log out to player that the path is blocked or something
        std.debug.print("NO LEVEL IN THAT WAY", .{});
        return newLocation;
    }

    return tmpLocation;
}

pub fn isTileWalkable(grid: []Level.Tile, pos: Types.Vector2Int) bool {
    const index = Utils.posToIndex(pos) orelse return false;
    const tile = grid[index];

    if (tile.solid) {
        return false;
    }

    if (!tile.walkable) {
        return false;
    }

    return true;
}
