const Types = @import("../common/types.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const inputManager = struct {};

//return whether it moved
pub fn takePositionInput(pos: *Types.Vector2Int) bool {
    var moved = false;

    if (c.IsKeyDown(c.KEY_H)) {
        pos.x -= 1;
        moved = true;
    } else if (c.IsKeyDown(c.KEY_L)) {
        pos.x += 1;
        moved = true;
    } else if (c.IsKeyDown(c.KEY_J)) {
        pos.y += 1;
        moved = true;
    } else if (c.IsKeyDown(c.KEY_K)) {
        pos.y -= 1;
        moved = true;
    }
    return moved;
}
