const std = @import("std");
const rl = @import("raylib");
const Config = @import("../common/config.zig");
const Window = @import("../game/window.zig");

// --- UI State ---
pub var uiTexture: rl.RenderTexture2 = undefined;
var is_initialized: bool = false;

pub const UIContext = struct {
    hot_index: i32 = 0,
    item_count: i32 = 0,
    last_item_count: i32 = 0,
    // Add any other interaction state here
};

pub var ctx: UIContext = .{};

pub fn init() void {
    // Create a texture the size of your game resolution
    uiTexture = rl.loadRenderTexture(Config.game_width, Config.game_height);
    is_initialized = true;
}

pub fn deinit() void {
    if (is_initialized) rl.unloadRenderTexture(uiTexture);
}

pub fn beginUI() void {
    // Start drawing to our "sticker"
    rl.beginTextureMode(uiTexture);
    // Clear with BLANK (fully transparent) so we only see the UI, not a solid background
    rl.clearBackground(rl.Color.blank);

    ctx.item_count = 0;
}

pub fn endUI() void {
    rl.endTextureMode();
    ctx.last_item_count = ctx.item_count;
}

// Example Widget
pub fn doButton(text: [:0]const u8, x: i32, y: i32) bool {
    const is_hot = (ctx.item_count == ctx.hot_index);
    const color = if (is_hot) rl.Color.red else rl.Color.white;

    // We draw IMMEDIATELY to the texture
    rl.drawText(text, x, y, 20, color);

    ctx.item_count += 1;
    // Logic: check input here and return true if clicked
    return false;
}

pub fn draw() void {
    // Draw the "sticker" texture over the whole screen
    // Note: RenderTextures are upside down in OpenGL/Raylib, so use a negative height
    const source = rl.Rectangle{ .x = 0, .y = 0, .width = @floatFromInt(uiTexture.texture.width), .height = @floatFromInt(-uiTexture.texture.height) };

    const dest = rl.Rectangle{ .x = @floatFromInt(Window.offsetx), .y = @floatFromInt(Window.offsety), .width = @floatFromInt(Window.scaledWidth), .height = @floatFromInt(Window.scaledHeight) };

    rl.drawTexturePro(uiTexture.texture, source, dest, .{ .x = 0, .y = 0 }, 0, rl.Color.white);
}

pub fn update(this: *Game) !void {
    // ... other update stuff ...

    UiManager.beginUI();
    // Your UI Logic lives here!
    if (UiManager.doButton("START", 100, 100)) {
        // action
    }
    UiManager.endUI();

    // ... continue update ...
}

pub fn draw(this: *Game) !void {
    // 1. Draw World + Shaders
    // ... (Your existing CRT pass) ...

    // 2. Draw UI Sticker on top of everything
    UiManager.draw();

    rl.endDrawing();
}
