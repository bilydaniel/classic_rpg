const std = @import("std");
const Config = @import("../common/config.zig");
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
    rect: c.Rectangle,
};

pub const Level = struct {
    grid: [Config.level_width * Config.level_height]Tile,
    //TODO: REMOVE
    tile_texture: c.Texture2D,
    allocator: std.mem.Allocator,
    entities: std.ArrayList(*Entity),
    tilesetTexture: c.Texture2D,

    pub fn init(allocator: std.mem.Allocator) !*Level {
        const level = try allocator.create(Level);

        for (0..level.grid.len) |i| {
            level.grid[i] = Tile{
                .texture_id = 1,
                .tile_type = .floor,
                .solid = false,
                .rect = c.Rectangle{ .x = i % Config.tile_width, .y = i / Config.tile_width },
            };
        }

        //const tileTexture = c.LoadTexture("assets/base_tile.png");

        const texture_path = "/home/daniel/projects/classic_rpg/assets/base_tile.png";
        const tileTexture = c.LoadTexture(texture_path);

        // Check if texture loading failed
        if (tileTexture.id == 0) {
            std.debug.print("Failed to load texture: {s}\n", .{texture_path});
            return error.TextureLoadFailed;
        }

        const entities = std.ArrayList(*Entity).init(allocator);
        level.* = .{
            .grid = level.grid,
            .tile_texture = tileTexture,
            .allocator = allocator,
            .entities = entities,
        };
        return level;
    }

    pub fn Draw(this: @This()) void {
        for (0..Config.level_height) |i| {
            for (0..Config.level_width) |j| {
                c.DrawTexture(this.tile_texture, @as(c_int, @intCast(j * Config.tile_width)), @as(c_int, @intCast(i * Config.tile_height)), c.WHITE);
            }
        }

        for (this.grid) |tile| {
            //TODO: finish this

            //c.DrawTextureRec(texture: Texture2D, source: Rectangle, position: Vector2, tint: Color)
            const tile_source = c.Rectangle{
                .x = tile.texture_id * Config.tile_width % this.tilesetTexture.width,
                .y = tile.texture_id * Config.tile_height / this.tilesetTexture.width,
                .width = Config.tile_width,
                .height = Config.tile_height,
            };
            c.DrawTextureRec(this.tilesetTexture, tile_source, tile.rect, c.WHITE);
        }
    }

    pub fn Update(this: *Level) void {
        std.debug.print("level: {}\n", .{this.entities});
    }

    //pub fn SetTile(
    //this: *Level,
    //) void {}
};
