const std = @import("std");
const Level = @import("level.zig");
const Config = @import("../common/config.zig");
const Types = @import("../common/types.zig");
const Systems = @import("Systems.zig");

pub const GeneratorType = enum {
    dungeon_bsp,
    dungeon_cellular,
    dungeon_drunkard,
    temple_rooms,
    maze,
    arena,
};

pub const Theme = enum {
    dungeon,
    cave,
    temple,
    fortress,
    laboratory,
};

pub const GenerationParams = struct {
    seed: u64,
    generator_type: GeneratorType = .dungeon_bsp,
    room_min_size: u32 = 5,
    room_max_size: u32 = 12,
    max_depth: u32 = 4,
    corridor_width: u32 = 1,
    room_density: f32 = 0.6,
    special_room_chance: f32 = 0.15,
    water_chance: f32 = 0.05,
    decoration_chance: f32 = 0.3,
    theme: Theme = .dungeon,
};

pub const Rectangle = struct {
    x: i32,
    y: i32,
    width: i32,
    height: i32,

    pub fn center(self: Rectangle) Types.Vector2Int {
        return Types.Vector2Int{
            .x = self.x + @divFloor(self.width, 2),
            .y = self.y + @divFloor(self.height, 2),
        };
    }

    pub fn contains(self: Rectangle, pos: Types.Vector2Int) bool {
        return pos.x >= self.x and pos.x < self.x + self.width and
            pos.y >= self.y and pos.y < self.y + self.height;
    }

    pub fn intersects(self: Rectangle, other: Rectangle) bool {
        return self.x < other.x + other.width and
            self.x + self.width > other.x and
            self.y < other.y + other.height and
            self.y + self.height > other.y;
    }
};

pub const Room = struct {
    rect: Rectangle,
    feature: ?RoomFeature = null,
    connected: bool = false,
};

pub const RoomFeature = enum {
    normal,
    pillar_grid,
    central_pool,
    altar,
    treasure_vault,
    garden,
};

