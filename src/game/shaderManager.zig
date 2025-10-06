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

pub const Effect = struct {
    pos: c.Vector2,
    effectType: EffectType,
    time: f32,
    duration: f32,
    fromPos: c.Vector2,
    toPos: ?c.Vector2,
    active: bool,

    pub fn init(fromPosition: c.Vector2, toPosition: ?c.Vector2, effectType: EffectType, duration: f32) Effect {
        return Effect{
            .fromPos = fromPosition,
            .toPos = toPosition,
            .effectType = effectType,
            .time = 0,
            .duration = duration,
            .active = true,
        };
    }

    pub fn update(self: *Effect, delta: f32) bool {
        self.time += delta;
        if (self.time >= self.duration) {
            self.active = false;
            return false;
        }
        return true;
    }
};

pub const Shader = struct {
    source: c.Shader,
    timeLoc: i32,
    resolutionLoc: i32,

    pub fn init(allocator: std.mem.Allocator, path: []const u8) !*Shader {
        const shader = try allocator.create(Shader);
        const source = c.LoadShader(null, path.ptr);
        shader.* = .{
            .source = source,
            .timeLoc = c.GetShaderLocation(source, "time"),
            .resolutionLoc = c.GetShaderLocation(source, "resolution"),
        };
        return shader;
    }
};

pub const ShaderManager = struct {
    allocator: std.mem.Allocator,
    effects: std.ArrayList(Effect),

    slashShader: *Shader,

    pub fn init(allocator: std.mem.Allocator) !*ShaderManager {
        const shaderManager = try allocator.create(ShaderManager);
        const slashShader = try Shader.init(allocator, "../shaders/slash.fs");
        const effects = std.ArrayList(Effect).init(allocator);

        shaderManager.* = .{
            .allocator = allocator,
            .effects = effects,
            .slashShader = slashShader,
        };
    }

    pub fn update(this: *ShaderManager, delta: f32) void {
        var i: usize = 0;
        while (i < this.effects.items.len) {
            if (!this.effects.items[i].update(delta)) {
                _ = this.effects.swapRemove(i);
            } else {
                i += 1;
            }
        }
    }

    fn drawSlash(this: *ShaderManager, effect: *Effect, progress: f32) void {
        c.BeginShaderMode(this.slashShader);

        c.SetShaderValue(this.slashShader.source, this.slashShader.timeLoc, &progress, c.SHADER_UNIFORM_FLOAT);

        const resolution = [2]f32{ @as(f32, @floatFromInt(c.GetScreenWidth())), @as(f32, @floatFromInt(c.GetScreenHeight())) };

        c.SetShaderValue(this.slashShader.source, this.slashShader.resolutionLoc, &resolution, c.SHADER_UNIFORM_VEC2);

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

    pub fn spawnSlash(this: *ShaderManager, from: Types.Vector2Int, to: Types.Vector2Int) !void {
        const from_pixel = c.Vector2{
            .x = @as(f32, @floatFromInt(from.x * Config.tile_width + Config.tile_width / 2)),
            .y = @as(f32, @floatFromInt(from.y * Config.tile_height + Config.tile_height / 2)),
        };
        const to_pixel = c.Vector2{
            .x = @as(f32, @floatFromInt(to.x * Config.tile_width + Config.tile_width / 2)),
            .y = @as(f32, @floatFromInt(to.y * Config.tile_height + Config.tile_height / 2)),
        };

        const effect = Effect.init(from_pixel, to_pixel, 0.3);
        try this.effects.append(effect);
    }

    pub fn draw(this: *ShaderManager) void {
        for (this.effects.items) |*effect| {
            if (!effect.active) continue;

            const progress = effect.time / effect.duration;

            switch (effect.effectType) {
                .slash => this.drawSlash(effect, progress),
                //.impact => this.drawImpact(effect, progress),
                //.explosion => this.drawExplosion(effect, progress),
            }
        }
    }
};
