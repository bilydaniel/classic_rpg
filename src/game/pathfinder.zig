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
    nodes: std.ArrayList(Types.Vector2Int),
    currIndex: usize,

    pub fn init(allocator: std.mem.Allocator) Path {
        return Path{
            .nodes = std.ArrayList(Types.Vector2Int).init(allocator),
            .currIndex = 0,
        };
    }
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
            const current_node = lowestF(open_list);
            _ = open_list.swapRemove(current_node.index);

            try closed_list.append(current_node.node.*);

            if (Types.vector2IntCompare(current_node.node.pos, end)) {
                const path = try this.reconstructPath(current_node.node);
                print_path(path);
                //TODO: TEST
                return path;
            }

            const neighbours = Systems.neighboursAll(start);

            for (neighbours) |neighbour| {
                const neigh = neighbour orelse continue;
                if (!Systems.canMove(grid, neigh)) {
                    continue;
                }

                if (findNode(closed_list, neigh)) |_| {
                    continue;
                }

                const new_g = current_node.node.g + 1.0; //TODO: add tile movement cost
                _ = new_g;

                if (findNode(open_list, neigh)) |found_node| {
                    if (new_g < found_node.node.g) {
                        open_list.items[found_node.index].g = new_g;
                        open_list.items[found_node.index].f = new_g + found_node.node.h;
                        open_list.items[found_node.index].parent = current_node;
                    }
                } else {}
            }

            //getTilePos(grid, result_pos)

            //try open_list.append(neighbours);
        }

        return null;
    }

    pub fn reconstructPath(this: *Pathfinder, node: *Node) !Path {
        var path = Path.init(this.allocator);
        var temp_path = Path.init(this.allocator);
        defer temp_path.nodes.deinit();

        var current: ?*Node = node;
        while (current) |current_node| {
            try temp_path.nodes.append(current_node.pos);
            current = current_node.parent;
        }

        var i = temp_path.nodes.items.len - 1;
        while (i >= 0) {
            try path.nodes.append(temp_path.nodes.items[i]);
            i -= 1;
        }
        return path;
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

pub fn print_path(path: Path) void {
    for (path.nodes.items) |node| {
        std.debug.print("{}\n", .{node});
    }
}

pub fn findNode(list: std.ArrayList(Node), pos: Types.Vector2Int) ?NodeIndex {
    for (list.items, 0..) |node, index| {
        if (Types.vector2IntCompare(node.pos, pos)) {
            return NodeIndex{ .index = index, .node = &list.items[index] };
        }
    }
    return null;
}
