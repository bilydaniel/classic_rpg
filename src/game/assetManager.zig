const c = @cImport({
    @cInclude("raylib.h");
});
const std = @import("std");

pub var tileset: c.Texture2D = undefined;
pub var urizenTileset: c.Texture2D = undefined;

pub fn init() void {
    urizenTileset = c.LoadTexture("assets/urizen_tileset.png");
    tileset = c.LoadTexture("assets/tileset.png");
    tileset = urizenTileset;
}
