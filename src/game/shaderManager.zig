const std = @import("std");
const Types = @import("../common/types.zig");
const Config = @import("../common/config.zig");
const rl = @import("raylib");

var allocator: std.mem.Allocator = undefined;
var effects: std.ArrayList(Effect) = undefined;

var slashShader: Shader = undefined;
var impactShader: Shader = undefined;
var explosionShader: Shader = undefined;
pub var crtShader: Shader = undefined;
var whiteImage: rl.Image = undefined;
var texture: rl.Texture2D = undefined;

pub fn init(alloc: std.mem.Allocator) !void {
    allocator = alloc;
    effects = std.ArrayList(Effect).empty;
    slashShader = try Shader.init("src/shaders/slash.fs");
    impactShader = try Shader.init("src/shaders/impact.fs");
    explosionShader = try Shader.init("src/shaders/explosion.fs");
    crtShader = try Shader.init("src/shaders/crt.fs");

    whiteImage = rl.genImageColor(1, 1, rl.Color.white);
    texture = try rl.loadTextureFromImage(whiteImage);
}

pub fn deinit() !void {
    effects.deinit(allocator);
    slashShader.deinit();
    impactShader.deinit();
    explosionShader.deinit();

    whiteImage.unload();
    texture.unload();
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
    rl.beginShaderMode(impactShader.source);

    // Set shader uniforms
    rl.setShaderValue(impactShader.source, impactShader.timeLoc, &progress, .float);

    const resolution = [2]f32{
        @as(f32, @floatFromInt(rl.getScreenWidth())),
        @as(f32, @floatFromInt(rl.getScreenHeight())),
    };
    rl.setShaderValue(impactShader.source, impactShader.resolutionLoc, &resolution, .vec2);

    // Compute size and position
    const size = 40.0 * (1.0 + progress);
    const destX = effect.fromPos.x; //- size / 2;
    const destY = effect.fromPos.y; //- size / 2;

    // Draw texture instead of rectangle
    const tex = texture; // Assuming you have loaded this earlier
    const srcRect = rl.Rectangle{
        .x = 0,
        .y = 0,
        .width = @as(f32, @floatFromInt(tex.width)),
        .height = @as(f32, @floatFromInt(tex.height)),
    };
    const destRect = rl.Rectangle{
        .x = destX,
        .y = destY,
        .width = size,
        .height = size,
    };
    const origin = rl.Vector2{ .x = size / 2.0, .y = size / 2.0 };

    // Rotation 0, color white (so shader fully controls the look)
    rl.drawTexturePro(tex, srcRect, destRect, origin, 0.0, rl.Color.white);

    rl.endShaderMode();
}

fn drawExplosion(effect: *Effect, progress: f32) void {
    rl.beginShaderMode(explosionShader.source);

    // Set shader uniforms
    rl.setShaderValue(explosionShader.source, explosionShader.timeLoc, &progress, .float);

    const resolution = [2]f32{
        @as(f32, @floatFromInt(rl.getScreenWidth())),
        @as(f32, @floatFromInt(rl.getScreenHeight())),
    };
    rl.setShaderValue(explosionShader.source, explosionShader.resolutionLoc, &resolution, .vec2);

    // Compute size and position
    const size = 30.0 * (1.0 + progress);
    const destX = effect.fromPos.x; //- size / 2;
    const destY = effect.fromPos.y; //- size / 2;

    // Draw texture instead of rectangle
    const tex = texture; // Assuming you have loaded this earlier
    const srcRect = rl.Rectangle{
        .x = 0,
        .y = 0,
        .width = @as(f32, @floatFromInt(tex.width)),
        .height = @as(f32, @floatFromInt(tex.height)),
    };
    const destRect = rl.Rectangle{
        .x = destX,
        .y = destY,
        .width = size,
        .height = size,
    };
    const origin = rl.Vector2{ .x = size / 2.0, .y = size / 2.0 };

    // Rotation 0, color white (so shader fully controls the look)
    rl.drawTexturePro(tex, srcRect, destRect, origin, 0.0, rl.Color.white);

    rl.endShaderMode();
}
fn drawSlash(effect: *Effect, progress: f32) void {
    rl.beginShaderMode(slashShader.source);

    rl.setShaderValue(slashShader.source, slashShader.timeLoc, &progress, .float);

    const resolution = [2]f32{ @as(f32, @floatFromInt(rl.getScreenWidth())), @as(f32, @floatFromInt(rl.getScreenHeight())) };

    rl.setShaderValue(slashShader.source, slashShader.resolutionLoc, &resolution, .vec2);

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

    const rect = rl.Rectangle{
        .x = effect.fromPos.x,
        .y = effect.fromPos.y,
        .width = length,
        .height = width,
    };
    const origin = rl.Vector2{ .x = 0, .y = width / 2 };

    const src = rl.Rectangle{ .x = 0, .y = 0, .width = 1, .height = 1 };

    rl.drawTexturePro(texture, src, rect, origin, angle * 180.0 / std.math.pi, rl.Color.white);

    rl.endShaderMode();
}

pub fn spawnSlash(from: Types.Vector2Int, to: Types.Vector2Int) !void {
    const from_pixel = rl.Vector2{
        .x = @as(f32, @floatFromInt(from.x * Config.tile_width + Config.tile_width / 2)),
        .y = @as(f32, @floatFromInt(from.y * Config.tile_height + Config.tile_height / 2)),
    };
    const to_pixel = rl.Vector2{
        .x = @as(f32, @floatFromInt(to.x * Config.tile_width + Config.tile_width / 2)),
        .y = @as(f32, @floatFromInt(to.y * Config.tile_height + Config.tile_height / 2)),
    };

    const effect = Effect.init(from_pixel, to_pixel, .slash, 0.3);
    try effects.append(allocator, effect);
}

pub fn spawnExplosion(pos: Types.Vector2Int) !void {
    const pos_pixel = rl.Vector2{
        .x = @as(f32, @floatFromInt(pos.x * Config.tile_width + Config.tile_width / 2)),
        .y = @as(f32, @floatFromInt(pos.y * Config.tile_height + Config.tile_height / 2)),
    };

    const effect = Effect.init(pos_pixel, null, .explosion, 0.5);
    try effects.append(allocator, effect);
}

pub fn spawnImpact(pos: Types.Vector2Int) !void {
    const pos_pixel = rl.Vector2{
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
    //TODO: refactor?
    effectType: EffectType,
    time: f32,
    duration: f32,
    fromPos: rl.Vector2,
    toPos: ?rl.Vector2,
    active: bool,

    pub fn init(fromPosition: rl.Vector2, toPosition: ?rl.Vector2, effectType: EffectType, duration: f32) Effect {
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
    source: rl.Shader,
    timeLoc: i32,
    resolutionLoc: i32,

    pub fn init(path: [:0]const u8) !Shader {
        const source = try rl.loadShader(null, path);

        return Shader{
            .source = source,
            .timeLoc = rl.getShaderLocation(source, "time"),
            .resolutionLoc = rl.getShaderLocation(source, "resolution"),
        };
    }

    pub fn deinit(this: *Shader) void {
        this.source.unload();
    }
};
