const c = @cImport({
    @cInclude("raylib.h");
});
const std = @import("std");

pub const TilesetManager = struct {
    tileset: c.Texture2D,
    urizenTileset: c.Texture2D,

    pub fn init(allocator: std.mem.Allocator) *TilesetManager {
        const tilesetManager = allocator.create(TilesetManager);
        const urizen_tileset = c.LoadTexture("../../assets/urizen_tileset.png");
        const tileset = c.LoadTexture("../../assets/tileset.png");
        tilesetManager.* = .{
            .tileset = tileset,
            .urizenTileset = urizen_tileset,
        };
    }
};
