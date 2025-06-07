const level = @import("level.zig");
const Entity = @import("entity.zig");
const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const World = struct {
    allocator: std.mem.Allocator,
    currentLevel: *level.Level,
    levels: std.ArrayList(*level.Level),
    entities: std.ArrayList(*Entity.Entity),
    tileset: c.Texture2D,

    //TODO: https://claude.ai/chat/8b0e4ed0-f114-4284-8f99-4b344afaedcb
    //https://chatgpt.com/c/68091cb1-4588-8004-afb8-f2154206753d
    //https://claude.ai/chat/5b723b6b-7166-4163-a2d2-379478335455

    pub fn init(allocator: std.mem.Allocator, tileset: c.Texture2D) !*World {
        const world = try allocator.create(World);
        const levels = std.ArrayList(*level.Level).init(allocator);
        const entities = std.ArrayList(*Entity.Entity).init(allocator);

        world.* = .{
            .currentLevel = try level.Level.init(allocator),
            .allocator = allocator,
            .levels = levels,
            .entities = entities,
            .tileset = tileset,
        };

        return world;
    }

    pub fn Draw(this: *World) void {
        this.currentLevel.Draw(this.tileset);
    }

    pub fn Update(this: *World) void {
        for (this.levels.items) |lvl| {
            lvl.Update();
        }
    }
};
