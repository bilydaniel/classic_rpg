const Types = @import("../common/types.zig");
const std = @import("std");
const Level = @import("level.zig");

pub const Node = struct {
    f: f32,
    g: f32,
    h: f32,
    pos: Types.Vector2Int,
    parent: ?*Node,
};

pub const Path = struct {
    nodes: std.ArrayList(Types.Vector2Int),
    currIndex: usize,
};

pub const Pathfinder = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Pathfinder {
        return Pathfinder{
            .allocator = allocator,
        };
    }

    pub fn findPath(
        this: *Pathfinder,
        grid: []Level.Tile,
    ) ?Path {
        _ = this;
        _ = grid;
    }
};
