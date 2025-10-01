const std = @import("std");
const Config = @import("../common/config.zig");
const Pathfinder = @import("../game/pathfinder.zig");
const Types = @import("../common/types.zig");
const Systems = @import("Systems.zig");
const Entity = @import("entity.zig");
const Level = @import("level.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const currentTurnEnum = enum {
    // TODO: for now only player and enemy, I want to have grups of enemies that will fight
    // amongst each other, will do later
    player,
    enemy,
};

pub const highlightTypeEnum = enum {
    cursor,
    pup_deploy,
    square,
    circle,
    movable,
    entity,
};

pub const highlight = struct {
    pos: Types.Vector2Int,
    type: highlightTypeEnum,
};

pub const EntityModeEnum = enum {
    none,
    moving,
    attacking,
};

pub const gameState = struct {
    cursor: ?Types.Vector2Int,

    deployableCells: ?[8]?Types.Vector2Int, //TODO: maybe more than 8?, after some power up
    deployHighlighted: bool,

    currentTurn: currentTurnEnum,

    selectedEntity: ?*Entity.Entity,
    selectedEntityMode: EntityModeEnum,

    movableTiles: std.ArrayList(Types.Vector2Int),
    movementHighlighted: bool,

    highlightedEntity: ?highlight,
    highlightedTiles: std.ArrayList(highlight),

    pub fn init(allocator: std.mem.Allocator) !*gameState {
        const highlighted_tiles = std.ArrayList(highlight).init(allocator);
        const movable_tiles = std.ArrayList(Types.Vector2Int).init(allocator);
        const gamestate = try allocator.create(gameState);

        gamestate.* = .{
            .cursor = null,
            .deployableCells = null,
            .movableTiles = movable_tiles,
            .currentTurn = .player,
            .selectedEntity = null,
            .selectedEntityMode = .none,
            .highlightedTiles = highlighted_tiles,
            .highlightedEntity = null,
            .deployHighlighted = false,
            .movementHighlighted = false,
        };

        return gamestate;
    }

    pub fn reset(this: *gameState) void {
        this.cursor = null;

        this.highlightedTiles.clearRetainingCapacity();
        this.movableTiles.clearRetainingCapacity();
        this.deployableCells = null;

        this.deployHighlighted = false;
        this.movementHighlighted = false;

        this.highlightedEntity = null;
        this.currentTurn = .player;
        this.selectedEntity = null;
        this.selectedEntityMode = .none;
    }

    pub fn makeCursor(this: *gameState, pos: Types.Vector2Int) void {
        if (this.cursor == null) {
            this.cursor = pos;
        }
    }
    pub fn removeCursor(this: *gameState) void {
        if (this.cursor != null) {
            this.cursor = null;
        }
    }
    pub fn updateCursor(this: *gameState) void {
        if (this.cursor) |cursor| {
            if (c.IsKeyPressed(c.KEY_H)) {
                if (cursor.x > 0) {
                    this.cursor.?.x -= 1;
                }
            } else if (c.IsKeyPressed(c.KEY_L)) {
                if (cursor.x < Config.level_width) {
                    this.cursor.?.x += 1;
                }
            } else if (c.IsKeyPressed(c.KEY_J)) {
                if (cursor.y < Config.level_height) {
                    this.cursor.?.y += 1;
                }
            } else if (c.IsKeyPressed(c.KEY_K)) {
                if (cursor.y > 0) {
                    this.cursor.?.y -= 1;
                }
            }
        }
    }

    pub fn highlightMovement(this: *gameState, entity: *Entity.Entity) !void {
        if (!this.movementHighlighted) {
            try Systems.neighboursDistance(entity.pos, entity.movementDistance, &this.movableTiles);
            try this.highlightTiles(this.movableTiles, .movable);
            this.movementHighlighted = true;
        }
    }

    pub fn highlightTiles(this: *gameState, tiles: std.ArrayList(Types.Vector2Int), highType: highlightTypeEnum) !void {
        for (tiles.items) |tile| {
            try this.highlightedTiles.append(highlight{
                .pos = Types.Vector2Int.init(tile.x, tile.y),
                .type = highType,
            });
        }
    }

    pub fn resetMovementHighlight(this: *gameState) void {
        this.movementHighlighted = false;
        this.movableTiles.clearRetainingCapacity();
        this.removeHighlightOfType(.movable);
    }

    pub fn removeHighlightOfType(this: *gameState, highType: highlightTypeEnum) void {
        //TODO: @continue, dies on swapremove, no idea how, fix
        var i: usize = 0;
        while (i < this.highlightedTiles.items.len) {
            const tile = this.highlightedTiles.items[i];
            if (tile.type == highType) {
                _ = this.highlightedTiles.swapRemove(i);
            } else {
                i += 1;
            }
        }
    }

    pub fn isinMovable(this: *gameState, pos: Types.Vector2Int) bool {
        for (this.movableTiles.items) |item| {
            if (Types.vector2IntCompare(item, pos)) {
                return true;
            }
        }
        return false;
    }
};
