// Bobbing/floating animation
pub fn drawEntityWithBob(entity: *Entity.Entity, time: f32) void {
    const bobAmount = 2.0;
    const bobSpeed = 3.0;
    const offset = @sin(time * bobSpeed) * bobAmount;

    const pos = c.Vector2{
        .x = @floatFromInt(entity.pos.x * Config.tile_width),
        .y = @floatFromInt(entity.pos.y * Config.tile_height) + offset,
    };

    c.DrawTextureRec(tileset, entity.sourceRect.?, pos, c.WHITE);
}

// Squash and stretch on hit
pub fn drawEntityWithSquash(entity: *Entity.Entity, squashAmount: f32) void {
    const sourceRect = entity.sourceRect.?;
    const destRect = c.Rectangle{
        .x = @floatFromInt(entity.pos.x * Config.tile_width),
        .y = @floatFromInt(entity.pos.y * Config.tile_height),
        .width = sourceRect.width * (1.0 + squashAmount), // Squash wider
        .height = sourceRect.height * (1.0 - squashAmount), // Squash shorter
    };

    c.DrawTexturePro(tileset, sourceRect, destRect, c.Vector2{ .x = 0, .y = 0 }, 0.0, c.WHITE);
}

// Rotation (for death, hits, etc.)
pub fn drawEntityWithRotation(entity: *Entity.Entity, rotation: f32) void {
    const sourceRect = entity.sourceRect.?;
    const destRect = c.Rectangle{
        .x = @floatFromInt(entity.pos.x * Config.tile_width + Config.tile_width / 2),
        .y = @floatFromInt(entity.pos.y * Config.tile_height + Config.tile_height / 2),
        .width = sourceRect.width,
        .height = sourceRect.height,
    };

    const origin = c.Vector2{
        .x = sourceRect.width / 2,
        .y = sourceRect.height / 2,
    };

    c.DrawTexturePro(tileset, sourceRect, destRect, origin, rotation, c.WHITE);
}

// Pulse/scale animation (for selection, powerups)
pub fn drawEntityWithScale(entity: *Entity.Entity, scale: f32) void {
    const sourceRect = entity.sourceRect.?;
    const destRect = c.Rectangle{
        .x = @floatFromInt(entity.pos.x * Config.tile_width),
        .y = @floatFromInt(entity.pos.y * Config.tile_height),
        .width = sourceRect.width * scale,
        .height = sourceRect.height * scale,
    };

    c.DrawTexturePro(tileset, sourceRect, destRect, c.Vector2{ .x = 0, .y = 0 }, 0.0, c.WHITE);
}

// Flash on damage
pub fn drawEntityWithFlash(entity: *Entity.Entity, flashAmount: f32) void {
    var color = c.WHITE;
    color.r = @intFromFloat(255 * (1.0 - flashAmount) + 255 * flashAmount);
    color.g = @intFromFloat(255 * (1.0 - flashAmount));
    color.b = @intFromFloat(255 * (1.0 - flashAmount));

    const pos = c.Vector2{
        .x = @floatFromInt(entity.pos.x * Config.tile_width),
        .y = @floatFromInt(entity.pos.y * Config.tile_height),
    };

    c.DrawTextureRec(tileset, entity.sourceRect.?, pos, color);
}

// Fade in/out
pub fn drawEntityWithAlpha(entity: *Entity.Entity, alpha: f32) void {
    var color = c.WHITE;
    color.a = @intFromFloat(255 * alpha);

    const pos = c.Vector2{
        .x = @floatFromInt(entity.pos.x * Config.tile_width),
        .y = @floatFromInt(entity.pos.y * Config.tile_height),
    };

    c.DrawTextureRec(tileset, entity.sourceRect.?, pos, color);
}

// Tint for status effects
pub fn drawEntityWithTint(entity: *Entity.Entity, tintColor: c.Color) void {
    const pos = c.Vector2{
        .x = @floatFromInt(entity.pos.x * Config.tile_width),
        .y = @floatFromInt(entity.pos.y * Config.tile_height),
    };

    c.DrawTextureRec(tileset, entity.sourceRect.?, pos, tintColor);
}
pub const AnimationType = enum {
    none,
    idle_bob,
    hit_flash,
    death_spin,
    attack_lunge,
    spawn_fade,
};

