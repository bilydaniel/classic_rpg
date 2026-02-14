const std = @import("std");
const Config = @import("../common/config.zig");
const Pathfinder = @import("../game/pathfinder.zig");
const Types = @import("../common/types.zig");
const Systems = @import("Systems.zig");
const Entity = @import("entity.zig");
const Level = @import("level.zig");
const UiManager = @import("../ui/uiManager.zig");
const EntityManager = @import("entityManager.zig");
const Movement = @import("movement.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const HighlightTypeEnum = enum {
    cursor,
    pup_deploy,
    square,
    circle,
    movable,
    attackable,
    entity,
};

pub const Highlight = struct {
    pos: Types.Vector2Int,
    type: HighlightTypeEnum,
};

pub const EntityModeEnum = enum {
    none,
    moving,
    attacking,
};

pub var cursor: ?Types.Vector2Int = null;

pub var deployableCells: ?[8]?Types.Vector2Int = null; //TODO: maybe more than 8?, after some power up
pub var deployHighlighted: bool = false;

pub var selectedEntity: ?*Entity.Entity = null; //TODO: maybe switch to id?
pub var selectedEntityMode: EntityModeEnum = .none;
pub var selectedEntityHighlight: ?Highlight = null;

pub var movableTiles: std.ArrayList(Types.Vector2Int) = undefined;
pub var movementHighlighted: bool = false;

pub var highlightedEntity: ?Highlight = null;
pub var highlightedTiles: std.ArrayList(Highlight) = undefined;

pub var attackableTiles: std.ArrayList(Types.Vector2Int) = undefined;
pub var attackHighlighted: bool = false;

pub var selectedPupId: ?u32 = null;
pub var selectedAction: ?UiManager.ActionType = null;

pub var showMenu: UiManager.MenuType = .none;

pub fn init(allocator: std.mem.Allocator) void {
    const highlighted_tiles = std.ArrayList(Highlight).init(allocator);
    highlightedTiles = highlighted_tiles;

    const movable_tiles = std.ArrayList(Types.Vector2Int).init(allocator);
    movableTiles = movable_tiles;

    const attackable_tiles = std.ArrayList(Types.Vector2Int).init(allocator);
    attackableTiles = attackable_tiles;
}

pub fn update() void {
    //TODO: maybe update the cursor through this function????

    if (selectedEntity != null and selectedEntityHighlight != null) {
        selectedEntityHighlight.?.pos = selectedEntity.?.pos;
    }
}

pub fn reset() void {
    cursor = null;

    highlightedTiles.clearRetainingCapacity();
    movableTiles.clearRetainingCapacity();
    deployableCells = null;

    movementHighlighted = false;

    highlightedEntity = null;
    selectedEntity = null;
    selectedEntityHighlight = null;
    selectedEntityMode = .none;
    selectedAction = null;
}

pub fn makeCursor(pos: Types.Vector2Int) void {
    if (cursor == null) {
        cursor = pos;
    }
}
pub fn removeCursor() void {
    cursor = null;
}
pub fn updateCursor() void {
    if (cursor) |curs| {
        if (c.IsKeyPressed(c.KEY_H)) {
            if (curs.x > 0) {
                cursor.?.x -= 1;
            }
        } else if (c.IsKeyPressed(c.KEY_L)) {
            if (curs.x < Config.level_width) {
                cursor.?.x += 1;
            }
        } else if (c.IsKeyPressed(c.KEY_J)) {
            if (curs.y < Config.level_height) {
                cursor.?.y += 1;
            }
        } else if (c.IsKeyPressed(c.KEY_K)) {
            if (curs.y > 0) {
                cursor.?.y -= 1;
            }
        }
    }
}

pub fn makeUpdateCursor(pos: Types.Vector2Int) void {
    makeCursor(pos);
    updateCursor();
}

pub fn highlightMovement(entity: *Entity.Entity) !void {
    if (!movementHighlighted) {
        try Systems.neighboursDistance(entity.pos, entity.movementDistance, &movableTiles);
        try highlightTiles(movableTiles, .movable);
        movementHighlighted = true;
    }
}

