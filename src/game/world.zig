const Level = @import("level.zig");
const Pathfinder = @import("pathfinder.zig");
const Entity = @import("entity.zig");
const std = @import("std");
const Types = @import("../common/types.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const World = struct {
    allocator: std.mem.Allocator,
    currentLevel: *Level.Level,
    levels: std.ArrayList(*Level.Level),
    levelLinks: std.ArrayList(Level.Link),
    entities: std.ArrayList(*Entity.Entity),
    tileset: ?*c.Texture2D,
    pathfinder: Pathfinder.Pathfinder,

    //TODO: https://claude.ai/chat/8b0e4ed0-f114-4284-8f99-4b344afaedcb
    //https://chatgpt.com/c/68091cb1-4588-8004-afb8-f2154206753d
    //https://claude.ai/chat/5b723b6b-7166-4163-a2d2-379478335455

    pub fn init(allocator: std.mem.Allocator, tileset: ?*c.Texture2D) !*World {
        const world = try allocator.create(World);
        var levels = std.ArrayList(*Level.Level).init(allocator);
        const entities = std.ArrayList(*Entity.Entity).init(allocator);

        var level1 = try Level.Level.init(allocator, tileset, 0);
        level1.generateInterestingLevel();
        var level2 = try Level.Level.init(allocator, tileset, 1);
        level2.generateInterestingLevel2();
        try levels.append(level1);
        try levels.append(level2);

        var levelLinks = std.ArrayList(Level.Link).init(allocator);
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

        world.* = .{
            .currentLevel = level1,
            .allocator = allocator,
            .levels = levels,
            .entities = entities,
            .tileset = tileset,
            .levelLinks = levelLinks,
            .pathfinder = Pathfinder.Pathfinder.init(allocator),
        };

        return world;
    }

    pub fn Draw(this: *World) void {
        this.currentLevel.Draw();
    }

    pub fn Update(this: *World) void {
        for (this.levels.items) |lvl| {
            lvl.Update();
        }
    }
};
