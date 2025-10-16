const std = @import("std");
const Types = @import("../common/types.zig");

// ============================================================================
// PROBLEM: Finding nearby entities is slow
// ============================================================================
//
// Current approach (BAD):
// for (entities.items) |entity| {
//     if (distance(player.pos, entity.pos) < 5) {
//         // Found nearby entity
//     }
// }
//
// With 1000 entities, you check ALL 1000 every time!
// O(n) complexity - gets slower as entities increase
//
// ============================================================================

// ============================================================================
// SOLUTION: Spatial Hash
// ============================================================================
//
// Divide world into grid cells (e.g., 5x5 tiles per cell)
// Each cell stores a list of entities in that area
// To find nearby entities, only check entities in nearby cells
//
// Example world (each number is a cell):
//   0 | 1 | 2 | 3
//   4 | 5 | 6 | 7
//   8 | 9 | 10| 11
//
// Entity at (12, 7) is in cell 5
// To find entities near (12, 7), only check cells: 1, 2, 4, 5, 6, 9, 10
// That's ~7 cells instead of the entire world!
//
// ============================================================================

pub const SpatialHash = struct {
    // Cell size in world units (tiles)
    // Smaller = more precise but more memory
    // Larger = less precise but less memory
    cell_size: i32,

    // HashMap: cell_id -> list of entities in that cell
    cells: std.AutoHashMap(i64, std.ArrayList(u32)),

    // Quick lookup: entity_id -> which cell it's in
    entity_to_cell: std.AutoHashMap(u32, i64),

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, cell_size: i32) SpatialHash {
        return SpatialHash{
            .cell_size = cell_size,
            .cells = std.AutoHashMap(i64, std.ArrayList(u32)).init(allocator),
            .entity_to_cell = std.AutoHashMap(u32, i64).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SpatialHash) void {
        var iter = self.cells.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.cells.deinit();
        self.entity_to_cell.deinit();
    }

    // Insert an entity at a position
    pub fn insert(self: *SpatialHash, entity_id: u32, pos: Types.Vector2Int) !void {
        const cell_id = self.positionToCellId(pos);

        // Get or create cell
        const result = try self.cells.getOrPut(cell_id);
        if (!result.found_existing) {
            result.value_ptr.* = std.ArrayList(u32).init(self.allocator);
        }

        // Add entity to cell
        try result.value_ptr.append(entity_id);

        // Remember which cell this entity is in
        try self.entity_to_cell.put(entity_id, cell_id);
    }

    // Remove an entity (when it's deleted)
    pub fn remove(self: *SpatialHash, entity_id: u32) void {
        // Find which cell the entity is in
        const cell_id = self.entity_to_cell.get(entity_id) orelse return;

        // Remove from cell
        if (self.cells.getPtr(cell_id)) |cell| {
            var i: usize = 0;
            while (i < cell.items.len) {
                if (cell.items[i] == entity_id) {
                    _ = cell.swapRemove(i);
                    break;
                }
                i += 1;
            }
        }

        // Remove from lookup
        _ = self.entity_to_cell.remove(entity_id);
    }

    // Update an entity's position (when it moves)
    pub fn update(self: *SpatialHash, entity_id: u32, new_pos: Types.Vector2Int) !void {
        const new_cell_id = self.positionToCellId(new_pos);
        const old_cell_id = self.entity_to_cell.get(entity_id);

        // If entity moved to a different cell, update it
        if (old_cell_id == null or old_cell_id.? != new_cell_id) {
            self.remove(entity_id);
            try self.insert(entity_id, new_pos);
        }
    }

    // Get all entities near a position (THIS IS THE FAST PART!)
    pub fn queryRadius(self: *SpatialHash, center: Types.Vector2Int, radius: i32, result: *std.ArrayList(u32)) !void {
        result.clearRetainingCapacity();

        // Calculate which cells to check
        const min_x = @divFloor(center.x - radius, self.cell_size);
        const max_x = @divFloor(center.x + radius, self.cell_size);
        const min_y = @divFloor(center.y - radius, self.cell_size);
        const max_y = @divFloor(center.y + radius, self.cell_size);

        // Check all cells in range
        var y = min_y;
        while (y <= max_y) : (y += 1) {
            var x = min_x;
            while (x <= max_x) : (x += 1) {
                const cell_id = self.coordsToCellId(x, y);

                if (self.cells.get(cell_id)) |entities_in_cell| {
                    // Add all entities from this cell to results
                    try result.appendSlice(entities_in_cell.items);
                }
            }
        }
    }

    // Get entity at exact position
    pub fn getEntityAt(self: *SpatialHash, pos: Types.Vector2Int, entity_positions: std.AutoHashMap(u32, Types.Vector2Int)) ?u32 {
        const cell_id = self.positionToCellId(pos);

        if (self.cells.get(cell_id)) |entities_in_cell| {
            for (entities_in_cell.items) |entity_id| {
                if (entity_positions.get(entity_id)) |entity_pos| {
                    if (Types.vector2IntCompare(entity_pos, pos)) {
                        return entity_id;
                    }
                }
            }
        }

        return null;
    }

    // Get all entities in a rectangular area
    pub fn queryRect(self: *SpatialHash, min: Types.Vector2Int, max: Types.Vector2Int, result: *std.ArrayList(u32)) !void {
        result.clearRetainingCapacity();

        const min_cell_x = @divFloor(min.x, self.cell_size);
        const max_cell_x = @divFloor(max.x, self.cell_size);
        const min_cell_y = @divFloor(min.y, self.cell_size);
        const max_cell_y = @divFloor(max.y, self.cell_size);

        var y = min_cell_y;
        while (y <= max_cell_y) : (y += 1) {
            var x = min_cell_x;
            while (x <= max_cell_x) : (x += 1) {
                const cell_id = self.coordsToCellId(x, y);

                if (self.cells.get(cell_id)) |entities_in_cell| {
                    try result.appendSlice(entities_in_cell.items);
                }
            }
        }
    }

    // Clear all entities (for level change, etc.)
    pub fn clear(self: *SpatialHash) void {
        var iter = self.cells.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.cells.clearRetainingCapacity();
        self.entity_to_cell.clearRetainingCapacity();
    }

    // Debug: print statistics
    pub fn printStats(self: *SpatialHash) void {
        var total_entities: usize = 0;
        var non_empty_cells: usize = 0;
        var max_entities_in_cell: usize = 0;

        var iter = self.cells.iterator();
        while (iter.next()) |entry| {
            const count = entry.value_ptr.items.len;
            if (count > 0) {
                non_empty_cells += 1;
                total_entities += count;
                if (count > max_entities_in_cell) {
                    max_entities_in_cell = count;
                }
            }
        }

        std.debug.print("Spatial Hash Stats:\n" ++
            "  Total cells: {}\n" ++
            "  Non-empty cells: {}\n" ++
            "  Total entities: {}\n" ++
            "  Max entities in one cell: {}\n" ++
            "  Avg entities per non-empty cell: {d:.2}\n", .{
            self.cells.count(),
            non_empty_cells,
            total_entities,
            max_entities_in_cell,
            if (non_empty_cells > 0) @as(f32, @floatFromInt(total_entities)) / @as(f32, @floatFromInt(non_empty_cells)) else 0.0,
        });
    }

    // ========================================================================
    // Helper functions
    // ========================================================================

    fn positionToCellId(self: *SpatialHash, pos: Types.Vector2Int) i64 {
        const cell_x = @divFloor(pos.x, self.cell_size);
        const cell_y = @divFloor(pos.y, self.cell_size);
        return self.coordsToCellId(cell_x, cell_y);
    }

    fn coordsToCellId(self: *SpatialHash, cell_x: i32, cell_y: i32) i64 {
        _ = self;
        // Combine x and y into a single ID
        // Using bit shifting for efficient packing
        return (@as(i64, cell_x) << 32) | @as(i64, @bitCast(@as(u32, @bitCast(cell_y))));
    }
};

