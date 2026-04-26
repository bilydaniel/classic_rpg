const Level = @import("level.zig");
const Allocators = @import("../common/allocators.zig");
const Config = @import("../common/config.zig");
const Types = @import("../common/types.zig");
const Utils = @import("../common/utils.zig");
const Debug = @import("../common/debug.zig");
const rl = @import("raylib");
const std = @import("std");

const generatorError = error{
    NoLine,
};
pub var allocator: std.mem.Allocator = undefined;

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
}

//TODO: start with pure random + BSP trees, more complex later
pub fn generate(id: u32, worldPos: Types.Vector3Int) !Level.Level {
    _ = try generateBSP(id, worldPos);

    //TODO: make a opposite version, mostly empty, add random walls
    var level = try Level.Level.init(Allocators.persistent, id, worldPos);

    fillLevelWith(&level, .wall);

    try carveRandomRooms(&level);

    return level;
}

pub fn fillLevelWith(level: *Level.Level, tileType: Level.TileType) void {
    for (0..level.grid.len) |i| {
        level.grid[i] = Level.Tile.init(tileType);
    }
}

pub fn carveRandomRooms(level: *Level.Level) !void {
    var collisions: i32 = 0;
    const maxRooms: i32 = 100;
    var currentRooms: i32 = 0;

    outer: while (true) {
        if (currentRooms >= maxRooms) {
            return;
        }

        if (collisions == 10) {
            return;
        }
        const roomW = std.crypto.random.intRangeLessThan(i32, 2, 8);
        const roomH = std.crypto.random.intRangeLessThan(i32, 2, 8);

        const roomX = std.crypto.random.intRangeLessThan(i32, 0, Config.level_width - roomW - 1);
        const roomY = std.crypto.random.intRangeLessThan(i32, 0, Config.level_height - roomH - 1);

        const room = Types.RectangleInt.init(roomX, roomY, roomW, roomH);

        for (level.rooms.items) |level_room| {
            if (room.collision(level_room)) {
                collisions += 1;
                continue :outer;
            }
        }

        if (level.rooms.items.len > 0) {
            const previousRoom = level.rooms.getLast();
            const corridorFrom = previousRoom.center();
            const corridorTo = room.center();

            std.debug.print("cor_from: {}\n", .{corridorFrom});
            std.debug.print("cor_to: {}\n", .{corridorTo});

            try makeLShape(level, corridorFrom, corridorTo, .floor);
        }

        try carveRoomRectangle(level, room);
        currentRooms += 1;
        collisions = 0;
    }
}

pub fn carveRoomRectangle(level: *Level.Level, room: Types.RectangleInt) !void {
    var i: i32 = 0;
    var j: i32 = 0;

    while (j < room.h) : (j += 1) {
        i = 0;
        while (i < room.w) : (i += 1) {
            const position = Types.Vector2Int.init(room.x + i, room.y + j);
            const index = Utils.posToIndex(position);
            if (index) |_index| {
                level.grid[_index] = Level.Tile.init(.floor);
                try level.rooms.append(allocator, room);
            }
        }
    }
}
pub fn carveRoomCircle(grid: Types.Grid, pos: Types.Vector2Int, r: u32) void {
    _ = grid;
    _ = pos;
    _ = r;
}

pub fn makeLShape(level: *Level.Level, from: Types.Vector2Int, to: Types.Vector2Int, tileType: Level.TileType) !void {
    std.debug.print("carve_corridor\n", .{});
    const horrizontal = std.crypto.random.boolean();

    var corner = Types.Vector2Int.init(0, 0);
    if (horrizontal) {
        corner.x = to.x;
        corner.y = from.y;
    } else {
        corner.x = from.x;
        corner.y = to.y;
    }

    try makeLine(level, from, corner, tileType);
    try makeLine(level, corner, to, tileType);
}

