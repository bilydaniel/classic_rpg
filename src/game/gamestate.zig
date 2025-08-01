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

pub const gameState = struct {
    cursor: ?Types.Vector2Int,
    deployableCells: ?[8]?Types.Vector2Int,
    currentTurn: currentTurnEnum,
    selectedEntity: ?*Entity.Entity,

    pub fn init(allocator: std.mem.Allocator) !*gameState {
        const gamestate = try allocator.create(gameState);
        gamestate.* = .{
            .cursor = null,
            .deployableCells = null,
            .currentTurn = .none,
            .selectedEntity = null,
        };
        return gamestate;
    }
};