const BSPNode = struct {
    rect: Rectangle,
    left: ?*BSPNode = null,
    right: ?*BSPNode = null,
    room: ?Room = null,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, rect: Rectangle) !*BSPNode {
        const node = try allocator.create(BSPNode);
        node.* = .{
            .rect = rect,
            .allocator = allocator,
        };
        return node;
    }

    pub fn deinit(self: *BSPNode) void {
        if (self.left) |left| {
            left.deinit();
            self.allocator.destroy(left);
        }
        if (self.right) |right| {
            right.deinit();
            self.allocator.destroy(right);
        }
    }

    pub fn split(self: *BSPNode, params: GenerationParams, rng: *std.rand.Random, depth: u32) !void {
        // Stop splitting if too deep or too small
        if (depth >= params.max_depth) {
            return;
        }

        const min_size = params.room_min_size + 4; // Need space for walls and corridor

        // Check if we can split
        const can_split_horizontally = self.rect.height >= min_size * 2;
        const can_split_vertically = self.rect.width >= min_size * 2;

        if (!can_split_horizontally and !can_split_vertically) {
            return; // Too small to split
        }

        // Decide split direction
        var split_horizontally: bool = false;
        if (can_split_horizontally and can_split_vertically) {
            // Prefer splitting along the longer dimension
            if (self.rect.height > self.rect.width) {
                split_horizontally = rng.float(f32) < 0.7;
            } else {
                split_horizontally = rng.float(f32) < 0.3;
            }
        } else {
            split_horizontally = can_split_horizontally;
        }

        if (split_horizontally) {
            // Split horizontally
            const max_split = self.rect.height - @as(i32, @intCast(min_size));
            const min_split = @as(i32, @intCast(min_size));
            const split_point = min_split + @as(i32, @intCast(rng.intRangeAtMost(u32, 0, @intCast(max_split - min_split))));

            const top_rect = Rectangle{
                .x = self.rect.x,
                .y = self.rect.y,
                .width = self.rect.width,
                .height = split_point,
            };

            const bottom_rect = Rectangle{
                .x = self.rect.x,
                .y = self.rect.y + split_point,
                .width = self.rect.width,
                .height = self.rect.height - split_point,
            };

            self.left = try BSPNode.init(self.allocator, top_rect);
            self.right = try BSPNode.init(self.allocator, bottom_rect);
        } else {
            // Split vertically
            const max_split = self.rect.width - @as(i32, @intCast(min_size));
            const min_split = @as(i32, @intCast(min_size));
            const split_point = min_split + @as(i32, @intCast(rng.intRangeAtMost(u32, 0, @intCast(max_split - min_split))));

            const left_rect = Rectangle{
                .x = self.rect.x,
                .y = self.rect.y,
                .width = split_point,
                .height = self.rect.height,
            };

            const right_rect = Rectangle{
                .x = self.rect.x + split_point,
                .y = self.rect.y,
                .width = self.rect.width - split_point,
                .height = self.rect.height,
            };

            self.left = try BSPNode.init(self.allocator, left_rect);
            self.right = try BSPNode.init(self.allocator, right_rect);
        }

        // Recursively split children
        if (self.left) |left| {
            try left.split(params, rng, depth + 1);
        }
        if (self.right) |right| {
            try right.split(params, rng, depth + 1);
        }
    }

    pub fn createRooms(self: *BSPNode, params: GenerationParams, rng: *std.rand.Random) void {
        // If this is a leaf node, create a room
        if (self.left == null and self.right == null) {
            const padding = 2;
            const max_room_width = @min(params.room_max_size, @as(u32, @intCast(self.rect.width - padding * 2)));
            const max_room_height = @min(params.room_max_size, @as(u32, @intCast(self.rect.height - padding * 2)));

            const room_width = @max(
                params.room_min_size,
                params.room_min_size + rng.intRangeAtMost(u32, 0, max_room_width - params.room_min_size),
            );
            const room_height = @max(
                params.room_min_size,
                params.room_min_size + rng.intRangeAtMost(u32, 0, max_room_height - params.room_min_size),
            );

            const max_x_offset = self.rect.width - @as(i32, @intCast(room_width)) - padding;
            const max_y_offset = self.rect.height - @as(i32, @intCast(room_height)) - padding;

            const x_offset = if (max_x_offset > 0)
                padding + @as(i32, @intCast(rng.intRangeAtMost(u32, 0, @intCast(max_x_offset))))
            else
                padding;

            const y_offset = if (max_y_offset > 0)
                padding + @as(i32, @intCast(rng.intRangeAtMost(u32, 0, @intCast(max_y_offset))))
            else
                padding;

            self.room = Room{
                .rect = Rectangle{
                    .x = self.rect.x + x_offset,
                    .y = self.rect.y + y_offset,
                    .width = @intCast(room_width),
                    .height = @intCast(room_height),
                },
            };

            // Assign feature chance
            if (rng.float(f32) < params.special_room_chance) {
                self.room.?.feature = rng.enumValue(RoomFeature);
            }
        } else {
            // Recursively create rooms in children
            if (self.left) |left| {
                left.createRooms(params, rng);
            }
            if (self.right) |right| {
                right.createRooms(params, rng);
            }
        }
    }

    pub fn getRooms(self: *BSPNode, rooms: *std.ArrayList(Room)) !void {
        if (self.room) |room| {
            try rooms.append(room);
        }

        if (self.left) |left| {
            try left.getRooms(rooms);
        }
        if (self.right) |right| {
            try right.getRooms(rooms);
        }
    }

    pub fn getLeaves(self: *BSPNode, leaves: *std.ArrayList(*BSPNode)) !void {
        if (self.left == null and self.right == null) {
            try leaves.append(self);
            return;
        }

        if (self.left) |left| {
            try left.getLeaves(leaves);
        }
        if (self.right) |right| {
            try right.getLeaves(leaves);
        }
    }
};