pub const Animation = struct {
    type: AnimationType,
    time: f32,
    duration: f32,

    pub fn update(this: *Animation, delta: f32) bool {
        this.time += delta;
        return this.time < this.duration;
    }

    pub fn getProgress(this: *Animation) f32 {
        return @min(this.time / this.duration, 1.0);
    }
};

// Add to Entity
pub const Entity = struct {
    // ... existing fields
    animation: ?Animation = null,

    pub fn playAnimation(this: *Entity, animType: AnimationType, duration: f32) void {
        this.animation = Animation{
            .type = animType,
            .time = 0,
            .duration = duration,
        };
    }
};
pub fn Draw(this: *Entity, tilesetManager: *TilesetManager.TilesetManager, time: f32) void {
    if (!this.visible) return;

    const basePos = c.Vector2{
        .x = @floatFromInt(this.pos.x * Config.tile_width),
        .y = @floatFromInt(this.pos.y * Config.tile_height),
    };

    var pos = basePos;
    var rotation: f32 = 0;
    var scale: f32 = 1.0;
    var color = c.WHITE;

    // Apply animation
    if (this.animation) |*anim| {
        const progress = anim.getProgress();

        switch (anim.type) {
            .idle_bob => {
                pos.y += @sin(time * 3.0) * 2.0;
            },
            .hit_flash => {
                const flash = 1.0 - progress;
                color.r = 255;
                color.g = @intFromFloat(255 * (1.0 - flash));
                color.b = @intFromFloat(255 * (1.0 - flash));
            },
            .death_spin => {
                rotation = progress * 360.0;
                scale = 1.0 - progress;
                color.a = @intFromFloat(255 * (1.0 - progress));
            },
            .attack_lunge => {
                // Lunge forward and back
                const lungeDistance = 8.0;
                const t = if (progress < 0.5) progress * 2.0 else (1.0 - progress) * 2.0;
                pos.x += lungeDistance * t;
            },
            .spawn_fade => {
                scale = progress;
                color.a = @intFromFloat(255 * progress);
            },
            .none => {},
        }
    }

    if (this.sourceRect) |sourceRect| {
        const destRect = c.Rectangle{
            .x = pos.x,
            .y = pos.y,
            .width = sourceRect.width * scale,
            .height = sourceRect.height * scale,
        };

        const origin = c.Vector2{ .x = 0, .y = 0 };

        c.DrawTexturePro(tilesetManager.tileset, sourceRect, destRect, origin, rotation, color);
    }
}
// In Entity
pub const Entity = struct {
    // ... existing
    displayPos: c.Vector2, // Smoothed position for rendering

    pub fn updateDisplayPos(this: *Entity, delta: f32) void {
        const targetX = @floatFromInt(this.pos.x * Config.tile_width);
        const targetY = @floatFromInt(this.pos.y * Config.tile_height);

        const speed = 8.0; // Lerp speed
        this.displayPos.x += (targetX - this.displayPos.x) * speed * delta;
        this.displayPos.y += (targetY - this.displayPos.y) * speed * delta;
    }
};

// Then draw using displayPos instead of pos
// Animated tiles (water, lava, torches)
pub fn drawAnimatedTile(tile: Tile, index: usize, time: f32) void {
    var sourceRect = tile.sourceRect.?;

    switch (tile.tile_type) {
        .water => {
            // Shift texture slightly for ripple effect
            const offset = @sin(time * 2.0 + @as(f32, @floatFromInt(index))) * 0.5;
            sourceRect.x += offset;
        },
        .lava => {
            // Pulse color
            const pulse = (@sin(time * 3.0) + 1.0) / 2.0;
            var color = c.RED;
            color.r = @intFromFloat(200 + 55 * pulse);
            c.DrawTextureRec(tileset, sourceRect, pos, color);
            return;
        },
        else => {},
    }

    c.DrawTextureRec(tileset, sourceRect, pos, c.WHITE);
}
