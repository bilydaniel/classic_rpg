const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const Enemy = struct{
    x: i32,
    y: i32,
    speed: i32,

    pub fn init(allocator: std.mem.Allocator) !*Enemy {
        const enemy = try allocator.create(Enemy);
        enemy.* = .{
            .x = 5,
            .y = 8,
            .speed = 1,
            .timeSinceInput = 0,
        };
        return player;
    }
}
