const std = @import("std");
const Assets = @import("../game/assets.zig");
const Config = @import("../common/config.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const Enemy = struct {
    x: i32,
    y: i32,
    speed: i32,

    pub fn init(allocator: std.mem.Allocator) !*Enemy {
        const enemy = try allocator.create(Enemy);
        enemy.* = .{
            .x = 5,
            .y = 8,
            .speed = 1,
        };
        return enemy;
    }

    pub fn deinit(this: *Enemy, allocator: std.mem.Allocator) void {
        allocator.destroy(this);
    }

    pub fn Update(this: *Enemy, assets: *const Assets.Assets) void {
        _ = this;
        _ = assets;
    }

    pub fn Draw(this: *Enemy, assets: *const Assets.Assets) void {
        c.DrawTexture(assets.enemy, @as(c_int, @intCast(this.x * Config.tile_width)), @as(c_int, @intCast(this.y * Config.tile_height)), c.WHITE);
    }
};
