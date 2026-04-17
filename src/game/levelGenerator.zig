const Level = @import("level.zig");
const Allocators = @import("../common/allocators.zig");
const Config = @import("../common/config.zig");
const Types = @import("../common/types.zig");
const Utils = @import("../common/utils.zig");
const rl = @import("raylib");
const std = @import("std");

pub const allocator: std.mem.Allocator = undefined;

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
}

//TODO: start with pure random + BSP trees, more complex later
pub fn generate(id: u32, worldPos: Types.Vector3Int) !Level.Level {
    const level = try Level.Level.init(Allocators.persistent, id, worldPos);

    fillWithWalls(level.grid);

    carveRandomRooms(level);

    return level;
}

pub fn fillWithWalls(grid: Types.Grid) void {
    for (0..grid.len) |i| {
        grid[i] = Level.Tile.init(.wall);
    }
}

pub fn carveRandomRooms(level: Level.Level) void {
    while (true) {
        const roomW = std.crypto.random.intRangeLessThan(i32, 2, 8);
        const roomH = std.crypto.random.intRangeLessThan(i32, 2, 8);

        const roomX = std.crypto.random.intRangeLessThan(i32, 0, Config.level_width - roomW - 1);
        const roomY = std.crypto.random.intRangeLessThan(i32, 0, Config.level_height - roomH - 1);

        const room = rl.Rectangle.init(roomX, roomY, roomW, roomH);

        carveRoomRectangle(level.grid, room);

        break;
    }
}

pub fn carveRoomRectangle(level: Level.Level, room: rl.Rectangle) void {
    var i: i32 = 0;
    var j: i32 = 0;

    while (i < room.width) : (i += 1) {
        j = 0;
        while (j < room.height) : (j += 1) {
            const position = Types.Vector2Int.init(room.x + i, room.y + j);
            const index = Utils.posToIndex(position);
            if (index) |_index| {
                level.grid[_index] = Level.Tile.init(.floor);
                level.rooms.append(allocator, room);
            }
        }
    }
}
pub fn carveRoomCircle(grid: Types.Grid, pos: Types.Vector2Int, r: u32) void {
    _ = grid;
    _ = pos;
    _ = r;
}
