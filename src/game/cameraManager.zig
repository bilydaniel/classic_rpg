const std = @import("std");
const Entity = @import("entity.zig");
const Config = @import("../common/config.zig");
const Window = @import("window.zig");
const EntityManager = @import("entityManager.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

var camera: *c.Camera2D = undefined;
var manual: bool = undefined;
var speed: f32 = undefined;
var targetEntity: ?u32 = undefined;

pub fn init(allocator: std.mem.Allocator, entityID: u32) !void {
    camera = try allocator.create(c.Camera2D);
    camera.* = .{
        .offset = c.Vector2{ .x = 0, .y = 0 },
        .target = c.Vector2{ .x = 0, .y = 0 },
        .rotation = 0.0,
        .zoom = Config.camera_zoom,
    };
    manual = false;
    speed = 100.0;
    targetEntity = entityID;
}

pub fn update(delta: f32) void {
    if (c.IsKeyPressed(c.KEY_END)) {
        manual = manual;
    }
    if (manual) {
        if (c.IsKeyDown(c.KEY_W)) {
            camera.target.y -= speed * delta;
        }
        if (c.IsKeyDown(c.KEY_S)) {
            camera.target.y += speed * delta;
        }
        if (c.IsKeyDown(c.KEY_A)) {
            camera.target.x -= speed * delta;
        }
        if (c.IsKeyDown(c.KEY_D)) {
            camera.target.x += speed * delta;
        }
    }
    if (c.IsKeyPressed(c.KEY_DELETE)) {
        if (camera.zoom < Config.camera_zoom_max) {
            camera.zoom += Config.camera_zoom_step;
        }
    }
    if (c.IsKeyPressed(c.KEY_INSERT)) {
        if (camera.zoom > Config.camera_zoom_min) {
            camera.zoom -= Config.camera_zoom_step;
        }
    }
    if (!manual) {
        if (targetEntity) |entityid| {
            //TODO: make it possible to just set a camera position without target
            const entity = EntityManager.getEntityID(entityid) orelse return;
            camera.target.x = @floor(@as(f32, @floatFromInt(entity.pos.x * Config.tile_width)) - Window.scaledWidthHalf / camera.zoom);
            camera.target.y = @floor(@as(f32, @floatFromInt(entity.pos.y * Config.tile_height)) - Window.scaledHeightHalf / camera.zoom);
        }
    }
}
