const std = @import("std");
const Types = @import("../common/types.zig");
const Config = @import("../common/config.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

var allocator: std.mem.Allocator = undefined;
var effects: std.ArrayList(Effect) = undefined;

var slashShader: *Shader = undefined;
var impactShader: *Shader = undefined;
var explosionShader: *Shader = undefined;
var texture: c.Texture2D = undefined;

pub fn init(alloc: std.mem.Allocator) !void {
    allocator = alloc;
    effects = std.ArrayList(Effect).empty;
    slashShader = try Shader.init("src/shaders/slash.fs");
    impactShader = try Shader.init("src/shaders/impact.fs");
    explosionShader = try Shader.init("src/shaders/explosion.fs");

    const whiteImage = c.GenImageColor(1, 1, c.WHITE);
    texture = c.LoadTextureFromImage(whiteImage);
}

pub fn update(delta: f32) void {
    //TODO: deinit the effect?
    var i: usize = 0;
    while (i < effects.items.len) {
        if (!effects.items[i].update(delta)) {
            _ = effects.swapRemove(i);
        } else {
            i += 1;
        }
    }
}
fn drawImpact(effect: *Effect, progress: f32) void {
    c.BeginShaderMode(impactShader.source);

    // Set shader uniforms
    c.SetShaderValue(impactShader.source, impactShader.timeLoc, &progress, c.SHADER_UNIFORM_FLOAT);

    const resolution = [2]f32{
        @as(f32, @floatFromInt(c.GetScreenWidth())),
        @as(f32, @floatFromInt(c.GetScreenHeight())),
    };
    c.SetShaderValue(impactShader.source, impactShader.resolutionLoc, &resolution, c.SHADER_UNIFORM_VEC2);

    // Compute size and position
    const size = 40.0 * (1.0 + progress);
    const destX = effect.fromPos.x; //- size / 2;
    const destY = effect.fromPos.y; //- size / 2;

    // Draw texture instead of rectangle
    const tex = texture; // Assuming you have loaded this earlier
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

fn drawExplosion(effect: *Effect, progress: f32) void {
    c.BeginShaderMode(explosionShader.source);

    // Set shader uniforms
    c.SetShaderValue(explosionShader.source, explosionShader.timeLoc, &progress, c.SHADER_UNIFORM_FLOAT);

    const resolution = [2]f32{
        @as(f32, @floatFromInt(c.GetScreenWidth())),
        @as(f32, @floatFromInt(c.GetScreenHeight())),
    };
    c.SetShaderValue(explosionShader.source, explosionShader.resolutionLoc, &resolution, c.SHADER_UNIFORM_VEC2);

    // Compute size and position
    const size = 30.0 * (1.0 + progress);
    const destX = effect.fromPos.x; //- size / 2;
    const destY = effect.fromPos.y; //- size / 2;

    // Draw texture instead of rectangle
    const tex = texture; // Assuming you have loaded this earlier
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
fn drawSlash(effect: *Effect, progress: f32) void {
    c.BeginShaderMode(slashShader.source);

    c.SetShaderValue(slashShader.source, slashShader.timeLoc, &progress, c.SHADER_UNIFORM_FLOAT);

    const resolution = [2]f32{ @as(f32, @floatFromInt(c.GetScreenWidth())), @as(f32, @floatFromInt(c.GetScreenHeight())) };

    c.SetShaderValue(slashShader.source, slashShader.resolutionLoc, &resolution, c.SHADER_UNIFORM_VEC2);

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

    c.DrawTexturePro(texture, src, rect, origin, angle * 180.0 / std.math.pi, c.WHITE);

    c.EndShaderMode();
}

pub fn spawnSlash(from: Types.Vector2Int, to: Types.Vector2Int) !void {
    const from_pixel = c.Vector2{
        .x = @as(f32, @floatFromInt(from.x * Config.tile_width + Config.tile_width / 2)),
        .y = @as(f32, @floatFromInt(from.y * Config.tile_height + Config.tile_height / 2)),
    };
    const to_pixel = c.Vector2{
        .x = @as(f32, @floatFromInt(to.x * Config.tile_width + Config.tile_width / 2)),
        .y = @as(f32, @floatFromInt(to.y * Config.tile_height + Config.tile_height / 2)),
    };

    const effect = Effect.init(from_pixel, to_pixel, .slash, 0.3);
    try effects.append(allocator, effect);
}

pub fn spawnExplosion(pos: Types.Vector2Int) !void {
    const pos_pixel = c.Vector2{
        .x = @as(f32, @floatFromInt(pos.x * Config.tile_width + Config.tile_width / 2)),
        .y = @as(f32, @floatFromInt(pos.y * Config.tile_height + Config.tile_height / 2)),
    };

    const effect = Effect.init(pos_pixel, null, .explosion, 0.5);
    try effects.append(allocator, effect);
}

pub fn spawnImpact(pos: Types.Vector2Int) !void {
    const pos_pixel = c.Vector2{
        .x = @as(f32, @floatFromInt(pos.x * Config.tile_width + Config.tile_width / 2)),
        .y = @as(f32, @floatFromInt(pos.y * Config.tile_height + Config.tile_height / 2)),
    };

    const effect = Effect.init(pos_pixel, null, .impact, 0.3);
    try effects.append(allocator, effect);
}

pub fn draw() void {
    for (effects.items) |*effect| {
        if (!effect.active) continue;

        const progress = effect.time / effect.duration;

        switch (effect.effectType) {
            .slash => drawSlash(effect, progress),
            .impact => drawImpact(effect, progress),
            .explosion => drawExplosion(effect, progress),
        }
    }
}

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

    pub fn init(path: []const u8) !*Shader {
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
