const Level = @import("level.zig");
const Pathfinder = @import("pathfinder.zig");
const Entity = @import("entity.zig");
const TilesetManager = @import("assetManager.zig");
const std = @import("std");
const Game = @import("game.zig");
const Types = @import("../common/types.zig");
const Utils = @import("../common/utils.zig");
const Systems = @import("Systems.zig");
const LevelGenerator = @import("levelGenerator.zig");

const c = @cImport({
    @cInclude("raylib.h");
});

pub var currentLevel: Types.Vector3Int = undefined;
pub var levels: std.AutoHashMap(Types.Vector3Int, Level.Level) = undefined;

pub fn init(allocator: std.mem.Allocator) !void {
    levels = std.AutoHashMap(Types.Vector3Int, Level.Level).init(allocator);

    //const randomLevel = LevelGenerator.generate();

    var worldPos = Types.Vector3Int.init(0, 0, 0);
    var level1 = try Level.Level.init(allocator, 0, worldPos);
    level1.generateInterestingLevel();

    worldPos.z -= 1;
    var level2 = try Level.Level.init(allocator, 1, worldPos);
    level2.generateInterestingLevel2();

    try levels.put(level1.worldPos, level1);
    try levels.put(level2.worldPos, level2);

    currentLevel = level1.worldPos;
    //currentLevel = randomLevel;
}

pub fn getCurrentLevel() *Level.Level {
    return levels.getPtr(currentLevel).?;
}

pub fn getLevelAt(worldPos: Types.Vector3Int) ?*Level.Level {
    return levels.getPtr(worldPos);
}

pub fn draw() void {
    getCurrentLevel().draw();
}

pub fn update() void {}

pub fn changeCurrentLevel(to: Types.Vector3Int) void {
    currentLevel = to;
}

pub fn changeCurrentLevelDelta(delta: Types.Vector3Int) void {
    //TODO: probably gonna need to be a bit more complex, loading etc.
    currentLevel = Types.vector3IntAdd(currentLevel, delta);
    //TODO: check if the level exists? maybe generate new level?
}