// ============================================================================
// Integration Example
// ============================================================================

pub const EntityManager = struct {
    spatial_hash: SpatialHash,
    positions: std.AutoHashMap(u32, Types.Vector2Int),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) EntityManager {
        return EntityManager{
            // Cell size of 5 means each cell covers 5x5 tiles
            .spatial_hash = SpatialHash.init(allocator, 5),
            .positions = std.AutoHashMap(u32, Types.Vector2Int).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *EntityManager) void {
        self.spatial_hash.deinit();
        self.positions.deinit();
    }

    pub fn addEntity(self: *EntityManager, entity_id: u32, pos: Types.Vector2Int) !void {
        try self.positions.put(entity_id, pos);
        try self.spatial_hash.insert(entity_id, pos);
    }

    pub fn removeEntity(self: *EntityManager, entity_id: u32) void {
        self.spatial_hash.remove(entity_id);
        _ = self.positions.remove(entity_id);
    }

    pub fn moveEntity(self: *EntityManager, entity_id: u32, new_pos: Types.Vector2Int) !void {
        try self.positions.put(entity_id, new_pos);
        try self.spatial_hash.update(entity_id, new_pos);
    }

    // FAST: Only checks nearby entities
    pub fn getEntitiesNear(self: *EntityManager, pos: Types.Vector2Int, radius: i32) !std.ArrayList(u32) {
        var result = std.ArrayList(u32).init(self.allocator);
        try self.spatial_hash.queryRadius(pos, radius, &result);
        return result;
    }

    // FAST: Only checks one cell
    pub fn getEntityAt(self: *EntityManager, pos: Types.Vector2Int) ?u32 {
        return self.spatial_hash.getEntityAt(pos, self.positions);
    }
};