// Main generation function
pub fn generate(level: *Level.Level, params: GenerationParams, allocator: std.mem.Allocator) !void {
    var rng_impl = std.rand.DefaultPrng.init(params.seed);
    var rng = rng_impl.random();

    // Initialize all tiles as walls
    for (level.grid) |*tile| {
        tile.* = Level.Tile.initWall();
    }

    // Create BSP tree
    const root_rect = Rectangle{
        .x = 1,
        .y = 1,
        .width = Config.level_width - 2,
        .height = Config.level_height - 2,
    };

    const root = try BSPNode.init(allocator, root_rect);
    defer {
        root.deinit();
        allocator.destroy(root);
    }

    // Split the space
    try root.split(params, &rng, 0);

    // Create rooms in leaf nodes
    root.createRooms(params, &rng);

    // Get all rooms
    var rooms = std.ArrayList(Room).init(allocator);
    defer rooms.deinit();
    try root.getRooms(&rooms);

    // Carve out rooms
    for (rooms.items) |room| {
        carveRoom(level, room);
    }

    // Connect rooms with corridors
    var leaves = std.ArrayList(*BSPNode).init(allocator);
    defer leaves.deinit();
    try root.getLeaves(&leaves);

    try connectRooms(level, root, &rng, params);

    // Apply room features
    for (rooms.items) |room| {
        if (room.feature) |feature| {
            applyRoomFeature(level, room, feature, &rng);
        }

        // Add decorations
        if (rng.float(f32) < params.decoration_chance) {
            addRoomDecorations(level, room, &rng);
        }

        // Add water
        if (rng.float(f32) < params.water_chance) {
            addWaterPool(level, room, &rng);
        }
    }

    // Place staircases
    try placeStaircases(level, &rooms, &rng);

    // Add wall variations
    addWallVariation(level, &rng);
}

fn carveRoom(level: *Level.Level, room: Room) void {
    var y: i32 = room.rect.y;
    while (y < room.rect.y + room.rect.height) : (y += 1) {
        var x: i32 = room.rect.x;
        while (x < room.rect.x + room.rect.width) : (x += 1) {
            if (x >= 0 and x < Config.level_width and y >= 0 and y < Config.level_height) {
                const idx = @as(usize, @intCast(y * Config.level_width + x));
                level.grid[idx] = Level.Tile.initFloor();
            }
        }
    }
}

fn connectRooms(level: *Level.Level, node: *BSPNode, rng: *std.rand.Random, params: GenerationParams) !void {
    if (node.left == null or node.right == null) {
        return; // Leaf node, nothing to connect
    }

    // Connect children first
    if (node.left) |left| {
        try connectRooms(level, left, rng, params);
    }
    if (node.right) |right| {
        try connectRooms(level, right, rng, params);
    }

    // Get a room from each child subtree
    const left_room = getRandomRoomFromNode(node.left.?, rng);
    const right_room = getRandomRoomFromNode(node.right.?, rng);

    if (left_room != null and right_room != null) {
        const start = left_room.?.rect.center();
        const end = right_room.?.rect.center();

        // Create L-shaped corridor
        if (rng.boolean()) {
            createHorizontalCorridor(level, start.x, end.x, start.y, params.corridor_width);
            createVerticalCorridor(level, start.y, end.y, end.x, params.corridor_width);
        } else {
            createVerticalCorridor(level, start.y, end.y, start.x, params.corridor_width);
            createHorizontalCorridor(level, start.x, end.x, end.y, params.corridor_width);
        }
    }
}

fn getRandomRoomFromNode(node: *BSPNode, rng: *std.rand.Random) ?Room {
    if (node.room) |room| {
        return room;
    }

    var options = std.ArrayList(?Room).init(node.allocator);
    defer options.deinit();

    if (node.left) |left| {
        if (getRandomRoomFromNode(left, rng)) |room| {
            options.append(room) catch {};
        }
    }
    if (node.right) |right| {
        if (getRandomRoomFromNode(right, rng)) |room| {
            options.append(room) catch {};
        }
    }

    if (options.items.len > 0) {
        const idx = rng.intRangeAtMost(usize, 0, options.items.len - 1);
        return options.items[idx];
    }

    return null;
}

fn createHorizontalCorridor(level: *Level.Level, x1: i32, x2: i32, y: i32, width: u32) void {
    const start_x = @min(x1, x2);
    const end_x = @max(x1, x2);

    const half_width = @as(i32, @intCast(width)) / 2;

    var cy: i32 = y - half_width;
    while (cy <= y + half_width) : (cy += 1) {
        var cx: i32 = start_x;
        while (cx <= end_x) : (cx += 1) {
            if (cx >= 0 and cx < Config.level_width and cy >= 0 and cy < Config.level_height) {
                const idx = @as(usize, @intCast(cy * Config.level_width + cx));
                if (level.grid[idx].tileType == .wall) {
                    level.grid[idx] = Level.Tile.initFloor();
                }
            }
        }
    }
}

