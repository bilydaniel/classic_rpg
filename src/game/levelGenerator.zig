const Level = @import("level.zig");
const Allocators = @import("../common/allocators.zig");
const Config = @import("../common/config.zig");
const Types = @import("../common/types.zig");
const Utils = @import("../common/utils.zig");
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

    while (i < room.w) : (i += 1) {
        j = 0;
        while (j < room.h) : (j += 1) {
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
    std.debug.print("carve_line\n", .{});
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
                std.debug.print("carving_tile\n", .{});
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

        std.debug.print("while_cond: {} {} \n", .{ current, to.x });
        while (current != to.x) : (current += dx) {
            std.debug.print("while...\n", .{});
            const pos = Types.Vector2Int.init(current, from.y);
            const index = Utils.posToIndex(pos);
            std.debug.print("index: {?}\n", .{index});

            if (index) |_index| {
                level.grid[_index] = Level.Tile.init(tileType);
                std.debug.print("carving_tile\n", .{});
            }
        }
    } else {
        return generatorError.NoLine;
    }
}
