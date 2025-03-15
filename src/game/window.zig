const std = @import("std");
const Game = @import("game.zig");
const Player = @import("../entities/player.zig");
const Config = @import("../common/config.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const Window = struct {
    screen: c.RenderTexture2D,
    scale: f32,
    windowWidth: i32,
    windowHeight: i32,
    offsetx: i32,
    offsety: i32,
    scaledWidth: i32,
    scaledHeight: i32,

    pub fn init() Window {
        const screen = c.LoadRenderTexture(Config.game_width, Config.game_height);
        c.SetTextureFilter(screen.texture, c.TEXTURE_FILTER_POINT); //TODO:try TEXTURE_FILTER_BILINEAR for blurry effect

        const scale = @min(
            @as(f32, @floatFromInt(Config.window_width)) / @as(f32, Config.game_width),
            @as(f32, @floatFromInt(Config.window_height)) / @as(f32, Config.game_height),
        );

        const scaled_width = @as(i32, @intFromFloat(@as(f32, Config.game_width) * scale));
        const scaled_height = @as(i32, @intFromFloat(@as(f32, Config.game_height) * scale));
        const offset_x = @divFloor(Config.window_width - scaled_width, 2);
        const offset_y = @divFloor(Config.window_height - scaled_height, 2);
        c.SetTargetFPS(60);

        return Window{
            .screen = screen,
            .scale = scale,
            .offsetx = offset_x,
            .offsety = offset_y,
            .scaledWidth = scaled_width,
            .scaledHeight = scaled_height,
            .windowWidth = Config.window_width,
            .windowHeight = Config.window_height,
        };
    }

    pub fn deinit(this: *Window) void {
        defer c.UnloadRenderTexture(this.screen);
    }

    pub fn Update(this: *Window) void {
        const new_width = c.GetScreenWidth();
        const new_height = c.GetScreenHeight();

        if (new_width == this.windowWidth and new_height == this.windowHeight) {
            return;
        }

        this.windowWidth = new_width;
        this.windowHeight = new_height;

        const scale = @min(
            @as(f32, @floatFromInt(Config.window_width)) / @as(f32, Config.game_width),
            @as(f32, @floatFromInt(Config.window_height)) / @as(f32, Config.game_height),
        );

        const scaled_width = @as(i32, @intFromFloat(@as(f32, Config.game_width) * scale));
        const scaled_height = @as(i32, @intFromFloat(@as(f32, Config.game_height) * scale));

        const offset_x = @divFloor(Config.window_width - scaled_width, 2);
        const offset_y = @divFloor(Config.window_height - scaled_height, 2);

        this.scale = scale;
        this.offsetx = offset_x;
        this.offsety = offset_y;
        this.scaledWidth = scaled_width;
        this.scaledHeight = scaled_height;
    }
};
