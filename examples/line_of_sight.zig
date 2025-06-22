const std = @import("std");

// Tile types
const TileType = enum {
    floor,
    wall,
};

const Tile = struct {
    tile_type: TileType,
    seen: bool = false,
    visible: bool = false, // Currently visible this turn
};

const Point = struct {
    x: i32,
    y: i32,
};

const Map = struct {
    width: usize,
    height: usize,
    tiles: []Tile,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize) !Map {
        const tiles = try allocator.alloc(Tile, width * height);
        return Map{
            .width = width,
            .height = height,
            .tiles = tiles,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Map) void {
        self.allocator.free(self.tiles);
    }

    pub fn getTile(self: *const Map, x: i32, y: i32) ?*Tile {
        if (x < 0 or y < 0 or x >= self.width or y >= self.height) return null;
        const idx = @as(usize, @intCast(y)) * self.width + @as(usize, @intCast(x));
        return &self.tiles[idx];
    }

    pub fn isBlocking(self: *const Map, x: i32, y: i32) bool {
        const tile = self.getTile(x, y) orelse return true;
        return tile.tile_type == .wall;
    }
};

// Bresenham's line algorithm for ray casting
fn castRay(map: *Map, x0: i32, y0: i32, x1: i32, y1: i32) void {
    const dx = @abs(x1 - x0);
    const dy = @abs(y1 - y0);
    var x = x0;
    var y = y0;

    const x_inc: i32 = if (x1 > x0) 1 else -1;
    const y_inc: i32 = if (y1 > y0) 1 else -1;
    var err = dx - dy;

    while (true) {
        // Mark current tile as visible and seen
        if (map.getTile(x, y)) |tile| {
            tile.visible = true;
            tile.seen = true;

            // If we hit a wall, stop the ray here
            if (tile.tile_type == .wall) {
                break;
            }
        }

        // Check if we've reached the end point
        if (x == x1 and y == y1) break;

        const e2 = 2 * err;
        if (e2 > -dy) {
            err -= dy;
            x += x_inc;
        }
        if (e2 < dx) {
            err += dx;
            y += y_inc;
        }
    }
}

// Calculate field of view using ray casting
pub fn calculateFOV(map: *Map, center_x: i32, center_y: i32, radius: i32) void {
    // Clear previous visibility
    for (map.tiles) |*tile| {
        tile.visible = false;
    }

    // Mark center as visible
    if (map.getTile(center_x, center_y)) |tile| {
        tile.visible = true;
        tile.seen = true;
    }

    // Cast rays in a circle around the center
    const num_rays = radius * 8; // More rays = smoother circle, adjust as needed

    var i: i32 = 0;
    while (i < num_rays) : (i += 1) {
        const angle = @as(f32, @floatFromInt(i)) * (2.0 * std.math.pi) / @as(f32, @floatFromInt(num_rays));

        const target_x = center_x + @as(i32, @intFromFloat(@cos(angle) * @as(f32, @floatFromInt(radius))));
        const target_y = center_y + @as(i32, @intFromFloat(@sin(angle) * @as(f32, @floatFromInt(radius))));

        castRay(map, center_x, center_y, target_x, target_y);
    }
}

// Alternative: Symmetric shadowcasting (more efficient for larger radii)
pub fn calculateFOVShadowcast(map: *Map, center_x: i32, center_y: i32, radius: i32) void {
    // Clear previous visibility
    for (map.tiles) |*tile| {
        tile.visible = false;
    }

    // Mark center as visible
    if (map.getTile(center_x, center_y)) |tile| {
        tile.visible = true;
        tile.seen = true;
    }

    // Cast shadows in 8 octants
    var octant: u8 = 0;
    while (octant < 8) : (octant += 1) {
        castShadow(map, center_x, center_y, radius, 1, 1.0, 0.0, octant);
    }
}

fn castShadow(map: *Map, center_x: i32, center_y: i32, radius: i32, row: i32, start_slope: f32, end_slope: f32, octant: u8) void {
    if (start_slope < end_slope or row > radius) return;

    var next_start_slope = start_slope;
    var blocked = false;

    var col = @as(i32, @intFromFloat(@as(f32, @floatFromInt(row)) * start_slope));
    while (col <= @as(i32, @intFromFloat(@as(f32, @floatFromInt(row)) * end_slope))) : (col += 1) {
        const map_pos = transformOctant(center_x, center_y, row, col, octant);
        const x = map_pos.x;
        const y = map_pos.y;

        // Check if within radius (circular)
        const dx = x - center_x;
        const dy = y - center_y;
        if (dx * dx + dy * dy > radius * radius) {
            col += 1;
            continue;
        }

        if (map.getTile(x, y)) |tile| {
            tile.visible = true;
            tile.seen = true;

            if (blocked) {
                if (map.isBlocking(x, y)) {
                    next_start_slope = @as(f32, @floatFromInt(col + 1)) / @as(f32, @floatFromInt(row));
                } else {
                    blocked = false;
                    start_slope = next_start_slope;
                }
            } else if (map.isBlocking(x, y)) {
                blocked = true;
                next_start_slope = @as(f32, @floatFromInt(col + 1)) / @as(f32, @floatFromInt(row));
                castShadow(map, center_x, center_y, radius, row + 1, start_slope, @as(f32, @floatFromInt(col)) / @as(f32, @floatFromInt(row)), octant);
            }
        }
    }

    if (!blocked) {
        castShadow(map, center_x, center_y, radius, row + 1, start_slope, end_slope, octant);
    }
}

fn transformOctant(center_x: i32, center_y: i32, row: i32, col: i32, octant: u8) Point {
    return switch (octant) {
        0 => Point{ .x = center_x + col, .y = center_y - row },
        1 => Point{ .x = center_x + row, .y = center_y - col },
        2 => Point{ .x = center_x + row, .y = center_y + col },
        3 => Point{ .x = center_x + col, .y = center_y + row },
        4 => Point{ .x = center_x - col, .y = center_y + row },
        5 => Point{ .x = center_x - row, .y = center_y + col },
        6 => Point{ .x = center_x - row, .y = center_y - col },
        7 => Point{ .x = center_x - col, .y = center_y - row },
        else => unreachable,
    };
}

// Example usage
pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var map = try Map.init(allocator, 50, 50);
    defer map.deinit();

    // Initialize some walls for testing
    for (0..map.height) |y| {
        for (0..map.width) |x| {
            const tile = map.getTile(@intCast(x), @intCast(y)).?;
            // Create some walls randomly or in patterns
            if (x == 10 or y == 10) {
                tile.tile_type = .wall;
            } else {
                tile.tile_type = .floor;
            }
        }
    }

    // Calculate FOV from player position
    const player_x: i32 = 25;
    const player_y: i32 = 25;
    const view_radius: i32 = 8;

    // Use either ray casting or shadowcasting
    calculateFOV(&map, player_x, player_y, view_radius);
    // OR: calculateFOVShadowcast(&map, player_x, player_y, view_radius);

    // Now you can check tile.visible for rendering current FOV
    // and tile.seen for rendering previously explored areas
}
