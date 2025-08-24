const std = @import("std");
const Entity = @import("entity.zig");
const Config = @import("../common/config.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const CamManager = struct {
    camera: *c.Camera2D,
    manual: bool,
    speed: f32,
    targetEntity: *Entity.Entity,

    pub fn init(allocator: std.mem.Allocator, entity: *Entity.Entity) !CamManager {
        const camera_manager = try allocator.create(CamManager);
        const camera = try allocator.create(c.Camera2D);
        camera.* = .{
            .offset = c.Vector2{ .x = 0, .y = 0 },
            .target = c.Vector2{ .x = 0, .y = 0 },
            .rotation = 0.0,
            .zoom = Config.camera_zoom,
        };
        camera_manager.* = .{
            .camera = camera,
            .manual = false,
            .speed = 100.0,
            .targetEntity = entity,
        };
        return camera_manager.*;
    }

    pub fn Update(this: *CamManager, delta: f32) void {
        if (c.IsKeyPressed(c.KEY_END)) {
            this.manual = !this.manual;
            std.debug.print("manua: {}", .{this.manual});
        }
        if (this.manual) {
            if (c.IsKeyDown(c.KEY_W)) {
                this.camera.target.y -= this.speed * delta;
            }
            if (c.IsKeyDown(c.KEY_S)) {
                this.camera.target.y += this.speed * delta;
            }
            if (c.IsKeyDown(c.KEY_A)) {
                this.camera.target.x -= this.speed * delta;
            }
            if (c.IsKeyDown(c.KEY_D)) {
                this.camera.target.x += this.speed * delta;
            }
        }
        if (c.IsKeyPressed(c.KEY_DELETE)) {
            if (this.camera.zoom < Config.camera_zoom_max) {
                this.camera.zoom += Config.camera_zoom_step;
            }
        }
        if (c.IsKeyPressed(c.KEY_INSERT)) {
            if (this.camera.zoom > Config.camera_zoom_min) {
                this.camera.zoom -= Config.camera_zoom_step;
            }
        }
        if (!this.manual) {
            this.camera.target.x = @floor(@as(f32, @floatFromInt(this.targetEntity.pos.x * Config.tile_width)) - Config.game_width_half / this.camera.zoom);
            this.camera.target.y = @floor(@as(f32, @floatFromInt(this.targetEntity.pos.y * Config.tile_height)) - Config.game_height_half / this.camera.zoom);
        }
    }
};
