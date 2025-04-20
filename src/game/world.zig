const level = @import("level.zig");
const std = @import("std");

pub const World = struct {
    allocator: std.mem.Allocator,
    currentLevel: *level.Level,
    levels: std.ArrayList(*level.Level),

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
