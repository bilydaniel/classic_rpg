const std = @import("std");
const Config = @import("../common/config.zig");
const Types = @import("../common/types.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

const TileType = enum {
    empty,
    wall,
    floor,
    water,
    staircase,
};

//TODO: put somewhere else
const Entity = struct {};

pub const Tile = struct {
    texture_id: ?i32,
    tile_type: TileType,
    solid: bool, //TODO: no idea if needed, tile_type already says if solid
    rect: c.Rectangle,
    isAscii: bool,
    ascii: ?[2]u8,
    backgroundColor: c.Color,
};

pub const Link = struct {
    from: Location,
    to: Location,
};

pub const Location = struct {
    level: u32,
    pos: Types.Vector2Int,
};

pub const Level = struct {
    id: u32,
    grid: []Tile,
    //TODO: REMOVE
    tile_texture: c.Texture2D,
    allocator: std.mem.Allocator,
    entities: std.ArrayList(*Entity),
    tilesetTexture: ?*c.Texture2D,

    pub fn init(allocator: std.mem.Allocator, tilesetTexture: ?*c.Texture2D, id: u32) !*Level {
        const level = try allocator.create(Level);
        const tileCount = Config.level_height * Config.level_width;
        const grid = try allocator.alloc(Tile, tileCount);

        for (0..grid.len) |i| {
            grid[i] = Tile{
                .texture_id = null,
                .tile_type = .floor,
                .solid = false,
                .rect = c.Rectangle{
                    .x = @floatFromInt(i % @as(usize, @intCast(Config.tile_width))),
                    .y = @floatFromInt(i / @as(usize, @intCast(Config.tile_height))),
                },
                .isAscii = false,
                .ascii = .{ '#', 0 },
                .backgroundColor = c.DARKBLUE,
            };
        }

        //const tileTexture = c.LoadTexture("assets/base_tile.png");

        const texture_path = "/home/daniel/projects/classic_rpg/assets/base_tile.png";
        const tileTexture = c.LoadTexture(texture_path);

        // Check if texture loading failed
        if (tileTexture.id == 0) {
            std.debug.print("Failed to load texture: {s}\n", .{texture_path});
            return error.TextureLoadFailed;
        }

        const entities = std.ArrayList(*Entity).init(allocator);
        level.* = .{
            .id = id,
            .grid = grid,
            .tile_texture = tileTexture,
            .allocator = allocator,
            .entities = entities,
            .tilesetTexture = tilesetTexture,
        };
        return level;
    }

    pub fn Draw(this: @This()) void {
        for (this.grid, 0..) |tile, index| {
            const x = @as(c_int, @intCast((index % Config.level_width) * Config.tile_width));
            const y = @as(c_int, @intCast((@divFloor(index, Config.level_width)) * Config.tile_height));

            if (tile.isAscii) {
                if (tile.ascii) |ascii| {
                    // Draw background rectangle
                    c.DrawRectangle(x, y, Config.tile_width, Config.tile_height, tile.backgroundColor);

                    // Calculate text centering
                    const font_size = @min(Config.tile_width - 4, Config.tile_height - 4); // Leave some padding
                    const text_width = c.MeasureText(&ascii[0], font_size);
                    const text_x = x + @divFloor(Config.tile_width - text_width, 2);
                    const text_y = y + @divFloor(Config.tile_height - font_size, 2);

                    // Draw text with better contrast
                    // First draw a shadow/outline for better readability
                    c.DrawText(&ascii[0], text_x + 1, text_y + 1, font_size, c.BLACK);

                    // Then draw the main text
                    var text_color = c.WHITE;
                    // Use different colors for different tile types for better visual distinction
                    switch (ascii[0]) {
                        '#' => text_color = c.LIGHTGRAY, // Walls
                        '.' => text_color = c.DARKGRAY, // Floors
                        '$' => text_color = c.YELLOW, // Treasures
                        '+' => text_color = c.DARKBROWN, // Doors
                        '~' => text_color = c.SKYBLUE, // Water
                        '>' => text_color = c.MAGENTA, // Stairs
                        else => text_color = c.WHITE,
                    }
                    // Draw border for better definition
                    //c.DrawRectangleLines(x, y, Config.tile_width, Config.tile_height, tile.backgroundColor);
                    c.DrawText(&ascii[0], text_x, text_y, font_size, text_color);
                }
            }
        }
    }

    pub fn Update(this: *Level) void {
        _ = this;
    }

    pub fn generateInterestingLevel(level: *Level) void {
        const width = Config.level_width;
        const height = Config.level_height;

        // First, fill everything with walls
        for (0..level.grid.len) |i| {
            const x = i % width;
            const y = @divFloor(i, width);

            level.grid[i] = Tile{
                .texture_id = null,
                .tile_type = .wall,
                .solid = true,
                .rect = c.Rectangle{
                    .x = @floatFromInt(x * Config.tile_width),
                    .y = @floatFromInt(y * Config.tile_height),
                    .width = @floatFromInt(Config.tile_width),
                    .height = @floatFromInt(Config.tile_height),
                },
                .isAscii = true,
                .ascii = .{ '#', 0 },
                .backgroundColor = c.DARKGRAY,
            };
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
                        level.grid[idx] = Tile{
                            .texture_id = null,
                            .tile_type = .floor,
                            .solid = false,
                            .rect = c.Rectangle{
                                .x = @floatFromInt(x * Config.tile_width),
                                .y = @floatFromInt(y * Config.tile_height),
                                .width = @floatFromInt(Config.tile_width),
                                .height = @floatFromInt(Config.tile_height),
                            },
                            .isAscii = true,
                            .ascii = .{ '.', 0 },
                            .backgroundColor = c.BEIGE,
                        };
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
                        level.grid[idx] = Tile{
                            .texture_id = null,
                            .tile_type = .floor,
                            .solid = false,
                            .rect = c.Rectangle{
                                .x = @floatFromInt(x * Config.tile_width),
                                .y = @floatFromInt(corridor.y1 * Config.tile_height),
                                .width = @floatFromInt(Config.tile_width),
                                .height = @floatFromInt(Config.tile_height),
                            },
                            .isAscii = true,
                            .ascii = .{ '.', 0 },
                            .backgroundColor = c.LIGHTGRAY,
                        };
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
                        level.grid[idx] = Tile{
                            .texture_id = null,
                            .tile_type = .floor,
                            .solid = false,
                            .rect = c.Rectangle{
                                .x = @floatFromInt(corridor.x1 * Config.tile_width),
                                .y = @floatFromInt(y * Config.tile_height),
                                .width = @floatFromInt(Config.tile_width),
                                .height = @floatFromInt(Config.tile_height),
                            },
                            .isAscii = true,
                            .ascii = .{ '.', 0 },
                            .backgroundColor = c.LIGHTGRAY,
                        };
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
                level.grid[idx] = Tile{
                    .texture_id = null,
                    .tile_type = .floor, // You might want to add a treasure tile type
                    .solid = false,
                    .rect = c.Rectangle{
                        .x = @floatFromInt(treasure.x * Config.tile_width),
                        .y = @floatFromInt(treasure.y * Config.tile_height),
                        .width = @floatFromInt(Config.tile_width),
                        .height = @floatFromInt(Config.tile_height),
                    },
                    .isAscii = true,
                    .ascii = .{ '$', 0 },
                    .backgroundColor = c.GOLD,
                };
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
                level.grid[idx] = Tile{
                    .texture_id = null,
                    .tile_type = .floor,
                    .solid = false,
                    .rect = c.Rectangle{
                        .x = @floatFromInt(door.x * Config.tile_width),
                        .y = @floatFromInt(door.y * Config.tile_height),
                        .width = @floatFromInt(Config.tile_width),
                        .height = @floatFromInt(Config.tile_height),
                    },
                    .isAscii = true,
                    .ascii = .{ '+', 0 },
                    .backgroundColor = c.BROWN,
                };
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
                level.grid[idx] = Tile{
                    .texture_id = null,
                    .tile_type = .floor, // You might want to add a water tile type
                    .solid = false,
                    .rect = c.Rectangle{
                        .x = @floatFromInt(hazard.x * Config.tile_width),
                        .y = @floatFromInt(hazard.y * Config.tile_height),
                        .width = @floatFromInt(Config.tile_width),
                        .height = @floatFromInt(Config.tile_height),
                    },
                    .isAscii = true,
                    .ascii = .{ '~', 0 },
                    .backgroundColor = c.BLUE,
                };
            }
        }

        // Add a staircase
        if (22 < width and 18 < height) {
            const idx = 18 * width + 22;
            level.grid[idx] = Tile{
                .texture_id = null,
                .tile_type = .staircase,
                .solid = false,
                .rect = c.Rectangle{
                    .x = @floatFromInt(22 * Config.tile_width),
                    .y = @floatFromInt(18 * Config.tile_height),
                    .width = @floatFromInt(Config.tile_width),
                    .height = @floatFromInt(Config.tile_height),
                },
                .isAscii = true,
                .ascii = .{ '>', 0 },
                .backgroundColor = c.PURPLE,
            };
        }
    }

    pub fn generateInterestingLevel2(level: *Level) void {
        const width = Config.level_width;
        const height = Config.level_height;

        // First, fill everything with walls
        for (0..level.grid.len) |i| {
            const x = i % width;
            const y = @divFloor(i, width);

            level.grid[i] = Tile{
                .texture_id = null,
                .tile_type = .wall,
                .solid = true,
                .rect = c.Rectangle{
                    .x = @floatFromInt(x * Config.tile_width),
                    .y = @floatFromInt(y * Config.tile_height),
                    .width = @floatFromInt(Config.tile_width),
                    .height = @floatFromInt(Config.tile_height),
                },
                .isAscii = true,
                .ascii = .{ '#', 0 },
                .backgroundColor = c.DARKGRAY,
            };
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
                        level.grid[idx] = Tile{
                            .texture_id = null,
                            .tile_type = .floor,
                            .solid = false,
                            .rect = c.Rectangle{
                                .x = @floatFromInt(x * Config.tile_width),
                                .y = @floatFromInt(y * Config.tile_height),
                                .width = @floatFromInt(Config.tile_width),
                                .height = @floatFromInt(Config.tile_height),
                            },
                            .isAscii = true,
                            .ascii = .{ '.', 0 },
                            .backgroundColor = c.BEIGE,
                        };
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
                        level.grid[idx] = Tile{
                            .texture_id = null,
                            .tile_type = .floor,
                            .solid = false,
                            .rect = c.Rectangle{
                                .x = @floatFromInt(x * Config.tile_width),
                                .y = @floatFromInt(corridor.y1 * Config.tile_height),
                                .width = @floatFromInt(Config.tile_width),
                                .height = @floatFromInt(Config.tile_height),
                            },
                            .isAscii = true,
                            .ascii = .{ '.', 0 },
                            .backgroundColor = c.LIGHTGRAY,
                        };
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
                        level.grid[idx] = Tile{
                            .texture_id = null,
                            .tile_type = .floor,
                            .solid = false,
                            .rect = c.Rectangle{
                                .x = @floatFromInt(corridor.x1 * Config.tile_width),
                                .y = @floatFromInt(y * Config.tile_height),
                                .width = @floatFromInt(Config.tile_width),
                                .height = @floatFromInt(Config.tile_height),
                            },
                            .isAscii = true,
                            .ascii = .{ '.', 0 },
                            .backgroundColor = c.LIGHTGRAY,
                        };
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
                level.grid[idx] = Tile{
                    .texture_id = null,
                    .tile_type = .floor, // You might want to add a treasure tile type
                    .solid = false,
                    .rect = c.Rectangle{
                        .x = @floatFromInt(treasure.x * Config.tile_width),
                        .y = @floatFromInt(treasure.y * Config.tile_height),
                        .width = @floatFromInt(Config.tile_width),
                        .height = @floatFromInt(Config.tile_height),
                    },
                    .isAscii = true,
                    .ascii = .{ '$', 0 },
                    .backgroundColor = c.GOLD,
                };
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
                level.grid[idx] = Tile{
                    .texture_id = null,
                    .tile_type = .floor,
                    .solid = false,
                    .rect = c.Rectangle{
                        .x = @floatFromInt(door.x * Config.tile_width),
                        .y = @floatFromInt(door.y * Config.tile_height),
                        .width = @floatFromInt(Config.tile_width),
                        .height = @floatFromInt(Config.tile_height),
                    },
                    .isAscii = true,
                    .ascii = .{ '+', 0 },
                    .backgroundColor = c.BROWN,
                };
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
                level.grid[idx] = Tile{
                    .texture_id = null,
                    .tile_type = .floor, // You might want to add a water tile type
                    .solid = false,
                    .rect = c.Rectangle{
                        .x = @floatFromInt(hazard.x * Config.tile_width),
                        .y = @floatFromInt(hazard.y * Config.tile_height),
                        .width = @floatFromInt(Config.tile_width),
                        .height = @floatFromInt(Config.tile_height),
                    },
                    .isAscii = true,
                    .ascii = .{ '~', 0 },
                    .backgroundColor = c.BLUE,
                };
            }
        }

        // Add a staircase
        if (3 < width and 6 < height) {
            const idx = 6 * width + 3;
            level.grid[idx] = Tile{
                .texture_id = null,
                .tile_type = .staircase,
                .solid = false,
                .rect = c.Rectangle{
                    .x = @floatFromInt(3 * Config.tile_width),
                    .y = @floatFromInt(6 * Config.tile_height),
                    .width = @floatFromInt(Config.tile_width),
                    .height = @floatFromInt(Config.tile_height),
                },
                .isAscii = true,
                .ascii = .{ '>', 0 },
                .backgroundColor = c.PURPLE,
            };
        }
    }
};
