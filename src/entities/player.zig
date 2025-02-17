const std = @import("std");
const Assets = @import("../game/assets.zig");
const Config = @import("../common/config.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const Player = struct {
    x: i32,
    y: i32,
    speed: i32,
    timeSinceInput: f32,

    pub fn init(allocator: std.mem.Allocator) !*Player {
        const player = try allocator.create(Player);
        player.* = .{
            .x = 2,
            .y = 3,
            .speed = 1,
            .timeSinceInput = 0,
        };
        return player;
    }

    pub fn Update(this: *Player) void {
        this.timeSinceInput += c.GetFrameTime();
        if (this.timeSinceInput > 0.10) {
            if (c.IsKeyDown(c.KEY_S)) {
                //TODO: wait
                this.timeSinceInput = 0;
            }
            if (c.IsKeyDown(c.KEY_W)) {
                this.y -= this.speed;
                this.timeSinceInput = 0;
            }
            if (c.IsKeyDown(c.KEY_X)) {
                this.y += this.speed;
                this.timeSinceInput = 0;
            }
            if (c.IsKeyDown(c.KEY_A)) {
                this.x -= this.speed;
                this.timeSinceInput = 0;
            }
            if (c.IsKeyDown(c.KEY_D)) {
                this.x += this.speed;
                this.timeSinceInput = 0;
            }
            if (c.IsKeyDown(c.KEY_Q)) {
                this.y -= this.speed;
                this.x -= this.speed;
                this.timeSinceInput = 0;
            }
            if (c.IsKeyDown(c.KEY_E)) {
                this.y -= this.speed;
                this.x += this.speed;
                this.timeSinceInput = 0;
            }
            if (c.IsKeyDown(c.KEY_Z)) {
                this.y += this.speed;
                this.x -= this.speed;
                this.timeSinceInput = 0;
            }
            if (c.IsKeyDown(c.KEY_C)) {
                this.x += this.speed;
                this.y += this.speed;
                this.timeSinceInput = 0;
            }
        }
    }

    pub fn Draw(this: *Player, assets: *const Assets.assets) void {
        c.DrawTexture(assets.playerTexture, @as(c_int, @intCast(this.x * Config.tile_width)), @as(c_int, @intCast(this.y * Config.tile_height)), c.WHITE);
    }
};