fn createVerticalCorridor(level: *Level.Level, y1: i32, y2: i32, x: i32, width: u32) void {
    const start_y = @min(y1, y2);
    const end_y = @max(y1, y2);

    const half_width = @as(i32, @intCast(width)) / 2;

    var cx: i32 = x - half_width;
    while (cx <= x + half_width) : (cx += 1) {
        var cy: i32 = start_y;
        while (cy <= end_y) : (cy += 1) {
            if (cx >= 0 and cx < Config.level_width and cy >= 0 and cy < Config.level_height) {
                const idx = @as(usize, @intCast(cy * Config.level_width + cx));
                if (level.grid[idx].tileType == .wall) {
                    level.grid[idx] = Level.Tile.initFloor();
                }
            }
        }
    }
}

fn applyRoomFeature(level: *Level.Level, room: Room, feature: RoomFeature, rng: *std.rand.Random) void {
    switch (feature) {
        .normal => {},
        .pillar_grid => {
            // Place pillars in a grid pattern
            var y: i32 = room.rect.y + 2;
            while (y < room.rect.y + room.rect.height - 2) : (y += 3) {
                var x: i32 = room.rect.x + 2;
                while (x < room.rect.x + room.rect.width - 2) : (x += 3) {
                    if (x >= 0 and x < Config.level_width and y >= 0 and y < Config.level_height) {
                        const idx = @as(usize, @intCast(y * Config.level_width + x));
                        level.grid[idx] = Level.Tile.initWall();
                    }
                }
            }
        },
        .central_pool => {
            const pool_width = @max(2, @divFloor(room.rect.width, 3));
            const pool_height = @max(2, @divFloor(room.rect.height, 3));
            const start_x = room.rect.x + @divFloor(room.rect.width - pool_width, 2);
            const start_y = room.rect.y + @divFloor(room.rect.height - pool_height, 2);

            var y: i32 = start_y;
            while (y < start_y + pool_height) : (y += 1) {
                var x: i32 = start_x;
                while (x < start_x + pool_width) : (x += 1) {
                    if (x >= 0 and x < Config.level_width and y >= 0 and y < Config.level_height) {
                        const idx = @as(usize, @intCast(y * Config.level_width + x));
                        level.grid[idx] = Level.Tile.initWater();
                    }
                }
            }
        },
        .altar => {
            const center = room.rect.center();
            if (center.x >= 0 and center.x < Config.level_width and
                center.y >= 0 and center.y < Config.level_height)
            {
                const idx = @as(usize, @intCast(center.y * Config.level_width + center.x));
                level.grid[idx] = Level.Tile.initFloor(); // Could be special altar tile
            }
        },
        .treasure_vault => {
            // Add pillars around the room perimeter
            var y: i32 = room.rect.y + 1;
            while (y < room.rect.y + room.rect.height - 1) : (y += 2) {
                // Left wall pillars
                if (room.rect.x + 1 >= 0 and room.rect.x + 1 < Config.level_width and
                    y >= 0 and y < Config.level_height)
                {
                    const idx = @as(usize, @intCast(y * Config.level_width + room.rect.x + 1));
                    level.grid[idx] = Level.Tile.initWall();
                }
                // Right wall pillars
                const right_x = room.rect.x + room.rect.width - 2;
                if (right_x >= 0 and right_x < Config.level_width and
                    y >= 0 and y < Config.level_height)
                {
                    const idx = @as(usize, @intCast(y * Config.level_width + right_x));
                    level.grid[idx] = Level.Tile.initWall();
                }
            }
        },
        .garden => {
            // Scatter water tiles randomly
            const water_count = @as(u32, @intCast(room.rect.width * room.rect.height / 10));
            var i: u32 = 0;
            while (i < water_count) : (i += 1) {
                const x = room.rect.x + @as(i32, @intCast(rng.intRangeAtMost(u32, 0, @intCast(room.rect.width - 1))));
                const y = room.rect.y + @as(i32, @intCast(rng.intRangeAtMost(u32, 0, @intCast(room.rect.height - 1))));

                if (x >= 0 and x < Config.level_width and y >= 0 and y < Config.level_height) {
                    const idx = @as(usize, @intCast(y * Config.level_width + x));
                    level.grid[idx] = Level.Tile.initWater();
                }
            }
        },
    }
}

