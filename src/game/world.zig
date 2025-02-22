const level = @import("level.zig");
const std = @import("std");

pub const World = struct {
    currentLevel: level.Level,

    pub fn init() !@This() {
        return World{
            .currentLevel = try level.Level.init(),
        };
    }

    pub fn deinit(this: *World, allocator: std.mem.Allocator) void {
        this.currentLevel.deinit(allocator);
    }
};
