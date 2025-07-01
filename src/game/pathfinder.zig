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
    nodes: std.ArrayList(Node),
    currIndex: usize,
};

pub const Pathfinder = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !*Pathfinder {
        const pathfinder = try allocator.create(Pathfinder);
        pathfinder.* = .{
            .allocator = allocator,
        };
        return pathfinder;
    }

    pub fn findPath(this: *Pathfinder, grid: []Level.Tile, start: Types.Vector2Int, end: Types.Vector2Int) ?Path {
        _ = this;
        _ = grid;
        _ = start;
        _ = end;

        open_list = std.ArrayList(Node).init(this.allocator);
        closed_list = std.ArrayList(Node).init(this.allocator);

        //TODO: finish
        return null;
    }
};
