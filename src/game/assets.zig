const c = @cImport({
    @cInclude("raylib.h");
});
//TODO: make a better system, dumb as fuck
pub const assets = struct {
    playerTexture: c.Texture2D,
    baseTile: c.Texture2D,

    pub fn init() @This() {
        //TODO: try what happens if load fails
        const player_texture = c.LoadTexture("assets/random_character.png");
        const tile_texture = c.LoadTexture("assets/base_tile.png");
        return assets{
            .playerTexture = player_texture,
            .baseTile = tile_texture,
        };
    }

    pub fn deinit(this: @This()) void {
        c.UnloadTexture(this.playerTexture);
        c.UnloadTexture(this.baseTile);
    }
};
