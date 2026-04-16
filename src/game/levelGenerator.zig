const Level = @import("level.zig");
const Allocators = @import("../common/allocators.zig");
const Types = @import("../common/types.zig");

pub fn generate(id: u32, worldPos: Types.Vector3Int) !Level.Level {
    const level = try Level.Level.init(Allocators.persistent, id, worldPos);

    fillWithWalls(level.grid);

    return level;
}

pub fn fillWithWalls(grid: Types.Grid) void {
    for (0..grid.len) |i| {
        grid[i] = Level.Tile.init(.wall);
    }
}

pub fn carveRoomRectangle(grid: Types.Grid, pos: Types.Vector2Int, size: Types.Vector2Int) void {
    //TODO: which tile to use?

}
pub fn carveRoomCircle(grid: Types.Grid, pos: Types.Vector2Int, r: u32) void {}
