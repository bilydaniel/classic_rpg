const std = @import("std");
const Types = @import("../common/types.zig");
const c = @cImport({
    @cInclude("raylib.h");
});
pub const Button = struct {
    pos: Types.Vector2Int,
    height: i32,
    width: i32,

    pub fn initValues(this: *Button, pos: Types.Vector2Int) void {
        //TODO: make some default values for easy instancing
        this.pos = pos;
        this.height = 16;
        this.width = 16;
    }

    pub fn Draw(this: @This()) void {
        //c.DrawTexture(texture: Texture2D, posX: c_int, posY: c_int, tint: Color)
        std.debug.print("button: {any}", .{this});

        c.DrawRectangle(@intCast(this.pos.x), this.pos.y, this.width, this.height, c.RED);
    }
};
