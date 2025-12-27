const Level = @import("level.zig");
const Pathfinder = @import("pathfinder.zig");
const Entity = @import("entity.zig");
const TilesetManager = @import("tilesetManager.zig");
const std = @import("std");
const Game = @import("game.zig");
const Types = @import("../common/types.zig");
const Utils = @import("../common/utils.zig");
const Systems = @import("Systems.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

//TODO: probably should completely rewrite, links are bullshit, make it like casey???
pub var currentLevel: *Level.Level = undefined; //TODO: mabe switch to id? if i need to delete levels, might be e problem
pub var levels: std.ArrayList(*Level.Level) = undefined;
pub var levelLinks: std.ArrayList(Level.Link) = undefined;

pub fn init(allocator: std.mem.Allocator) !void {
    //TODO: test if i can do this, arraylist of just Level, not Level.Level
    levels = std.ArrayList(*Level.Level).init(allocator);

    var level1 = try Level.Level.init(allocator, 0);
    level1.generateInterestingLevel();
    var level2 = try Level.Level.init(allocator, 1);
    level2.generateInterestingLevel2();
    try levels.append(level1);
    try levels.append(level2);

    levelLinks = std.ArrayList(Level.Link).init(allocator);
    const link1 = Level.Link{
        .from = Level.Location{
            .level = 0,
            .pos = Types.Vector2Int.init(22, 18),
        },
        .to = Level.Location{
            .level = 1,
            .pos = Types.Vector2Int.init(3, 6),
        },
    };

    const link2 = Level.Link{
        .from = Level.Location{
            .level = 1,
            .pos = Types.Vector2Int.init(3, 6),
        },
        .to = Level.Location{
            .level = 0,
            .pos = Types.Vector2Int.init(22, 18),
        },
    };

    try levelLinks.append(link1);
    try levelLinks.append(link2);
}

pub fn draw(tilesetManager: *TilesetManager.TilesetManager) void {
    currentLevel.draw(tilesetManager);
}

pub fn update() void {}
