const rl = @import("raylib");
const std = @import("std");

pub var tileset: rl.Texture2D = undefined;
pub var urizenTileset: rl.Texture2D = undefined;

pub fn init() !void {
    urizenTileset = try rl.loadTexture("assets/urizen_tileset.png");
    tileset = try rl.loadTexture("assets/tileset.png");
    tileset = urizenTileset;
}

pub const TileNames = enum(i32) {
    wall_1 = 0,

    staircase_down = 23,
    staircase_up = 24,

    floor_1 = 1030,

    water_1 = 1049,

    puppet_1 = 2773,
    robot_1 = 2780,

    player = 5666,
};