// ============================================================================
// Performance Comparison
// ============================================================================

pub fn performanceTest(allocator: std.mem.Allocator) !void {
    var timer = try std.time.Timer.start();

    // Create 1000 entities
    var entity_manager = EntityManager.init(allocator);
    defer entity_manager.deinit();

    var i: u32 = 0;
    while (i < 1000) : (i += 1) {
        const pos = Types.Vector2Int{
            .x = @mod(@as(i32, @intCast(i * 7)), 100),
            .y = @mod(@as(i32, @intCast(i * 13)), 100),
        };
        try entity_manager.addEntity(i, pos);
    }

    // Test query performance
    const query_pos = Types.Vector2Int{ .x = 50, .y = 50 };
    const query_radius = 10;

    timer.reset();
    const nearby = try entity_manager.getEntitiesNear(query_pos, query_radius);
    defer nearby.deinit();
    const spatial_hash_time = timer.read();

    std.debug.print("\nPerformance Test (1000 entities):\n" ++
        "  Spatial hash query: {} ns\n" ++
        "  Found {} entities within radius {}\n", .{
        spatial_hash_time,
        nearby.items.len,
        query_radius,
    });

    entity_manager.spatial_hash.printStats();
}

// ============================================================================
// Usage in Your Game
// ============================================================================

// Replace this:
pub fn OLD_getEntityByPos(entities: std.ArrayList(*Entity), pos: Types.Vector2Int) ?*Entity {
    for (entities.items) |entity| { // O(n) - BAD!
        if (Types.vector2IntCompare(entity.pos, pos)) {
            return entity;
        }
    }
    return null;
}

// With this:
pub fn NEW_getEntityByPos(entity_manager: *EntityManager, pos: Types.Vector2Int) ?u32 {
    return entity_manager.getEntityAt(pos); // O(1) average - GOOD!
}

// Replace this:
pub fn OLD_checkCombatStart(player: *Entity, entities: std.ArrayList(*Entity)) bool {
    for (entities.items) |entity| { // O(n) - checks ALL entities
        if (entity.data == .enemy) {
            const distance = Types.vector2Distance(player.pos, entity.pos);
            if (distance < 3) {
                return true;
            }
        }
    }
    return false;
}

// With this:
pub fn NEW_checkCombatStart(entity_manager: *EntityManager, player_id: u32, player_pos: Types.Vector2Int) !bool {
    const nearby = try entity_manager.getEntitiesNear(player_pos, 3); // Only checks nearby cells!
    defer nearby.deinit();

    for (nearby.items) |entity_id| {
        if (entity_id != player_id) {
            // Check if enemy
            return true;
        }
    }
    return false;
}

// ============================================================================
// Choosing Cell Size
// ============================================================================
//
// Too small (e.g., 1 tile per cell):
//   - More memory usage (more cells)
//   - More overhead updating cells when moving
//   - Very precise queries
//
// Too large (e.g., 50 tiles per cell):
//   - Less memory usage
//   - Less overhead
//   - Less precise (still checks many entities)
//
// Good rule of thumb:
//   cell_size = 2-3 times your typical query radius
//
// If you usually search within 5 tiles, use cell_size = 10-15
// If you usually search within 10 tiles, use cell_size = 20-30
//
// For your game with combat range ~3 tiles, cell_size = 5-8 is good
//
// ============================================================================

// Example Entity struct
const Entity = struct {
    id: u32,
    pos: Types.Vector2Int,
    data: union(enum) {
        player,
        enemy,
        puppet,
    },
};
