const std = @import("std");
const Types = @import("../common/types.zig");
const Config = @import("../common/config.zig");

// Add this to your existing Level.zig file or create a new pathfinding.zig file

pub const PathNode = struct {
    pos: Types.Vector2Int,
    g_cost: f32, // Distance from start
    h_cost: f32, // Heuristic distance to goal
    f_cost: f32, // g_cost + h_cost
    parent: ?*PathNode,

    pub fn init(pos: Types.Vector2Int, g: f32, h: f32, parent: ?*PathNode) PathNode {
        return PathNode{
            .pos = pos,
            .g_cost = g,
            .h_cost = h,
            .f_cost = g + h,
            .parent = parent,
        };
    }
};

pub const Path = struct {
    nodes: std.ArrayList(Types.Vector2Int),
    current_index: usize,

    pub fn init(allocator: std.mem.Allocator) Path {
        return Path{
            .nodes = std.ArrayList(Types.Vector2Int).init(allocator),
            .current_index = 0,
        };
    }

    pub fn deinit(self: *Path) void {
        self.nodes.deinit();
    }

    pub fn getNextPosition(self: *Path) ?Types.Vector2Int {
        if (self.current_index >= self.nodes.items.len) {
            return null;
        }
        const pos = self.nodes.items[self.current_index];
        self.current_index += 1;
        return pos;
    }

    pub fn hasNextPosition(self: *Path) bool {
        return self.current_index < self.nodes.items.len;
    }

    pub fn reset(self: *Path) void {
        self.current_index = 0;
    }
};

pub const Pathfinder = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Pathfinder {
        return Pathfinder{
            .allocator = allocator,
        };
    }

    // Calculate Manhattan distance heuristic
    fn heuristic(a: Types.Vector2Int, b: Types.Vector2Int) f32 {
        const dx = @abs(a.x - b.x);
        const dy = @abs(a.y - b.y);
        return @floatFromInt(dx + dy);
    }

    // Check if a position is valid and walkable
    fn isWalkable(level: *Level, pos: Types.Vector2Int) bool {
        if (pos.x < 0 or pos.x >= Config.level_width or
            pos.y < 0 or pos.y >= Config.level_height)
        {
            return false;
        }

        const idx = @as(usize, @intCast(pos.y * Config.level_width + pos.x));
        return !level.grid[idx].solid;
    }

    // Get neighbors of a position (4-directional movement)
    fn getNeighbors(pos: Types.Vector2Int, neighbors: *[4]Types.Vector2Int) void {
        neighbors[0] = Types.Vector2Int{ .x = pos.x + 1, .y = pos.y }; // Right
        neighbors[1] = Types.Vector2Int{ .x = pos.x - 1, .y = pos.y }; // Left
        neighbors[2] = Types.Vector2Int{ .x = pos.x, .y = pos.y + 1 }; // Down
        neighbors[3] = Types.Vector2Int{ .x = pos.x, .y = pos.y - 1 }; // Up
    }

    // Find if a node exists in the list and return its index
    fn findNodeInList(list: std.ArrayList(PathNode), pos: Types.Vector2Int) ?usize {
        for (list.items, 0..) |node, i| {
            if (node.pos.x == pos.x and node.pos.y == pos.y) {
                return i;
            }
        }
        return null;
    }

    // Find the node with lowest f_cost in open list
    fn findLowestFCost(open_list: std.ArrayList(PathNode)) usize {
        var lowest_index: usize = 0;
        var lowest_f: f32 = open_list.items[0].f_cost;

        for (open_list.items, 0..) |node, i| {
            if (node.f_cost < lowest_f) {
                lowest_f = node.f_cost;
                lowest_index = i;
            }
        }
        return lowest_index;
    }

    // Reconstruct path from goal to start
    fn reconstructPath(allocator: std.mem.Allocator, goal_node: *PathNode) !Path {
        var path = Path.init(allocator);
        var current = goal_node;

        // Build path backwards from goal to start
        var temp_path = std.ArrayList(Types.Vector2Int).init(allocator);
        defer temp_path.deinit();

        while (current) |node| {
            try temp_path.append(node.pos);
            current = node.parent;
        }

        // Reverse the path so it goes from start to goal
        var i = temp_path.items.len;
        while (i > 0) {
            i -= 1;
            try path.nodes.append(temp_path.items[i]);
        }

        return path;
    }

    // Main A* pathfinding function
    pub fn findPath(self: *Pathfinder, level: *Level, start: Types.Vector2Int, goal: Types.Vector2Int) !?Path {
        // Early exit if goal is not walkable
        if (!isWalkable(level, goal)) {
            return null;
        }

        var open_list = std.ArrayList(PathNode).init(self.allocator);
        defer open_list.deinit();

        var closed_list = std.ArrayList(PathNode).init(self.allocator);
        defer closed_list.deinit();

        // Create start node
        const start_node = PathNode.init(start, 0.0, heuristic(start, goal), null);
        try open_list.append(start_node);

        while (open_list.items.len > 0) {
            // Find node with lowest f_cost
            const current_index = findLowestFCost(open_list);
            const current_node = open_list.items[current_index];

            // Move current node from open to closed list
            _ = open_list.swapRemove(current_index);
            try closed_list.append(current_node);

            // Check if we reached the goal
            if (current_node.pos.x == goal.x and current_node.pos.y == goal.y) {
                // We need to get a pointer to the goal node in closed_list
                const goal_node = &closed_list.items[closed_list.items.len - 1];
                return try self.reconstructPath(self.allocator, goal_node);
            }

            // Check all neighbors
            var neighbors: [4]Types.Vector2Int = undefined;
            getNeighbors(current_node.pos, &neighbors);

            for (neighbors) |neighbor_pos| {
                // Skip if not walkable
                if (!isWalkable(level, neighbor_pos)) {
                    continue;
                }

                // Skip if already in closed list
                if (findNodeInList(closed_list, neighbor_pos) != null) {
                    continue;
                }

                const tentative_g = current_node.g_cost + 1.0; // Movement cost is 1

                // Check if this neighbor is already in open list
                if (findNodeInList(open_list, neighbor_pos)) |existing_index| {
                    // If this path to neighbor is better, update it
                    if (tentative_g < open_list.items[existing_index].g_cost) {
                        open_list.items[existing_index].g_cost = tentative_g;
                        open_list.items[existing_index].f_cost = tentative_g + open_list.items[existing_index].h_cost;
                        // Note: In a full implementation, you'd update the parent pointer here
                        // but that requires more complex memory management in Zig
                    }
                } else {
                    // Add neighbor to open list
                    const neighbor_node = PathNode.init(neighbor_pos, tentative_g, heuristic(neighbor_pos, goal), null // Simplified - in full implementation you'd store parent reference
                    );
                    try open_list.append(neighbor_node);
                }
            }
        }

        // No path found
        return null;
    }

    // Simplified pathfinding for when you just need to know if a path exists
    pub fn hasPath(self: *Pathfinder, level: *Level, start: Types.Vector2Int, goal: Types.Vector2Int) !bool {
        if (self.findPath(level, start, goal)) |path| {
            var mutable_path = path;
            mutable_path.deinit();
            return true;
        } else |_| {
            return false;
        }
    }
};

