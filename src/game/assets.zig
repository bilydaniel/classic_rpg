const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});
//TODO: make a better system, dumb as fuck
pub const assets = struct {
    playerTexture: c.Texture2D,
    baseTile: c.Texture2D,
    enemy: c.Texture2D,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) @This() {
        //TODO: try what happens if load fails
        const player_texture = c.LoadTexture("assets/random_character.png");
        const tile_texture = c.LoadTexture("assets/base_tile.png");
        const enemy_texture = c.LoadTexture("assets/enemy.png");
        return assets{
            .playerTexture = player_texture,
            .baseTile = tile_texture,
            .enemy = enemy_texture,
            .allocator = allocator,
        };
    }

    pub fn deinit(this: @This()) void {
        c.UnloadTexture(this.playerTexture);
        c.UnloadTexture(this.baseTile);
        c.UnloadTexture(this.enemy);
    }
};
