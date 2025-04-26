const std = @import("std");

const EntityType = enum {
    Player,
    Enemy,
    Item,
};

pub const Entity = union(EntityType) {
    Player: EntityPlayer,
    Enemy: EntityEnemy,
    Item: EntityItem,
};

const EntityPlayer = struct {
    health: i32,
};

const EntityEnemy = struct {
    health: i32,
};

const EntityItem = struct {
    health: i32,
};
