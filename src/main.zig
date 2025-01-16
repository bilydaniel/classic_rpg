const std = @import("std");
//const ray = @import("raylib");
const ray = @cImport({
    @cInclude("raylib.h");
});

const player = struct {
    x: f32,
    y: f32,
    speed: f32,
};

pub fn main() !void {
    std.debug.print("Hello world\n", .{});
    ray.InitWindow(800, 600, "RPG");
    defer ray.CloseWindow();
    ray.SetTargetFPS(60);

    while (!ray.WindowShouldClose()) {}
}
