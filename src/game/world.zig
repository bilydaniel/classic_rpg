const level = @import("level.zig");
const std = @import("std");

pub const World = struct {
    allocator: std.mem.Allocator,
    currentLevel: *level.Level,
    levels: std.ArrayList(*level.Level),
    //TODO: https://claude.ai/chat/8b0e4ed0-f114-4284-8f99-4b344afaedcb
    //https://chatgpt.com/c/68091cb1-4588-8004-afb8-f2154206753d
    //https://claude.ai/chat/5b723b6b-7166-4163-a2d2-379478335455

    pub fn init(allocator: std.mem.Allocator) !*World {
        const world = try allocator.create(World);
        const levels = std.ArrayList(*level.Level).init(allocator);

        world.* = .{
            .currentLevel = try level.Level.init(allocator),
            .allocator = allocator,
            .levels = levels,
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
