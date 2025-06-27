const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const Vector2Int = struct {
    x: i32,
    y: i32,

    pub fn init(x: i32, y: i32) Vector2Int {
        return Vector2Int{
            .x = x,
            .y = y,
        };
    }
};

pub fn vector2IntCompare(a: Vector2Int, b: Vector2Int) bool {
    return a.x == b.x and a.y == b.y;
}

pub fn vector2IntConvert(a: Vector2Int) c.Vector2 {
    return c.Vector2{
        .x = @floatFromInt(a.x),
        .y = @floatFromInt(a.y),
    };
}

pub fn vector2Convert(a: c.Vector2) Vector2Int {
    std.debug.print("converting: {}\n", .{a});
    return Vector2Int{
        .x = @intFromFloat(a.x),
        .y = @intFromFloat(a.y),
    };
}
