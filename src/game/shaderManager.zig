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

        std.debug.print("shader: {}\n", .{source});

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
    impactShader: *Shader,
    explosionShader: *Shader,
    texture: c.Texture2D,

    pub fn init(allocator: std.mem.Allocator) !*ShaderManager {
        const shaderManager = try allocator.create(ShaderManager);
        const slashShader = try Shader.init(allocator, "src/shaders/slash.fs");
        const impactShader = try Shader.init(allocator, "src/shaders/impact.fs");
        const explosionShader = try Shader.init(allocator, "src/shaders/explosion.fs");
        const effects = std.ArrayList(Effect).init(allocator);
        const whiteImage = c.GenImageColor(1, 1, c.WHITE);
        const texture = c.LoadTextureFromImage(whiteImage);

        shaderManager.* = .{
            .allocator = allocator,
            .effects = effects,
            .slashShader = slashShader,
            .impactShader = impactShader,
            .explosionShader = explosionShader,
            .texture = texture,
        };

        return shaderManager;
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
    fn drawImpact(this: *ShaderManager, effect: *Effect, progress: f32) void {
        c.BeginShaderMode(this.impactShader.source);

        // Set shader uniforms
        c.SetShaderValue(this.impactShader.source, this.impactShader.timeLoc, &progress, c.SHADER_UNIFORM_FLOAT);

        const resolution = [2]f32{
            @as(f32, @floatFromInt(c.GetScreenWidth())),
            @as(f32, @floatFromInt(c.GetScreenHeight())),
        };
        c.SetShaderValue(this.impactShader.source, this.impactShader.resolutionLoc, &resolution, c.SHADER_UNIFORM_VEC2);

        // Compute size and position
        const size = 40.0 * (1.0 + progress);
        const destX = effect.fromPos.x; //- size / 2;
        const destY = effect.fromPos.y; //- size / 2;

        // Draw texture instead of rectangle
        const tex = this.texture; // Assuming you have loaded this earlier
        const srcRect = c.Rectangle{
            .x = 0,
            .y = 0,
            .width = @as(f32, @floatFromInt(tex.width)),
            .height = @as(f32, @floatFromInt(tex.height)),
        };
        const destRect = c.Rectangle{
            .x = destX,
            .y = destY,
            .width = size,
            .height = size,
        };
        const origin = c.Vector2{ .x = size / 2.0, .y = size / 2.0 };

        // Rotation 0, color white (so shader fully controls the look)
        c.DrawTexturePro(tex, srcRect, destRect, origin, 0.0, c.WHITE);

        c.EndShaderMode();
    }

    fn drawExplosion(this: *ShaderManager, effect: *Effect, progress: f32) void {
        c.BeginShaderMode(this.explosionShader.source);

        // Set shader uniforms
        c.SetShaderValue(this.explosionShader.source, this.explosionShader.timeLoc, &progress, c.SHADER_UNIFORM_FLOAT);

        const resolution = [2]f32{
            @as(f32, @floatFromInt(c.GetScreenWidth())),
            @as(f32, @floatFromInt(c.GetScreenHeight())),
        };
        c.SetShaderValue(this.explosionShader.source, this.explosionShader.resolutionLoc, &resolution, c.SHADER_UNIFORM_VEC2);

        // Compute size and position
        const size = 30.0 * (1.0 + progress);
        const destX = effect.fromPos.x; //- size / 2;
        const destY = effect.fromPos.y; //- size / 2;

        // Draw texture instead of rectangle
        const tex = this.texture; // Assuming you have loaded this earlier
        const srcRect = c.Rectangle{
            .x = 0,
            .y = 0,
            .width = @as(f32, @floatFromInt(tex.width)),
            .height = @as(f32, @floatFromInt(tex.height)),
        };
        const destRect = c.Rectangle{
            .x = destX,
            .y = destY,
            .width = size,
            .height = size,
        };
        const origin = c.Vector2{ .x = size / 2.0, .y = size / 2.0 };

        // Rotation 0, color white (so shader fully controls the look)
        c.DrawTexturePro(tex, srcRect, destRect, origin, 0.0, c.WHITE);

        c.EndShaderMode();
    }
    fn drawSlash(this: *ShaderManager, effect: *Effect, progress: f32) void {
        c.BeginShaderMode(this.slashShader.source);

        c.SetShaderValue(this.slashShader.source, this.slashShader.timeLoc, &progress, c.SHADER_UNIFORM_FLOAT);

        const resolution = [2]f32{ @as(f32, @floatFromInt(c.GetScreenWidth())), @as(f32, @floatFromInt(c.GetScreenHeight())) };

        c.SetShaderValue(this.slashShader.source, this.slashShader.resolutionLoc, &resolution, c.SHADER_UNIFORM_VEC2);

        // Draw a quad between from and to positions
        const width: f32 = 20.0;
        var dx: f32 = 0;
        var dy: f32 = 0;

        if (effect.toPos) |to_pos| {
            dx = to_pos.x - effect.fromPos.x;
            dy = to_pos.y - effect.fromPos.y;
        }
        const length = @sqrt(dx * dx + dy * dy);
        const angle = std.math.atan2(dy, dx);

        const rect = c.Rectangle{
            .x = effect.fromPos.x,
            .y = effect.fromPos.y,
            .width = length,
            .height = width,
        };
        const origin = c.Vector2{ .x = 0, .y = width / 2 };

        const src = c.Rectangle{ .x = 0, .y = 0, .width = 1, .height = 1 };

        c.DrawTexturePro(this.texture, src, rect, origin, angle * 180.0 / std.math.pi, c.WHITE);

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

        const effect = Effect.init(from_pixel, to_pixel, .slash, 0.3);
        try this.effects.append(effect);
    }

    pub fn spawnExplosion(this: *ShaderManager, pos: Types.Vector2Int) !void {
        const pos_pixel = c.Vector2{
            .x = @as(f32, @floatFromInt(pos.x * Config.tile_width + Config.tile_width / 2)),
            .y = @as(f32, @floatFromInt(pos.y * Config.tile_height + Config.tile_height / 2)),
        };

        const effect = Effect.init(pos_pixel, null, .explosion, 0.5);
        try this.effects.append(effect);
    }

    pub fn spawnImpact(this: *ShaderManager, pos: Types.Vector2Int) !void {
        const pos_pixel = c.Vector2{
            .x = @as(f32, @floatFromInt(pos.x * Config.tile_width + Config.tile_width / 2)),
            .y = @as(f32, @floatFromInt(pos.y * Config.tile_height + Config.tile_height / 2)),
        };

        const effect = Effect.init(pos_pixel, null, .impact, 0.3);
        try this.effects.append(effect);
    }

    pub fn draw(this: *ShaderManager) void {
        for (this.effects.items) |*effect| {
            if (!effect.active) continue;

            const progress = effect.time / effect.duration;

            switch (effect.effectType) {
                .slash => this.drawSlash(effect, progress),
                .impact => this.drawImpact(effect, progress),
                .explosion => this.drawExplosion(effect, progress),
            }
        }
    }
};
