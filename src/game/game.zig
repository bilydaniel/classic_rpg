const std = @import("std");
const world = @import("world.zig");

pub const Game = struct {
    world: world.World,

    pub fn init() !@This() {
        return Game{
            .world = try world.World.init(),
        };
    }
};
