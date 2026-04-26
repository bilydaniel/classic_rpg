const std = @import("std");
const rl = @import("raylib");
const Types = @import("types.zig");
const Utils = @import("utils.zig");
const Config = @import("config.zig");
const Allocators = @import("allocators.zig");

pub const shapes: std.ArrayList(Types.Shape) = undefined;

pub fn init() void {
    shapes = std.ArrayList(Types.Shape).empty;
}

pub fn addTile(tilePos: Types.Vector2Int) !void {
    const pixelPos = Utils.vector2TileToPixel(tilePos);
    const shape = Types.Shape.initRectangle(pixelPos, Config.tile_width, Config.tile_height, rl.Color.red);
    try shapes.append(Allocators.persistent, shape);
}

pub fn addRect(x: i32, y: i32, h: i32, w: i32) !void {
    const pixelX = x * Config.tile_width;
    const pixelY = y * Config.tile_height;
    const pixelW = w * Config.tile_width;
    const pixelH = h * Config.tile_height;
    const shape = Types.Shape.initRectangle(pixelPos, pixelW, pixelH, rl.Color.red);
    try shapes.append(Allocators.persistent, shape);
}
