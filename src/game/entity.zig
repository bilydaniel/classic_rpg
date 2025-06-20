const std = @import("std");
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

const EntityEnemy = struct {
    health: i32,
};

const EntityItem = struct {};

const Common = struct {};
