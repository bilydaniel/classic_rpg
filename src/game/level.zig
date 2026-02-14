const std = @import("std");
const Pathfinder = @import("pathfinder.zig");
const Utils = @import("../common/utils.zig");
const Entity = @import("entity.zig");
const TilesetManager = @import("assetManager.zig");
const Config = @import("../common/config.zig");
const Types = @import("../common/types.zig");
const EntityManager = @import("entityManager.zig");
const World = @import("world.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const TileType = enum {
    empty,
    wall,
    floor,
    water,
    staircase_up,
    staircase_down,
};

pub const Tile = struct {
    //TODO: add movement cost? can be derived from tile_type
    textureID: ?i32,
    sourceRect: ?c.Rectangle,
    tileType: TileType,
    solid: bool, //TODO: no idea if needed, tile_type already says if solid
    walkable: bool,
    backgroundColor: c.Color,
    tempBackground: ?c.Color,
    seen: bool,
    visible: bool,

    pub fn initFloor() Tile {
        var texture_id: ?i32 = null;
        var source_rect: ?c.Rectangle = null;
        if (!Config.ascii_mode) {
            texture_id = 100; // try: 1, 100
            if (texture_id) |text_id| {
                source_rect = Utils.makeSourceRect(text_id);
            }
        }
        return Tile{
            .textureID = texture_id,
            .sourceRect = source_rect,
            .tileType = .floor,
            .solid = false,
            .walkable = true,
            .backgroundColor = c.BLACK,
            .seen = false,
            .visible = false,
            .tempBackground = null,
        };
    }
    pub fn initWall() Tile {
        var texture_id: ?i32 = null;
        var source_rect: ?c.Rectangle = null;
        texture_id = 1; //try: 2,3,4
        if (texture_id) |text_id| {
            source_rect = Utils.makeSourceRect(text_id);
        }
        return Tile{
            .textureID = texture_id,
            .sourceRect = source_rect,
            .tileType = .wall,
            .solid = true,
            .walkable = false,
            .backgroundColor = c.WHITE,
            .seen = false,
            .visible = false,
            .tempBackground = null,
        };
    }

    pub fn initDoor() Tile {
        var texture_id: ?i32 = null;
        var source_rect: ?c.Rectangle = null;
        texture_id = 25; //26 for open
        if (texture_id) |text_id| {
            source_rect = Utils.makeSourceRect(text_id);
        }
        return Tile{
            .textureID = texture_id,
            .sourceRect = source_rect,
            .tileType = .floor,
            .solid = false,
            .walkable = false,
            .backgroundColor = c.BROWN,
            .seen = false,
            .visible = false,
            .tempBackground = null,
        };
    }

    pub fn initWater() Tile {
        var texture_id: ?i32 = null;
        var source_rect: ?c.Rectangle = null;
        texture_id = 119;
        if (texture_id) |text_id| {
            source_rect = Utils.makeSourceRect(text_id);
        }
        return Tile{
            .textureID = texture_id,
            .sourceRect = source_rect,
            .tileType = .water, // You might want to add a water tile type
            .solid = false,
            .walkable = false,
            .backgroundColor = c.BLUE,
            .seen = false,
            .visible = false,
            .tempBackground = null,
        };
    }

    pub fn initStaircaseUp() Tile {
        var texture_id: ?i32 = null;
        var source_rect: ?c.Rectangle = null;
        texture_id = 17; //18 for up
        if (texture_id) |text_id| {
            source_rect = Utils.makeSourceRect(text_id);
        }
        return Tile{
            .textureID = texture_id,
            .sourceRect = source_rect,
            .tileType = .staircase_up,
            .solid = false,
            .walkable = true,
            .backgroundColor = c.PURPLE,
            .seen = false,
            .visible = false,
            .tempBackground = null,
        };
    }

    pub fn initStaircaseDown() Tile {
        var texture_id: ?i32 = null;
        var source_rect: ?c.Rectangle = null;
        texture_id = 17; //18 for up
        if (texture_id) |text_id| {
            source_rect = Utils.makeSourceRect(text_id);
        }
        return Tile{
            .textureID = texture_id,
            .sourceRect = source_rect,
            .tileType = .staircase_down,
            .solid = false,
            .walkable = true,
            .backgroundColor = c.PURPLE,
            .seen = false,
            .visible = false,
            .tempBackground = null,
        };
    }
};

