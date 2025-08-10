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
    none,
    player,
    enemy,
};

pub const highlightTypeEnum = enum {
    cursor,
    pup_deploy,
    square,
    circle,
};

pub const highlight = struct {
    pos: Types.Vector2Int,
    type: highlightTypeEnum,
    color: c.Color,
};

pub const EntityModeEnum = enum {
    none,
    moving,
    attacking,
};

pub const gameState = struct {
    cursor: ?Types.Vector2Int,
    deployableCells: ?[8]?Types.Vector2Int, //TODO: maybe more than 8?, after some power up
    movableTiles: std.ArrayList(Types.Vector2Int),
    currentTurn: currentTurnEnum,
    selectedEntity: ?*Entity.Entity,
    selectedEntityMode: EntityModeEnum,
    highlightedTiles: std.ArrayList(highlight),
    highlightedEntity: ?highlight,

    pub fn init(allocator: std.mem.Allocator) !*gameState {
        const highlighted_tiles = std.ArrayList(highlight).init(allocator);
        const movable_tiles = std.ArrayList(Types.Vector2Int).init(allocator);
        const gamestate = try allocator.create(gameState);

        gamestate.* = .{
            .cursor = null,
            .deployableCells = null,
            .movableTiles = movable_tiles,
            .currentTurn = .none,
            .selectedEntity = null,
            .selectedEntityMode = .none,
            .highlightedTiles = highlighted_tiles,
            .highlightedEntity = null,
        };

        return gamestate;
    }

    pub fn resetDeploy(this: *gameState) void {
        this.cursor = null;
        this.highlightedTiles.clearRetainingCapacity();
        this.deployableCells = null;
    }
};