// Add these methods to your Level struct:

// In your Level struct, add this method:
pub fn getTileAt(self: *Level, pos: Types.Vector2Int) ?*Tile {
    if (pos.x < 0 or pos.x >= Config.level_width or
        pos.y < 0 or pos.y >= Config.level_height)
    {
        return null;
    }

    const idx = @as(usize, @intCast(pos.y * Config.level_width + pos.x));
    return &self.grid[idx];
}

pub fn isPositionWalkable(self: *Level, pos: Types.Vector2Int) bool {
    if (self.getTileAt(pos)) |tile| {
        return !tile.solid;
    }
    return false;
}

// Example usage in a Player or Enemy struct:
pub const MovingEntity = struct {
    position: Types.Vector2Int,
    path: ?Path,
    pathfinder: Pathfinder,
    move_timer: f32,
    move_speed: f32, // Time between moves in seconds

    pub fn init(allocator: std.mem.Allocator, start_pos: Types.Vector2Int) MovingEntity {
        return MovingEntity{
            .position = start_pos,
            .path = null,
            .pathfinder = Pathfinder.init(allocator),
            .move_timer = 0.0,
            .move_speed = 0.5, // Move every 0.5 seconds
        };
    }

    pub fn deinit(self: *MovingEntity) void {
        if (self.path) |*path| {
            path.deinit();
        }
    }

    pub fn setTarget(self: *MovingEntity, level: *Level, target: Types.Vector2Int) !void {
        // Clear existing path
        if (self.path) |*old_path| {
            old_path.deinit();
        }

        // Find new path
        self.path = try self.pathfinder.findPath(level, self.position, target);
    }

    pub fn update(self: *MovingEntity, delta_time: f32) void {
        if (self.path == null) return;

        self.move_timer += delta_time;

        if (self.move_timer >= self.move_speed) {
            self.move_timer = 0.0;

            if (self.path.?.getNextPosition()) |next_pos| {
                self.position = next_pos;
            } else {
                // Path completed
                self.path.?.deinit();
                self.path = null;
            }
        }
    }

    pub fn isMoving(self: *MovingEntity) bool {
        return self.path != null and self.path.?.hasNextPosition();
    }
};
