const Types = @import("../common/types.zig");
const Systems = @import("Systems.zig");
const Movement = @import("movement.zig");
const std = @import("std");
const Level = @import("level.zig");
const Entity = @import("entity.zig");
const Config = @import("../common/config.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const NodeIndex = struct {
    node: *Node,
    index: usize,
};

pub const Node = struct {
    pos: Types.Vector2Int,
    parent: ?usize,
    f: f32,
    g: f32,
    h: f32,

    pub fn init(pos: Types.Vector2Int, parent: ?usize, g: f32, h: f32) Node {
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

    pub fn init() Path {
        return Path{
            .nodes = .empty,
            .currIndex = 0,
        };
    }

    pub fn deinit(this: *Path) void {
        this.nodes.deinit(allocator);
    }
};

var allocator: std.mem.Allocator = undefined;

pub fn init(alloc: std.mem.Allocator) !void {
    allocator = alloc;
}

pub fn findPath(start: Types.Vector2Int, end: Types.Vector2Int, level: Level.Level, entities: *const Types.PositionHash) !?Path {
    //TODO: check the code, made by ai
    //TODO: different pathfinding for different enemy types??
    var open_list: std.ArrayList(Node) = .empty;
    defer open_list.deinit(allocator);

    var closed_list: std.ArrayList(Node) = .empty;
    defer closed_list.deinit(allocator);

    try open_list.append(allocator, Node.init(start, null, 0, heuristic(start, end)));

    while (open_list.items.len > 0) {
        const current_index = lowestF(open_list);
        const current_open_node = open_list.swapRemove(current_index);

        try closed_list.append(allocator, current_open_node);
        var current_node = closed_list.getLast();
        const current_node_index = closed_list.items.len - 1;

        if (Types.vector2IntCompare(current_node.pos, end)) {
            const path = try reconstructPath(closed_list, &current_node);
            return path;
        }

        const neighbours = Movement.neighboursAll(current_node.pos);

        for (neighbours) |neighbour| {
            const neigh = neighbour orelse continue;
            const neighLoc = Types.Location.init(level.worldPos, neigh);
            if (!Movement.canMove(neighLoc, level.grid, entities)) {
                continue;
            }

            if (findNode(closed_list, neigh)) |_| {
                continue;
            }

            const new_g = current_node.g + 1.0; //TODO: add tile movement cost

            if (findNode(open_list, neigh)) |found_node| {
                if (new_g < found_node.node.g) {
                    open_list.items[found_node.index].g = new_g;
                    open_list.items[found_node.index].f = new_g + found_node.node.h;
                    open_list.items[found_node.index].parent = current_node_index;
                }
            } else {
                try open_list.append(allocator, Node.init(neigh, current_node_index, new_g, heuristic(neigh, end)));
            }
        }
    }

    return null;
}

pub fn reconstructPath(closed_list: std.ArrayList(Node), node: *Node) !Path {
    var path = Path.init();
    var temp_path = Path.init();
    defer temp_path.nodes.deinit(allocator);

    var current: ?*Node = node;
    while (current) |current_node| {
        try temp_path.nodes.append(allocator, current_node.pos);
        const parentIndex = current_node.parent;

        if (parentIndex) |parent_index| {
            current = &closed_list.items[parent_index];
        } else {
            current = null;
        }
    }

    var i = temp_path.nodes.items.len;
    while (i > 0) {
        i -= 1;
        try path.nodes.append(allocator, temp_path.nodes.items[i]);
    }
    return path;
}

pub fn lowestF(list: std.ArrayList(Node)) usize {
    var lowest = NodeIndex{ .index = 0, .node = &list.items[0] };
    for (list.items[0..], 0..) |*item, i| {
        if (lowest.node.f > item.f) {
            lowest.node = item;
            lowest.index = i;
        }
    }
    return lowest.index;
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

pub fn printList(list: std.ArrayList(Node)) void {
    for (list.items) |item| {
        std.debug.print("\t{}\n", .{item.pos});
    }
    std.debug.print("*********************\n", .{});
}

//TODO: make this a gameplay mechanic, you can find an item that shows enemy pathing?
pub fn drawPath(path: Path) void {
    if (Config.drawPathDebug) {
        for (path.nodes.items[path.currIndex..]) |value| {
            const pos = Types.vector2IntToPixels(value);
            c.DrawRectangleLines(pos.x, pos.y, Config.tile_width, Config.tile_height, c.RED);
        }

        const current = Types.vector2IntToPixels(path.nodes.items[path.currIndex]);
        c.DrawRectangleLines(current.x, current.y, Config.tile_width, Config.tile_height, c.GREEN);
    }
}
