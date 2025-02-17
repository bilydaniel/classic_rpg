const std = @import("std");
const World = @import("world.zig");
const Player = @import("../entities/player.zig");
const Assets = @import("../game/assets.zig");
const Config = @import("../common/config.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const Game = struct {
    allocator: std.mem.Allocator,
    world: World.World,
    player: *Player.Player,
    assets: Assets.assets,

    pub fn init(allocator: std.mem.Allocator) !Game {
        return Game{
            .allocator = allocator,
            .world = try World.World.init(),
            .player = try Player.Player.init(allocator),
            .assets = Assets.assets.init(),
        };
    }

    pub fn Update(this: @This()) void {
        this.player.Update();
    }

    pub fn Draw(this: @This()) void {
        this.world.currentLevel.Draw();
        this.player.Draw(&this.assets);
    }
};
