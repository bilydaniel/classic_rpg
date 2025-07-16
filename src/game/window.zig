const std = @import("std");
const Game = @import("game.zig");
const Config = @import("../common/config.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub var screen: c.RenderTexture2D = .{};
pub var scale: f32 = 0.0;
pub var windowWidth: i32 = 0;
pub var windowHeight: i32 = 0;
pub var offsetx: i32 = 0;
pub var offsety: i32 = 0;
pub var scaledWidth: i32 = 0;
pub var scaledHeight: i32 = 0;
pub var camera: c.Camera2D = .{};

pub fn init() void {
    screen = c.LoadRenderTexture(Config.game_width, Config.game_height);
    c.SetTextureFilter(screen.texture, c.TEXTURE_FILTER_POINT); //TODO:try TEXTURE_FILTER_BILINEAR for blurry effect

    scale = @min(
        @as(f32, @floatFromInt(Config.window_width)) / @as(f32, Config.game_width),
        @as(f32, @floatFromInt(Config.window_height)) / @as(f32, Config.game_height),
    );

    const scaled_width = @as(i32, @intFromFloat(@as(f32, Config.game_width) * scale));
    const scaled_height = @as(i32, @intFromFloat(@as(f32, Config.game_height) * scale));
    const offset_x = @divFloor(Config.window_width - scaled_width, 2);
    const offset_y = @divFloor(Config.window_height - scaled_height, 2);
    c.SetTargetFPS(60);

    screen = screen;
    scale = scale;
    offsetx = offset_x;
    offsety = offset_y;
    scaledWidth = scaled_width;
    scaledHeight = scaled_height;
    windowWidth = Config.window_width;
    windowHeight = Config.window_height;
    camera = c.Camera2D{
        .offset = c.Vector2{ .x = 0, .y = 0 },
        .target = c.Vector2{ .x = 0, .y = 0 },
        .rotation = 0.0,
        .zoom = 1.0,
    };
}

pub fn UpdateWindow() void {
    const new_width = c.GetScreenWidth();
    const new_height = c.GetScreenHeight();

    if (new_width == windowWidth and new_height == windowHeight) {
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
}
