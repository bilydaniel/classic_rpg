const std = @import("std");
const Pathfinder = @import("../game/pathfinder.zig");
const Types = @import("../common/types.zig");
const Player = @import("../entities/player.zig");

const EntityType = enum {
    Player,
    Enemy,
    Item,
};

pub const Entity = union(EntityType) {
    Player: Player.Player,
    Enemy: EntityEnemy,
    Item: EntityItem,
};

pub const EntityEnemy = struct {
    pos: Types.Vector2Int,
    path: ?Pathfinder.Path,
    health: i32,
    isAscii: bool,
    ascii: ?[2]u8,
    movementCooldown: f32,

    pub fn init(allocator: std.mem.Allocator, pos: Types.Vector2Int) !*EntityEnemy {
        const entity = try allocator.create(EntityEnemy);
        entity.* = .{
            .pos = pos,
            .path = null,
            .health = 10,
            .isAscii = true,
            .ascii = .{ 'c', 0 },
            .movementCooldown = 0,
        };
        return entity;
    }
};

const EntityItem = struct {};

const Common = struct {};
