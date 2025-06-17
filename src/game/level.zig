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
    texture_id: ?i32,
    tile_type: TileType,
    solid: bool, //TODO: no idea if needed, tile_type already says if solid
    rect: c.Rectangle,
    isAscii: bool,
    ascii: ?[2]u8,
};

pub const Level = struct {
    grid: [Config.level_width * Config.level_height]Tile,
    //TODO: REMOVE
    tile_texture: c.Texture2D,
    allocator: std.mem.Allocator,
    entities: std.ArrayList(*Entity),
    tilesetTexture: ?*c.Texture2D,

    pub fn init(allocator: std.mem.Allocator, tilesetTexture: ?*c.Texture2D) !*Level {
        const level = try allocator.create(Level);

        for (0..level.grid.len) |i| {
            level.grid[i] = Tile{
                .texture_id = null,
                .tile_type = .floor,
                .solid = false,
                .rect = c.Rectangle{
                    .x = @floatFromInt(i % @as(usize, @intCast(Config.tile_width))),
                    .y = @floatFromInt(i / @as(usize, @intCast(Config.tile_height))),
                },
                .isAscii = true,
                .ascii = .{ '#', 0 },
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
            .tilesetTexture = tilesetTexture,
        };
        return level;
    }

    pub fn Draw(this: @This()) void {
        //c.DrawTexture(this.tile_texture, @as(c_int, @intCast(j * Config.tile_width)), @as(c_int, @intCast(i * Config.tile_height)), c.WHITE);

        for (this.grid, 0..) |tile, index| {
            if (tile.isAscii) {
                if (tile.ascii) |ascii| {
                    const x = (index % Config.level_width) * Config.tile_width;
                    const y = (@divFloor(index, Config.level_width)) * Config.tile_height;
                    c.DrawText(&ascii[0], @intCast(x), @intCast(y), 16, c.WHITE);
                }
            }

            //c.DrawTextureRec(texture: Texture2D, source: Rectangle, position: Vector2, tint: Color)
            //            if (this.tilesetTexture) |tileset_texture| {
            //                const tile_source = c.Rectangle{
            //                    .x = @floatFromInt(@mod(tile.texture_id * Config.tile_width, tileset_texture.width)),
            //                    .y = @floatFromInt(@divFloor(tile.texture_id * Config.tile_width, tileset_texture.width)),
            //                    .width = Config.tile_width,
            //                    .height = Config.tile_height,
            //                };
            //                c.DrawTextureRec(tileset_texture.*, tile_source, c.Vector2{ .x = @floatFromInt(index % Config.level_width), .y = @floatFromInt(@divFloor(index, Config.level_width)) }, c.WHITE);
            //            }
        }
    }

    pub fn Update(this: *Level) void {
        std.debug.print("level: {}\n", .{this.entities});
    }

    //pub fn SetTile(
    //this: *Level,
    //) void {}
};
