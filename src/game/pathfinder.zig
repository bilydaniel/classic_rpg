const Types = @import("../common/types.zig");
const Systems = @import("Systems.zig");
const std = @import("std");
const Level = @import("level.zig");

pub const NodeIndex = struct {
    node: *Node,
    index: usize,
};

pub const Node = struct {
    pos: Types.Vector2Int,
    parent: ?*Node,
    f: f32,
    g: f32,
    h: f32,

    pub fn init(pos: Types.Vector2Int, parent: ?*Node, g: f32, h: f32) Node {
        return Node{
            .pos = pos,
            .parent = parent,
            .f = g + h,
            .g = g,
            .h = h,
        };
    }
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

    pub fn findPath(this: *Pathfinder, grid: []Level.Tile, start: Types.Vector2Int, end: Types.Vector2Int) !?Path {
        var open_list = std.ArrayList(Node).init(this.allocator);
        defer open_list.deinit();

        var closed_list = std.ArrayList(Node).init(this.allocator);
        defer closed_list.deinit();

        try open_list.append(Node.init(start, null, 0, heuristic(start, end)));

        while (open_list.items.len > 0) {
            //find lovest f
            const lowest_node = lowestF(open_list);
            std.debug.print("lowest_node: {}", .{lowest_node});
            // remove open
            _ = open_list.swapRemove(0);
            // add closed
            // check end
            // get neighbours
            const neighbours = Systems.gridNeighboursAll(grid, start);
            std.debug.print("neighbours: {any}", .{neighbours});
            //try open_list.append(neighbours);
        }

        return null;
    }
};

pub fn lowestF(list: std.ArrayList(Node)) NodeIndex {
    var lowest = NodeIndex{ .index = 0, .node = &list.items[0] };
    for (list.items[0..], 0..) |*item, i| {
        if (lowest.node.f > item.f) {
            lowest.node = item;
            lowest.index = i;
        }
    }
    return lowest;
}
pub fn heuristic(start: Types.Vector2Int, end: Types.Vector2Int) f32 {
    return @floatFromInt(@abs(start.x - end.x) + @abs(start.y - end.y));
}