pub fn makeLine(level: *Level.Level, from: Types.Vector2Int, to: Types.Vector2Int, tileType: Level.TileType) !void {
    if (from.x == to.x) {
        // vertical
        var current = from.y;
        var dy: i32 = 0;
        if (from.y < to.y) {
            dy = 1;
        } else if (from.y > to.y) {
            dy = -1;
        }

        while (current != to.y) : (current += dy) {
            const pos = Types.Vector2Int.init(from.x, current);
            const index = Utils.posToIndex(pos);
            if (index) |_index| {
                level.grid[_index] = Level.Tile.init(tileType);
            }
        }
    } else if (from.y == to.y) {
        //horizontal
        var current = from.x;
        var dx: i32 = 0;
        if (from.x < to.x) {
            dx = 1;
        } else if (from.x > to.x) {
            dx = -1;
        }

        while (current != to.x) : (current += dx) {
            const pos = Types.Vector2Int.init(current, from.y);
            const index = Utils.posToIndex(pos);

            if (index) |_index| {
                level.grid[_index] = Level.Tile.init(tileType);
            }
        }
    } else {
        return generatorError.NoLine;
    }
}

pub fn generateBSP(id: u32, worldPos: Types.Vector3Int) !Level.Level {
    const iterations: u32 = 10;
    //TODO: add min / max
    //const splitMin = 0.1;

    var tree = Types.BSPTree.init(Allocators.persistent);
    defer tree.deinit();

    var levelVal = try Level.Level.init(Allocators.persistent, id, worldPos);
    const level = &levelVal;
    fillLevelWith(level, .wall);

    const mainRoom = Types.RectangleInt.init(0, 0, Config.level_width, Config.level_height);
    try tree.insert(mainRoom);

    var splitRooms = std.ArrayList(Types.RectangleInt).empty;
    //TODO: use arena
    try splitRooms.insert(Allocators.persistent, 0, mainRoom);

    for (0..iterations) |_| {
        const room = splitRooms.orderedRemove(splitRooms.items.len - 1);
        const horizontal = std.crypto.random.boolean();
        const split = std.crypto.random.float(f32);

        var splitValue: i32 = 0;
        var room1 = Types.RectangleInt.init(0, 0, 0, 0);
        var room2 = Types.RectangleInt.init(0, 0, 0, 0);

        if (horizontal) {
            splitValue = @intFromFloat(split * @as(f32, @floatFromInt(room.h)));
            room1 = Types.RectangleInt.init(0, 0, room.w, splitValue);
            room2 = Types.RectangleInt.init(0, splitValue, room.w, room.h - splitValue);
        } else {
            splitValue = @intFromFloat(split * @as(f32, @floatFromInt(room.w)));
            room1 = Types.RectangleInt.init(0, 0, splitValue, room.h);
            room2 = Types.RectangleInt.init(splitValue, 0, room.w - splitValue, room.h);
        }

        try splitRooms.insert(Allocators.persistent, 0, room1);
        try splitRooms.insert(Allocators.persistent, 0, room2);
        try tree.insert(room1);
        try tree.insert(room2);
    }

    tree.printTopDown();

    try carveBSPCorridor(level, &tree, 0);

    //TODO: remove
    const fakeRoom = Types.RectangleInt.init(0, 0, 1, 1);
    try carveRoomRectangle(level, fakeRoom);

    return levelVal;
}

pub fn carveBSPCorridor(level: *Level.Level, tree: *Types.BSPTree, index: usize) !void {
    std.debug.print("index: {}\n", .{index});
    const node = tree.getNode(index) orelse return;

    if (index != 0 and node.left == null and node.right == null) {
        std.debug.print("rooming...\n", .{});
        std.debug.print("room: {}\n", .{node.data});
        const room = roomCutOff(node.data);

        //debugDrawRoom(room);
        Debug.addRect(tilePos: Vector2Int)

        try carveRoomRectangle(level, room);
    }

    if (node.left != null and node.right != null) {
        const leftIndex = node.left.?;
        const rightIndex = node.right.?;
        const leftNode = tree.getNode(leftIndex) orelse unreachable;
        const rightNode = tree.getNode(rightIndex) orelse unreachable;

        try makeLine(level, leftNode.data.center(), rightNode.data.center(), .floor);

        try carveBSPCorridor(level, tree, leftIndex);
        try carveBSPCorridor(level, tree, rightIndex);
    }
}

pub fn roomCutOff(room: Types.RectangleInt) Types.RectangleInt {
    //TODO: make better
    const cutoff = 2;
    return Types.RectangleInt.init(room.x + cutoff, room.y + cutoff, room.w - cutoff, room.h - cutoff);
}

pub fn debugDrawRoom(room: Types.RectangleInt) void {
    //const rlRect = room.getRLRect();
    rl.drawRectangleLines(room.x * Config.tile_width, room.y * Config.tile_height, room.w * Config.tile_width, room.h * Config.tile_height, rl.Color.red);
}
