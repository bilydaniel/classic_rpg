// attackEffects.zig - Shader-based attack effects system
const std = @import("std");
const Types = @import("../common/types.zig");
const Config = @import("../common/config.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const EffectType = enum {
    slash,
    impact,
    explosion,
};

pub const AttackEffect = struct {
    pos: c.Vector2,
    effectType: EffectType,
    time: f32,
    duration: f32,
    fromPos: c.Vector2,
    toPos: c.Vector2,
    active: bool,

    pub fn init(pos: c.Vector2, effectType: EffectType, duration: f32) AttackEffect {
        return AttackEffect{
            .pos = pos,
            .effectType = effectType,
            .time = 0,
            .duration = duration,
            .fromPos = pos,
            .toPos = pos,
            .active = true,
        };
    }

    pub fn initSlash(from: c.Vector2, to: c.Vector2, duration: f32) AttackEffect {
        return AttackEffect{
            .pos = from,
            .effectType = .slash,
            .time = 0,
            .duration = duration,
            .fromPos = from,
            .toPos = to,
            .active = true,
        };
    }

    pub fn update(self: *AttackEffect, delta: f32) bool {
        self.time += delta;
        if (self.time >= self.duration) {
            self.active = false;
            return false;
        }
        return true;
    }
};

pub const ShaderEffectSystem = struct {
    effects: std.ArrayList(AttackEffect),
    allocator: std.mem.Allocator,

    // Shaders
    slashShader: c.Shader,
    impactShader: c.Shader,
    explosionShader: c.Shader,

    // Shader uniforms
    timeLoc_slash: i32,
    timeLoc_impact: i32,
    timeLoc_explosion: i32,
    resolutionLoc_slash: i32,
    resolutionLoc_impact: i32,
    resolutionLoc_explosion: i32,

    pub fn init(allocator: std.mem.Allocator) !ShaderEffectSystem {
        // Load shaders (you'll create these files)
        const slashShader = c.LoadShader(null, "resources/shaders/slash.fs");
        const impactShader = c.LoadShader(null, "resources/shaders/impact.fs");
        const explosionShader = c.LoadShader(null, "resources/shaders/explosion.fs");

        return ShaderEffectSystem{
            .effects = std.ArrayList(AttackEffect).init(allocator),
            .allocator = allocator,
            .slashShader = slashShader,
            .impactShader = impactShader,
            .explosionShader = explosionShader,
            .timeLoc_slash = c.GetShaderLocation(slashShader, "time"),
            .timeLoc_impact = c.GetShaderLocation(impactShader, "time"),
            .timeLoc_explosion = c.GetShaderLocation(explosionShader, "time"),
            .resolutionLoc_slash = c.GetShaderLocation(slashShader, "resolution"),
            .resolutionLoc_impact = c.GetShaderLocation(impactShader, "resolution"),
            .resolutionLoc_explosion = c.GetShaderLocation(explosionShader, "resolution"),
        };
    }

    pub fn deinit(self: *ShaderEffectSystem) void {
        c.UnloadShader(self.slashShader);
        c.UnloadShader(self.impactShader);
        c.UnloadShader(self.explosionShader);
        self.effects.deinit();
    }

    pub fn update(self: *ShaderEffectSystem, delta: f32) void {
        var i: usize = 0;
        while (i < self.effects.items.len) {
            if (!self.effects.items[i].update(delta)) {
                _ = self.effects.swapRemove(i);
            } else {
                i += 1;
            }
        }
    }

    pub fn draw(self: *ShaderEffectSystem) void {
        for (self.effects.items) |*effect| {
            if (!effect.active) continue;

            const progress = effect.time / effect.duration;

            switch (effect.effectType) {
                .slash => self.drawSlash(effect, progress),
                .impact => self.drawImpact(effect, progress),
                .explosion => self.drawExplosion(effect, progress),
            }
        }
    }

    fn drawSlash(self: *ShaderEffectSystem, effect: *AttackEffect, progress: f32) void {
        c.BeginShaderMode(self.slashShader);

        c.SetShaderValue(self.slashShader, self.timeLoc_slash, &progress, c.SHADER_UNIFORM_FLOAT);

        const resolution = [2]f32{ @as(f32, @floatFromInt(c.GetScreenWidth())), @as(f32, @floatFromInt(c.GetScreenHeight())) };
        c.SetShaderValue(self.slashShader, self.resolutionLoc_slash, &resolution, c.SHADER_UNIFORM_VEC2);

        // Draw a quad between from and to positions
        const width: f32 = 20.0;
        const dx = effect.toPos.x - effect.fromPos.x;
        const dy = effect.toPos.y - effect.fromPos.y;
        const length = @sqrt(dx * dx + dy * dy);
        const angle = std.math.atan2(dy, dx);

        const rect = c.Rectangle{
            .x = effect.fromPos.x,
            .y = effect.fromPos.y,
            .width = length,
            .height = width,
        };
        const origin = c.Vector2{ .x = 0, .y = width / 2 };

        c.DrawRectanglePro(rect, origin, angle * 180.0 / std.math.pi, c.WHITE);

        c.EndShaderMode();
    }

    fn drawImpact(self: *ShaderEffectSystem, effect: *AttackEffect, progress: f32) void {
        c.BeginShaderMode(self.impactShader);

        c.SetShaderValue(self.impactShader, self.timeLoc_impact, &progress, c.SHADER_UNIFORM_FLOAT);

        const resolution = [2]f32{ @as(f32, @floatFromInt(c.GetScreenWidth())), @as(f32, @floatFromInt(c.GetScreenHeight())) };
        c.SetShaderValue(self.impactShader, self.resolutionLoc_impact, &resolution, c.SHADER_UNIFORM_VEC2);

        const size = 60.0;
        c.DrawRectangle(@as(i32, @intFromFloat(effect.pos.x - size / 2)), @as(i32, @intFromFloat(effect.pos.y - size / 2)), @as(i32, @intFromFloat(size)), @as(i32, @intFromFloat(size)), c.WHITE);

        c.EndShaderMode();
    }

    fn drawExplosion(self: *ShaderEffectSystem, effect: *AttackEffect, progress: f32) void {
        c.BeginShaderMode(self.explosionShader);

        c.SetShaderValue(self.explosionShader, self.timeLoc_explosion, &progress, c.SHADER_UNIFORM_FLOAT);

        const resolution = [2]f32{ @as(f32, @floatFromInt(c.GetScreenWidth())), @as(f32, @floatFromInt(c.GetScreenHeight())) };
        c.SetShaderValue(self.explosionShader, self.resolutionLoc_explosion, &resolution, c.SHADER_UNIFORM_VEC2);

        const size = 80.0 * (1.0 + progress);
        c.DrawRectangle(@as(i32, @intFromFloat(effect.pos.x - size / 2)), @as(i32, @intFromFloat(effect.pos.y - size / 2)), @as(i32, @intFromFloat(size)), @as(i32, @intFromFloat(size)), c.WHITE);

        c.EndShaderMode();
    }

    // Spawn effects
    pub fn spawnSlash(self: *ShaderEffectSystem, from: Types.Vector2Int, to: Types.Vector2Int) !void {
        const from_pixel = c.Vector2{
            .x = @as(f32, @floatFromInt(from.x * Config.tile_width + Config.tile_width / 2)),
            .y = @as(f32, @floatFromInt(from.y * Config.tile_height + Config.tile_height / 2)),
        };
        const to_pixel = c.Vector2{
            .x = @as(f32, @floatFromInt(to.x * Config.tile_width + Config.tile_width / 2)),
            .y = @as(f32, @floatFromInt(to.y * Config.tile_height + Config.tile_height / 2)),
        };

        const effect = AttackEffect.initSlash(from_pixel, to_pixel, 0.3);
        try self.effects.append(effect);
    }

    pub fn spawnImpact(self: *ShaderEffectSystem, pos: Types.Vector2Int) !void {
        const pixel_pos = c.Vector2{
            .x = @as(f32, @floatFromInt(pos.x * Config.tile_width + Config.tile_width / 2)),
            .y = @as(f32, @floatFromInt(pos.y * Config.tile_height + Config.tile_height / 2)),
        };

        const effect = AttackEffect.init(pixel_pos, .impact, 0.4);
        try self.effects.append(effect);
    }

    pub fn spawnExplosion(self: *ShaderEffectSystem, pos: Types.Vector2Int) !void {
        const pixel_pos = c.Vector2{
            .x = @as(f32, @floatFromInt(pos.x * Config.tile_width + Config.tile_width / 2)),
            .y = @as(f32, @floatFromInt(pos.y * Config.tile_height + Config.tile_height / 2)),
        };

        const effect = AttackEffect.init(pixel_pos, .explosion, 0.5);
        try self.effects.append(effect);
    }
};

// ===== INTEGRATION =====
// In Game.Context:
// shaderEffects: ShaderEffectSystem,

// In init:
// shaderEffects: try ShaderEffectSystem.init(allocator),

// In update:
// ctx.shaderEffects.update(ctx.delta);

// In draw (after entities, before UI):
// ctx.shaderEffects.draw();

// In attack function:
// try ctx.shaderEffects.spawnSlash(entity.pos, attacked_entity.pos);
// try ctx.shaderEffects.spawnImpact(attacked_entity.pos);
// try ctx.shaderEffects.spawnExplosion(attacked_entity.pos);
