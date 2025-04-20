const std = @import("std");
const config = @import("../common/config.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

const TileType = enum {
    empty,
    wall,
    floor,
    water,
    //TODO:
};

//TODO: put somewhere else
const Entity = struct {};

const Tile = struct {
    texture_id: i32,
    tile_type: TileType,
    solid: bool, //TODO: no idea if needed, tile_type already says if solid
};

pub const Level = struct {
    grid: [config.level_height][config.level_width]Tile, //TODO: do i want to have it always the same size?
    //TODO: probably just make this a 1D array and just add some MATHS
    //TODO: REMOVE
    tile_texture: c.Texture2D,
    allocator: std.mem.Allocator,
    entities: std.ArrayList(*Entity),

    pub fn init(allocator: std.mem.Allocator) !*Level {
        const level = try allocator.create(Level);
        var grid: [config.level_height][config.level_width]Tile = undefined;

        for (&grid) |*row| {
            for (row) |*tile| {
                tile.* = Tile{
                    .texture_id = 1,
                    .tile_type = .floor,
                    .solid = false,
                };
            }
        }
        //const tileTexture = c.LoadTexture("assets/base_tile.png");

        const texture_path = "/home/daniel/projects/classic_rpg/assets/base_tile.png";
        const tileTexture = c.LoadTexture(texture_path);

        // Check if texture loading failed
        if (tileTexture.id == 0) {
            std.debug.print("Failed to load texture: {s}\n", .{texture_path});
            return error.TextureLoadFailed;
        }

        level.* = .{
            .grid = grid,
            .tile_texture = tileTexture,
            .allocator = allocator,
        };
        return level;
    }

    pub fn Draw(this: @This()) void {
        for (0..config.level_height) |i| {
            for (0..config.level_width) |j| {
                c.DrawTexture(this.tile_texture, @as(c_int, @intCast(j * config.tile_width)), @as(c_int, @intCast(i * config.tile_height)), c.WHITE);
            }
        }
    }

    pub fn Update(this: *Level) void {}
};
