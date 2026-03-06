const std = @import("std");
const Game = @import("game.zig");
const Config = @import("../common/config.zig");
const rl = @import("raylib");

pub var screen: rl.RenderTexture2D = undefined;
pub var scale: f32 = 0.0;
pub var windowWidth: i32 = 0;
pub var windowHeight: i32 = 0;
pub var offsetx: i32 = 0;
pub var offsety: i32 = 0;
pub var scaledWidth: i32 = 0;
pub var scaledHeight: i32 = 0;
pub var scaledWidthHalf: f32 = 0;
pub var scaledHeightHalf: f32 = 0;

pub fn init() !void {
    rl.setTargetFPS(60);
    screen = try rl.loadRenderTexture(Config.game_width, Config.game_height);

    rl.setTextureFilter(screen.texture, .point);

    scale = @min(
        @as(f32, @floatFromInt(Config.window_width)) / @as(f32, Config.game_width),
        @as(f32, @floatFromInt(Config.window_height)) / @as(f32, Config.game_height),
    );

    const scaled_width = @as(i32, @intFromFloat(@as(f32, Config.game_width) * scale));
    const scaled_height = @as(i32, @intFromFloat(@as(f32, Config.game_height) * scale));
    const offset_x = @divFloor(Config.window_width - scaled_width, 2);
    const offset_y = @divFloor(Config.window_height - scaled_height, 2);

    screen = screen;
    scale = scale;
    offsetx = offset_x;
    offsety = offset_y;
    scaledWidth = scaled_width;
    scaledHeight = scaled_height;
    scaledWidthHalf = @as(f32, @floatFromInt(scaled_width)) / 2;
    scaledHeightHalf = @as(f32, @floatFromInt(scaled_height)) / 2;
    windowWidth = scaledWidth;
    windowHeight = scaledHeight;
}

pub fn updateWindow() void {
    const new_width = rl.getScreenWidth();
    const new_height = rl.getScreenHeight();

    if (new_width == windowWidth or new_height == windowHeight) {
        return;
    }

    windowWidth = new_width;
    windowHeight = new_height;

    scale = @min(
        @as(f32, @floatFromInt(windowWidth)) / @as(f32, Config.game_width),
        @as(f32, @floatFromInt(windowHeight)) / @as(f32, Config.game_height),
    );

    const scaled_width = @as(i32, @intFromFloat(@as(f32, Config.game_width) * scale));
    const scaled_height = @as(i32, @intFromFloat(@as(f32, Config.game_height) * scale));

    const offset_x = @divFloor(windowWidth - scaled_width, 2);
    const offset_y = @divFloor(windowHeight - scaled_height, 2);

    scale = scale;
    offsetx = offset_x;
    offsety = offset_y;
    scaledWidth = scaled_width;
    scaledHeight = scaled_height;
    scaledWidthHalf = @as(f32, @floatFromInt(scaled_width)) / 2;
    scaledHeightHalf = @as(f32, @floatFromInt(scaled_height)) / 2;
}