fn addWaterPool(level: *Level.Level, room: Room, rng: *std.rand.Random) void {
    const pool_size = rng.intRangeAtMost(u32, 2, 4);
    const x = room.rect.x + @as(i32, @intCast(rng.intRangeAtMost(u32, 1, @intCast(room.rect.width - @as(i32, @intCast(pool_size)) - 1))));
    const y = room.rect.y + @as(i32, @intCast(rng.intRangeAtMost(u32, 1, @intCast(room.rect.height - @as(i32, @intCast(pool_size)) - 1))));

    var py: i32 = y;
    while (py < y + @as(i32, @intCast(pool_size))) : (py += 1) {
        var px: i32 = x;
        while (px < x + @as(i32, @intCast(pool_size))) : (px += 1) {
            if (px >= 0 and px < Config.level_width and py >= 0 and py < Config.level_height) {
                const idx = @as(usize, @intCast(py * Config.level_width + px));
                level.grid[idx] = Level.Tile.initWater();
            }
        }
    }
}

fn addRoomDecorations(level: *Level.Level, room: Room, rng: *std.rand.Random) void {
    // Randomly place a few wall tiles (debris/statues)
    const decoration_count = rng.intRangeAtMost(u32, 1, 3);
    var i: u32 = 0;
    while (i < decoration_count) : (i += 1) {
        const x = room.rect.x + @as(i32, @intCast(rng.intRangeAtMost(u32, 1, @intCast(room.rect.width - 2))));
        const y = room.rect.y + @as(i32, @intCast(rng.intRangeAtMost(u32, 1, @intCast(room.rect.height - 2))));

        if (x >= 0 and x < Config.level_width and y >= 0 and y < Config.level_height) {
            const idx = @as(usize, @intCast(y * Config.level_width + x));
            // Could add different decoration types here
            level.grid[idx] = Level.Tile.initWall();
        }
    }
}

fn placeStaircases(level: *Level.Level, rooms: *std.ArrayList(Room), rng: *std.rand.Random) !void {
    if (rooms.items.len < 2) return;

    // Place down staircase in first room
    const first_room = rooms.items[0];
    const down_pos = first_room.rect.center();

    if (down_pos.x >= 0 and down_pos.x < Config.level_width and
        down_pos.y >= 0 and down_pos.y < Config.level_height)
    {
        const idx = @as(usize, @intCast(down_pos.y * Config.level_width + down_pos.x));
        level.grid[idx] = Level.Tile.initStaircaseDown();
    }

    // Place up staircase in last room
    const last_room = rooms.items[rooms.items.len - 1];
    const up_pos = last_room.rect.center();

    if (up_pos.x >= 0 and up_pos.x < Config.level_width and
        up_pos.y >= 0 and up_pos.y < Config.level_height)
    {
        const idx = @as(usize, @intCast(up_pos.y * Config.level_width + up_pos.x));
        level.grid[idx] = Level.Tile.initStaircaseUp();
    }
}

fn addWallVariation(level: *Level.Level, rng: *std.rand.Random) void {
    for (level.grid) |*tile| {
        if (tile.tileType == .wall) {
            const roll = rng.float(f32);
            // Could add wall variations here when you add those tile types
            _ = roll;
        }
    }
}

// Helper function for getting generation params based on depth
pub fn getGenerationParams(worldPos: Types.Vector3Int, base_seed: u64) GenerationParams {
    const depth = @abs(worldPos.z);

    return GenerationParams{
        .seed = base_seed ^ @as(u64, @bitCast(@as(i64, worldPos.z))),
        .generator_type = .dungeon_bsp,
        .room_min_size = 5,
        .room_max_size = if (depth > 5) 10 else 12,
        .max_depth = if (depth > 10) 5 else 4,
        .room_density = 0.6 - (@as(f32, @floatFromInt(depth)) * 0.01),
        .special_room_chance = 0.15 + (@as(f32, @floatFromInt(depth)) * 0.02),
        .water_chance = if (depth > 5) 0.15 else 0.05,
        .decoration_chance = 0.3,
        .theme = .dungeon,
    };
}
