const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});

pub fn main() void {
    rl.InitWindow(800, 600, "Slash Animation");
    rl.SetTargetFPS(60);

    var frame: i32 = 0;
    var slashing = false;
    const slashPos = rl.Vector2{ .x = 400, .y = 300 };

    while (!rl.WindowShouldClose()) {
        // Start animation with space
        if (rl.IsKeyPressed(rl.KEY_SPACE)) {
            slashing = true;
            frame = 0;
        }

        rl.BeginDrawing();
        rl.ClearBackground(rl.BLACK);

        // Draw player
        rl.DrawCircleV(slashPos, 10, rl.GREEN);

        // Slash animation (5 frames long)
        if (slashing) {
            const length: f32 = 40;
            const angleBase: f32 = -45.0;
            const angleStep: f32 = 20.0;

            const angle = angleBase + @as(f32, @floatFromInt(frame)) * angleStep;
            const rad = angle * (std.math.pi / 180.0);

            const endX = slashPos.x + length * @cos(rad);
            const endY = slashPos.y + length * @sin(rad);

            rl.DrawLineEx(slashPos, rl.Vector2{ .x = endX, .y = endY }, 4, rl.RED);

            frame += 1;
            if (frame > 4) slashing = false;
        }

        rl.EndDrawing();
    }

    rl.CloseWindow();
}
