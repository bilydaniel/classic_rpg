const Config = @import("../common/config.zig");
const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const Screen = struct {
    texture: c.RenderTexture2D,
    scale: f32,
    scaled_width: i32,
    scaled_height: i32,
    offset_x: i32,
    offset_y: i32,

    pub fn init(allocator: std.mem.Allocator) !*Screen {
        const texture = c.LoadRenderTexture(Config.game_width, Config.game_height);
        c.SetTextureFilter(texture.texture, c.TEXTURE_FILTER_POINT); //TODO:try TEXTURE_FILTER_BILINEAR for blurry effect
        const scale = @min(
            @as(f32, @floatFromInt(Config.window_width)) / @as(f32, Config.game_width),
            @as(f32, @floatFromInt(Config.window_height)) / @as(f32, Config.game_height),
        );
        const scaled_width = @as(i32, @intFromFloat(@as(f32, Config.game_width) * scale));
        const scaled_height = @as(i32, @intFromFloat(@as(f32, Config.game_height) * scale));
        const offset_x = @divFloor(Config.window_width - scaled_width, 2);
        const offset_y = @divFloor(Config.window_height - scaled_height, 2);

        const screen = try allocator.create(Screen);
        screen.* = Screen{
            .texture = texture,
            .scale = scale,
            .scaled_width = scaled_width,
            .scaled_height = scaled_height,
            .offset_x = offset_x,
            .offset_y = offset_y,
        };
        return screen;
    }

    pub fn deinit(this: *Screen, allocator: std.mem.Allocator) void {
        c.UnloadRenderTexture(this.texture);
        allocator.destroy(this);
    }

    pub fn Update(this: *Screen) void {
        const window_width = c.GetScreenWidth();
        const window_height = c.GetScreenHeight();

        this.scale = @min(
            @as(f32, @floatFromInt(window_width)) / @as(f32, Config.game_width),
            @as(f32, @floatFromInt(window_height)) / @as(f32, Config.game_height),
        );

        this.scaled_width = @as(i32, @intFromFloat(@as(f32, Config.game_width) * this.scale));
        this.scaled_height = @as(i32, @intFromFloat(@as(f32, Config.game_height) * this.scale));
        this.offset_x = @divFloor(window_width - this.scaled_width, 2);
        this.offset_y = @divFloor(window_height - this.scaled_height, 2);
    }
};