pub const Level = struct {
    id: u32,
    worldPos: Types.Vector3Int, //TODO: dont know if needed
    grid: []Tile,

    pub fn init(allocator: std.mem.Allocator, id: u32, worldPos: Types.Vector3Int) !Level {
        const tileCount = Config.level_height * Config.level_width;
        const grid = try allocator.alloc(Tile, tileCount);

        for (0..grid.len) |i| {
            grid[i] = Tile.initFloor();
        }

        return Level{
            .id = id,
            .worldPos = worldPos,
            .grid = grid,
        };
    }

    pub fn draw(this: *Level) void {
        for (this.grid, 0..) |tile, index| {
            const x = @as(c_int, @intCast((index % Config.level_width) * Config.tile_width));
            const y = @as(c_int, @intCast((@divFloor(index, Config.level_width)) * Config.tile_height));

            if (tile.seen) {
                if (tile.sourceRect) |source_rect| {
                    const pos = c.Vector2{ .x = @floatFromInt(x), .y = @floatFromInt(y) };
                    var background = c.WHITE;
                    if (tile.tempBackground) |back| {
                        background = back;
                    }
                    //TODO: pridat scaling podle Wwindow.scale ???
                    c.DrawTextureRec(TilesetManager.tileset, source_rect, pos, background);
                }
            }
        }
    }

    pub fn generateInterestingLevel(level: *Level) void {
        const width = Config.level_width;
        const height = Config.level_height;

        // First, fill everything with walls
        for (0..level.grid.len) |i| {
            level.grid[i] = Tile.initWall();
        }

        // Create some rooms
        const rooms = [_]struct { x: usize, y: usize, w: usize, h: usize }{
            .{ .x = 2, .y = 2, .w = 8, .h = 6 }, // Top-left room
            .{ .x = 15, .y = 3, .w = 10, .h = 5 }, // Top-right room
            .{ .x = 5, .y = 12, .w = 6, .h = 8 }, // Bottom-left room
            .{ .x = 18, .y = 15, .w = 7, .h = 6 }, // Bottom-right room
            .{ .x = 12, .y = 8, .w = 4, .h = 4 }, // Central small room
        };

        // Carve out rooms
        for (rooms) |room| {
            for (room.y..room.y + room.h) |y| {
                for (room.x..room.x + room.w) |x| {
                    if (x < width and y < height) {
                        const idx = y * width + x;
                        level.grid[idx] = Tile.initFloor();
                    }
                }
            }
        }

        // Create corridors connecting rooms
        const corridors = [_]struct { x1: usize, y1: usize, x2: usize, y2: usize }{
            .{ .x1 = 10, .y1 = 5, .x2 = 15, .y2 = 5 }, // Connect room 1 to room 2
            .{ .x1 = 6, .y1 = 8, .x2 = 6, .y2 = 12 }, // Connect room 1 to room 3
            .{ .x1 = 11, .y1 = 16, .x2 = 18, .y2 = 16 }, // Connect room 3 to room 4
            .{ .x1 = 14, .y1 = 8, .x2 = 14, .y2 = 12 }, // Connect central room down
            .{ .x1 = 12, .y1 = 10, .x2 = 16, .y2 = 10 }, // Connect central room right
        };

        // Carve out corridors
        for (corridors) |corridor| {
            // Horizontal corridor
            if (corridor.y1 == corridor.y2) {
                const start_x = @min(corridor.x1, corridor.x2);
                const end_x = @max(corridor.x1, corridor.x2);
                for (start_x..end_x + 1) |x| {
                    if (x < width and corridor.y1 < height) {
                        const idx = corridor.y1 * width + x;
                        level.grid[idx] = Tile.initFloor();
                    }
                }
            }
            // Vertical corridor
            else if (corridor.x1 == corridor.x2) {
                const start_y = @min(corridor.y1, corridor.y2);
                const end_y = @max(corridor.y1, corridor.y2);
                for (start_y..end_y + 1) |y| {
                    if (corridor.x1 < width and y < height) {
                        const idx = y * width + corridor.x1;
                        level.grid[idx] = Tile.initFloor();
                    }
                }
            }
        }

        // Add some special tiles
        // Treasure chests
        const treasures = [_]struct { x: usize, y: usize }{
            .{ .x = 4, .y = 4 },
            .{ .x = 20, .y = 17 },
            .{ .x = 13, .y = 9 },
        };

        for (treasures) |treasure| {
            if (treasure.x < width and treasure.y < height) {
                const idx = treasure.y * width + treasure.x;
                level.grid[idx] = Tile.initFloor();
            }
        }

        // Add doors
        const doors = [_]struct { x: usize, y: usize }{
            .{ .x = 10, .y = 6 }, // Room 1 exit
            .{ .x = 15, .y = 6 }, // Room 2 entrance
            .{ .x = 6, .y = 11 }, // Corridor junction
            .{ .x = 17, .y = 16 }, // Room 4 entrance
        };

        for (doors) |door| {
            if (door.x < width and door.y < height) {
                const idx = door.y * width + door.x;
                level.grid[idx] = Tile.initDoor();
            }
        }

        // Add some water/hazard tiles
        const hazards = [_]struct { x: usize, y: usize }{
            .{ .x = 7, .y = 15 },
            .{ .x = 8, .y = 15 },
            .{ .x = 7, .y = 16 },
            .{ .x = 8, .y = 16 },
        };

        for (hazards) |hazard| {
            if (hazard.x < width and hazard.y < height) {
                const idx = hazard.y * width + hazard.x;
                level.grid[idx] = Tile.initWater();
            }
        }

        // Add a staircase
        if (22 < width and 18 < height) {
            const idx = 18 * width + 22;
            level.grid[idx] = Tile.initStaircaseDown();
        }

        const idx = 2 * width + 2;
        level.grid[idx] = Tile.initStaircaseDown();
    }

    pub fn generateInterestingLevel2(level: *Level) void {
        const width = Config.level_width;
        const height = Config.level_height;

        // First, fill everything with walls
        for (0..level.grid.len) |i| {
            level.grid[i] = Tile.initWall();
        }

        // Create larger rooms to fill the 80x25 space
        const rooms = [_]struct { x: usize, y: usize, w: usize, h: usize }{
            .{ .x = 2, .y = 2, .w = 15, .h = 8 }, // Large top-left room
            .{ .x = 25, .y = 1, .w = 18, .h = 7 }, // Large top-center room
            .{ .x = 52, .y = 3, .w = 25, .h = 6 }, // Large top-right room
            .{ .x = 1, .y = 14, .w = 12, .h = 9 }, // Bottom-left room
            .{ .x = 20, .y = 12, .w = 16, .h = 11 }, // Large bottom-center room
            .{ .x = 45, .y = 15, .w = 14, .h = 8 }, // Bottom-center-right room
            .{ .x = 65, .y = 12, .w = 13, .h = 11 }, // Bottom-right room
            .{ .x = 45, .y = 1, .w = 6, .h = 5 }, // Small connector room
            .{ .x = 15, .y = 8, .w = 8, .h = 5 }, // Small central room
            .{ .x = 38, .y = 9, .w = 10, .h = 6 }, // Mid-center room
            .{ .x = 60, .y = 8, .w = 8, .h = 5 }, // Small right-center room
        };

        // Carve out rooms
        for (rooms) |room| {
            for (room.y..room.y + room.h) |y| {
                for (room.x..room.x + room.w) |x| {
                    if (x < width and y < height) {
                        const idx = y * width + x;
                        level.grid[idx] = Tile.initFloor();
                    }
                }
            }
        }

        // Create longer corridors connecting rooms
        const corridors = [_]struct { x1: usize, y1: usize, x2: usize, y2: usize }{
            .{ .x1 = 17, .y1 = 6, .x2 = 25, .y2 = 6 }, // Connect top-left to top-center
            .{ .x1 = 43, .y1 = 4, .x2 = 52, .y2 = 4 }, // Connect top-center to top-right
            .{ .x1 = 10, .y1 = 10, .x2 = 10, .y2 = 14 }, // Connect top-left down
            .{ .x1 = 13, .y1 = 18, .x2 = 20, .y2 = 18 }, // Connect bottom-left to bottom-center
            .{ .x1 = 36, .y1 = 17, .x2 = 45, .y2 = 17 }, // Connect bottom-center to bottom-center-right
            .{ .x1 = 59, .y1 = 19, .x2 = 65, .y2 = 19 }, // Connect to bottom-right
            .{ .x1 = 23, .y1 = 8, .x2 = 23, .y2 = 12 }, // Connect top-center to bottom-center
            .{ .x1 = 48, .y1 = 6, .x2 = 48, .y2 = 9 }, // Connect small connector down
            .{ .x1 = 48, .y1 = 12, .x2 = 48, .y2 = 15 }, // Connect mid-center to bottom-center-right
            .{ .x1 = 60, .y1 = 10, .x2 = 65, .y2 = 10 }, // Connect right-center to top-right
            .{ .x1 = 68, .y1 = 9, .x2 = 68, .y2 = 12 }, // Connect top-right to bottom-right
        };

        // Carve out corridors
        for (corridors) |corridor| {
            // Horizontal corridor
            if (corridor.y1 == corridor.y2) {
                const start_x = @min(corridor.x1, corridor.x2);
                const end_x = @max(corridor.x1, corridor.x2);
                for (start_x..end_x + 1) |x| {
                    if (x < width and corridor.y1 < height) {
                        const idx = corridor.y1 * width + x;
                        level.grid[idx] = Tile.initFloor();
                    }
                }
            }
            // Vertical corridor
            else if (corridor.x1 == corridor.x2) {
                const start_y = @min(corridor.y1, corridor.y2);
                const end_y = @max(corridor.y1, corridor.y2);
                for (start_y..end_y + 1) |y| {
                    if (corridor.x1 < width and y < height) {
                        const idx = y * width + corridor.x1;
                        level.grid[idx] = Tile.initFloor();
                    }
                }
            }
        }

        // Add more treasure chests distributed across the larger level
        const treasures = [_]struct { x: usize, y: usize }{
            .{ .x = 5, .y = 5 }, // Top-left room
            .{ .x = 30, .y = 4 }, // Top-center room
            .{ .x = 70, .y = 6 }, // Top-right room
            .{ .x = 7, .y = 18 }, // Bottom-left room
            .{ .x = 28, .y = 20 }, // Bottom-center room
            .{ .x = 50, .y = 18 }, // Bottom-center-right room
            .{ .x = 72, .y = 16 }, // Bottom-right room
            .{ .x = 47, .y = 3 }, // Small connector room
            .{ .x = 42, .y = 12 }, // Mid-center room
        };

        for (treasures) |treasure| {
            if (treasure.x < width and treasure.y < height) {
                const idx = treasure.y * width + treasure.x;
                level.grid[idx] = Tile.initFloor();
            }
        }

        // Add doors at strategic corridor entrances
        const doors = [_]struct { x: usize, y: usize }{
            .{ .x = 17, .y = 7 }, // Top-left room exit
            .{ .x = 24, .y = 6 }, // Top-center room entrance
            .{ .x = 44, .y = 4 }, // Top-center room exit
            .{ .x = 51, .y = 4 }, // Top-right room entrance
            .{ .x = 13, .y = 14 }, // Bottom-left to corridor
            .{ .x = 19, .y = 18 }, // Bottom-left to bottom-center
            .{ .x = 36, .y = 18 }, // Bottom-center to bottom-center-right
            .{ .x = 59, .y = 20 }, // Bottom-center-right to bottom-right
            .{ .x = 23, .y = 11 }, // Vertical corridor junction
            .{ .x = 48, .y = 8 }, // Small connector to mid-center
            .{ .x = 64, .y = 10 }, // Right-center to top-right
        };

        for (doors) |door| {
            if (door.x < width and door.y < height) {
                const idx = door.y * width + door.x;
                level.grid[idx] = Tile.initFloor();
            }
        }

        // Add larger water/hazard areas
        const hazards = [_]struct { x: usize, y: usize }{
            // Small lake in bottom-left
            .{ .x = 3, .y = 16 },  .{ .x = 4, .y = 16 },  .{ .x = 5, .y = 16 },
            .{ .x = 3, .y = 17 },  .{ .x = 4, .y = 17 },  .{ .x = 5, .y = 17 },
            .{ .x = 4, .y = 18 },  .{ .x = 5, .y = 18 },
            // Water feature in large bottom-center room
             .{ .x = 26, .y = 15 },
            .{ .x = 27, .y = 15 }, .{ .x = 28, .y = 15 }, .{ .x = 25, .y = 16 },
            .{ .x = 26, .y = 16 }, .{ .x = 27, .y = 16 }, .{ .x = 28, .y = 16 },
            .{ .x = 29, .y = 16 }, .{ .x = 26, .y = 17 }, .{ .x = 27, .y = 17 },
            .{ .x = 28, .y = 17 },
            // Small hazard in top-right
            .{ .x = 65, .y = 5 },  .{ .x = 66, .y = 5 },
            .{ .x = 65, .y = 6 },  .{ .x = 66, .y = 6 },
        };

        for (hazards) |hazard| {
            if (hazard.x < width and hazard.y < height) {
                const idx = hazard.y * width + hazard.x;
                level.grid[idx] = Tile.initWater();
            }
        }

        // Add multiple staircases for variety
        const staircases = [_]struct { x: usize, y: usize }{
            .{ .x = 3, .y = 6 }, // Top-left room
        };

        for (staircases) |stair| {
            if (stair.x < width and stair.y < height) {
                const idx = stair.y * width + stair.x;
                level.grid[idx] = Tile.initStaircaseDown();
            }
        }
    }
};
