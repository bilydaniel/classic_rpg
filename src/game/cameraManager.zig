const std = @import("std");
const Entity = @import("entity.zig");
const Config = @import("../common/config.zig");
const Window = @import("window.zig");
const EntityManager = @import("entityManager.zig");
const rl = @import("raylib");

pub var camera: *rl.Camera2D = undefined;
pub var manual: bool = undefined;
pub var speed: f32 = undefined;
pub var targetEntity: ?u32 = undefined;

pub fn init(allocator: std.mem.Allocator, entityID: u32) !void {
    camera = try allocator.create(rl.Camera2D);
    camera.* = .{
        .offset = rl.Vector2{ .x = 0, .y = 0 },
        .target = rl.Vector2{ .x = 0, .y = 0 },
        .rotation = 0.0,
        .zoom = Config.camera_zoom,
    };
    manual = false;
    speed = 100.0;
    targetEntity = entityID;
}

pub fn update(delta: f32) void {
    if (rl.isKeyPressed(rl.KeyboardKey.end)) {
        manual = !manual;
    }
    if (manual) {
        if (rl.isKeyDown(rl.KeyboardKey.w)) {
            camera.target.y -= speed * delta;
        }
        if (rl.isKeyDown(rl.KeyboardKey.s)) {
            camera.target.y += speed * delta;
        }
        if (rl.isKeyDown(rl.KeyboardKey.a)) {
            camera.target.x -= speed * delta;
        }
        if (rl.isKeyDown(rl.KeyboardKey.d)) {
            camera.target.x += speed * delta;
        }
    }
    if (rl.isKeyPressed(rl.KeyboardKey.delete)) {
        if (camera.zoom < Config.camera_zoom_max) {
            camera.zoom += Config.camera_zoom_step;
        }
    }
    if (rl.isKeyPressed(rl.KeyboardKey.insert)) {
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
