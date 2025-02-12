const config = @import("../common/config.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

const Tile = struct {
    id: i32,
};

pub const Level = struct {
    grid: [config.level_height][config.level_width]Tile, //TODO: do i want to have it always the same size?
    width: usize,
    height: usize,
    //TODO: REMOVE
    tile_texture: c.Texture2D,

    pub fn init() @This() {
        var grid: [config.level_height][config.level_width]Tile = undefined;

        for (0..config.level_height) |i| {
            for (0..config.level_width) |j| {
                grid[i][j] = Tile{ .id = 1 };
            }
        }
        return Level{
            .grid = grid,
            .width = config.level_width,
            .height = config.level_height,
            .tile_texture = c.LoadTexture("assets/base_tile.png"),
        };
    }

    pub fn Draw(this: @This()) void {
        for (0..config.level_height) |i| {
            for (0..config.level_width) |j| {
                c.DrawTexture(
                    this.tile_texture,
                    @as(c_int, @intCast(j * 16)),
                    @as(c_int, @intCast(i * 16)),
                    c.WHITE,
                );
            }
        }
    }
};
