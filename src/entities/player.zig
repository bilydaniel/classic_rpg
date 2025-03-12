const std = @import("std");
const Assets = @import("../game/assets.zig");
const Config = @import("../common/config.zig");
const Types = @import("../common/types.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const Player = struct {
    x: i32,
    y: i32,
    destination: ?Types.Vector2Int,
    speed: i32,

    pub fn init(allocator: std.mem.Allocator) !*Player {
        const player = try allocator.create(Player);
        player.* = .{
            .x = 3,
            .y = 2,
            .speed = 1,
            .destination = null,
        };
        return player;
    }

    pub fn Update(this: *Player) void {
        if (this.destination) |dest| {
            if (this.x < dest.x) {
                this.x += this.speed;
            }
            if (this.x > dest.x) {
                this.x -= this.speed;
            }
            if (this.y > dest.y) {
                this.y -= this.speed;
            }
            if (this.y < dest.y) {
                this.y += this.speed;
            }
        }
    }

    pub fn Draw(this: *Player, assets: *const Assets.assets) void {
        c.DrawTexture(assets.playerTexture, @as(c_int, @intCast(this.x * Config.tile_width)), @as(c_int, @intCast(this.y * Config.tile_height)), c.WHITE);
    }
};