//TODO: @refactor, take the type in too
pub fn highlightTile(pos: Types.Vector2Int) !void {
    try highlightedTiles.append(Highlight{
        .pos = pos,
        .type = .pup_deploy,
    });
}

pub fn highlightEntity(pos: Types.Vector2Int) void {
    selectedEntityHighlight = Highlight{
        .pos = pos,
        .type = .circle,
    };
}

pub fn highlightAttack(entity: *Entity.Entity) !void {
    if (!attackHighlighted) {
        try Systems.neighboursDistance(entity.pos, entity.attackDistance, &attackableTiles);
        try highlightTiles(attackableTiles, .attackable);
        attackHighlighted = true;
    }
}

pub fn highlightTiles(tiles: std.ArrayList(Types.Vector2Int), highType: HighlightTypeEnum) !void {
    for (tiles.items) |tile| {
        try highlightedTiles.append(Highlight{
            .pos = Types.Vector2Int.init(tile.x, tile.y),
            .type = highType,
        });
    }
}

pub fn resetMovementHighlight() void {
    movementHighlighted = false;
    movableTiles.clearRetainingCapacity();
    removeHighlightOfType(.movable);
}

pub fn resetAttackHighlight() void {
    attackHighlighted = false;
    attackableTiles.clearRetainingCapacity();
    removeHighlightOfType(.attackable);
}

pub fn removeHighlightOfType(highType: HighlightTypeEnum) void {
    var i: usize = 0;
    while (i < highlightedTiles.items.len) {
        const tile = highlightedTiles.items[i];
        if (tile.type == highType) {
            _ = highlightedTiles.swapRemove(i);
        } else {
            i += 1;
        }
    }
}

pub fn isinMovable(pos: Types.Vector2Int, grid: []Level.Tile, entitiesHash: *const Types.PositionHash) bool {
    if (!Movement.canMove(pos, grid, entitiesHash)) {
        return false;
    }

    for (movableTiles.items) |item| {
        if (Types.vector2IntCompare(item, pos)) {
            return true;
        }
    }
    return false;
}

pub fn isinAttackable(pos: Types.Vector2Int) bool {
    for (attackableTiles.items) |item| {
        if (Types.vector2IntCompare(item, pos)) {
            return true;
        }
    }
    return false;
}

pub fn draw() !void {
    if (highlightedTiles.items.len > 0) {
        for (highlightedTiles.items) |highlight| {
            var highlightColor = c.RED;

            if (highlight.type == .movable) {
                highlightColor = c.BLUE;
            }

            c.DrawRectangleLines(highlight.pos.x * Config.tile_width, highlight.pos.y * Config.tile_height, Config.tile_width, Config.tile_height, highlightColor);
        }
    }

    if (selectedEntityHighlight) |highlight| {
        if (highlight.type == .circle) {
            var highColor = c.RED;
            if (highlight.type == .entity) {
                highColor = c.YELLOW;
            }
            c.DrawCircleLines(highlight.pos.x * Config.tile_width + Config.tile_width / 2, highlight.pos.y * Config.tile_height + Config.tile_height / 2, Config.tile_width / 2, highColor);
            //c.DrawEllipseLines(highlight.pos.x * Config.tile_width + Config.tile_width / 2, highlight.pos.y * Config.tile_height + Config.tile_height, Config.tile_width / 2, Config.tile_height / 3, highlight.color);
            //TODO: figure out the elipse, circle for now
        }
    }

    if (cursor) |cur| {
        c.DrawRectangleLines(cur.x * Config.tile_width, cur.y * Config.tile_height, Config.tile_width, Config.tile_height, c.YELLOW);
    }

    //TODO: @refactor for debugging
    //@refactor
    // if (EntityManager.actingEntity) |e| {
    //     c.DrawCircleLines(e.pos.x * Config.tile_width + Config.tile_width / 2, e.pos.y * Config.tile_height + Config.tile_height / 2, Config.tile_width / 2, c.WHITE);
    // }
}
