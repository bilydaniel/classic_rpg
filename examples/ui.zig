const std = @import("std");
const rl = @import("raylib");
const InputManager = @import("../game/inputManager.zig");
const Window = @import("../game/window.zig");
const Utils = @import("../common/utils.zig");
const Types = @import("../common/types.zig");

// --- IMUI State ---
// This context tracks the user's interaction at any given time.
pub const UIContext = struct {
    // Casey's core identifiers
    hot_id: u32 = 0,
    active_id: u32 = 0,

    // Inputs for the current frame
    nav_y: i32 = 0,
    confirm: bool = false,

    // Menu Layout Tracking
    menu_pos: rl.Vector2 = .{ .x = 0, .y = 0 },
    layout_y: f32 = 0,
    item_index: i32 = 0,
    hot_index: i32 = 0,
    last_frame_item_count: i32 = 0, // Used for wrap-around keyboard navigation
};

pub var ctx: UIContext = .{};

// Simple string hasher to generate unique IDs for elements
pub fn getID(text: []const u8) u32 {
    var hash: u32 = 2166136261;
    for (text) |c| {
        hash ^= c;
        hash *%= 16777619;
    }
    return hash;
}

// ---------------------------------------------------------
// Core API
// ---------------------------------------------------------

pub fn beginFrame() void {
    ctx.nav_y = 0;

    // Read directional inputs
    if (InputManager.takePositionInput()) |move| {
        ctx.nav_y = move.y;
    }

    // Read confirm input
    ctx.confirm = InputManager.takeConfirmInput();
}

pub fn endFrame() void {
    // If confirm is released, nothing is active anymore.
    // Since takeConfirmInput() usually acts as a "pressed this frame" trigger,
    // we reset it at the end of the frame.
    ctx.confirm = false;
}

// ---------------------------------------------------------
// Widgets
// ---------------------------------------------------------

pub fn beginMenu(relPos: RelativePos, size: rl.Vector2, title: [:0]const u8) void {
    const scaledSize = getScaledSize(size);
    const screenPos = relativeToScreenPos(relPos, scaledSize);

    ctx.menu_pos = screenPos;

    // Handle keyboard navigation BEFORE we draw the items
    if (ctx.nav_y == 1) {
        ctx.hot_index += 1;
    } else if (ctx.nav_y == -1) {
        ctx.hot_index -= 1;
    }

    // Wrap around logic (relies on knowing how many items we drew *last* frame)
    if (ctx.last_frame_item_count > 0) {
        if (ctx.hot_index < 0) {
            ctx.hot_index = ctx.last_frame_item_count - 1;
        } else if (ctx.hot_index >= ctx.last_frame_item_count) {
            ctx.hot_index = 0;
        }
    }

    // Reset layout for the incoming items
    ctx.item_index = 0;
    ctx.layout_y = screenPos.y + 35; // Start items underneath the title

    // 1. Draw Background
    rl.drawRectangle(@intFromFloat(screenPos.x), @intFromFloat(screenPos.y), @intFromFloat(scaledSize.x), @intFromFloat(scaledSize.y), rl.Color.blue);

    // 2. Draw Title
    rl.drawText(title, @intFromFloat(screenPos.x + 5), @intFromFloat(screenPos.y + 5), 20, rl.Color.white);
}

pub fn doMenuItem(id: u32, text: [:0]const u8) bool {
    const is_hot = (ctx.item_index == ctx.hot_index);
    var clicked = false;

    // Logic: Is this interacted with?
    if (is_hot) {
        ctx.hot_id = id;
        if (ctx.confirm) {
            ctx.active_id = id;
            clicked = true;
            ctx.confirm = false; // Consume the input so we don't trigger multiple menus at once
        }
    }

    // Drawing
    const color = if (is_hot) rl.Color.red else rl.Color.yellow;
    const x_offset: f32 = if (is_hot) 15 else 5; // Indent the hovered item slightly

    if (is_hot) {
        // Draw a pointer/arrow for the hot item
        rl.drawText(">", @intFromFloat(ctx.menu_pos.x + 5), @intFromFloat(ctx.layout_y), 20, color);
    }

    rl.drawText(text, @intFromFloat(ctx.menu_pos.x + x_offset), @intFromFloat(ctx.layout_y), 20, color);

    // Advance layout for the next item
    ctx.item_index += 1;
    ctx.layout_y += 20;

    return clicked;
}

pub fn endMenu() void {
    // Save how many items we actually processed. Next frame needs this to wrap keyboard navigation.
    ctx.last_frame_item_count = ctx.item_index;
}

// Simple passive UI elements (No logic, just drawing)
pub fn drawPanel(relPos: RelativePos, size: rl.Vector2, color: rl.Color) void {
    const scaledSize = getScaledSize(size);
    const screenPos = relativeToScreenPos(relPos, scaledSize);
    rl.drawRectangle(@intFromFloat(screenPos.x), @intFromFloat(screenPos.y), @intFromFloat(scaledSize.x), @intFromFloat(scaledSize.y), color);
}

pub fn drawTextLabel(relPos: RelativePos, size: rl.Vector2, text: [:0]const u8, fontSize: i32, color: rl.Color) void {
    const scaledSize = getScaledSize(size);
    const screenPos = relativeToScreenPos(relPos, scaledSize);
    const scaledFontSize = @as(c_int, @intFromFloat(@as(f32, @floatFromInt(fontSize)) * Window.scale));

    rl.drawText(text, @intFromFloat(screenPos.x), @intFromFloat(screenPos.y), scaledFontSize, color);
}

// ---------------------------------------------------------
// Positioning & Alignment Utilities (Kept from original)
// ---------------------------------------------------------

pub const AnchorEnum = enum {
    top_left,
    top_center,
    top_right,
    center_left,
    center,
    center_right,
    bottom_left,
    bottom_center,
    bottom_right,
};

pub const RelativePos = struct {
    anchor: AnchorEnum,
    pos: rl.Vector2,

    pub fn init(anchor: AnchorEnum, x: f32, y: f32) RelativePos {
        return .{ .anchor = anchor, .pos = .{ .x = x, .y = y } };
    }
};

fn getScaledSize(size: rl.Vector2) rl.Vector2 {
    return Utils.vector2Scale(size, Window.scale);
}

fn relativeToScreenPos(rPos: RelativePos, size: rl.Vector2) rl.Vector2 {
    const anchorPosition = getAnchorPosition(rPos.anchor);
    const position = Utils.vector2Scale(rPos.pos, Window.scale);
    var result = Utils.vector2Add(anchorPosition, position);

    switch (rPos.anchor) {
        .top_center, .center, .bottom_center => {
            result.x -= (size.x * Window.scale) / 2;
        },
        .top_right, .center_right, .bottom_right => {
            result.x -= size.x * Window.scale;
        },
        else => {},
    }
    switch (rPos.anchor) {
        .center_left, .center, .center_right => {
            result.y -= (size.y * Window.scale) / 2;
        },
        .bottom_left, .bottom_center, .bottom_right => {
            result.y -= size.y * Window.scale;
        },
        else => {},
    }
    return result;
}

fn getAnchorPosition(anchor: AnchorEnum) rl.Vector2 {
    return switch (anchor) {
        .top_left => .{ .x = 0, .y = 0 },
        .top_center => .{ .x = Window.scaledWidthHalf, .y = 0 },
        .top_right => .{ .x = @floatFromInt(Window.scaledWidth), .y = 0 },
        .center_left => .{ .x = 0, .y = Window.scaledHeightHalf },
        .center => .{ .x = Window.scaledWidthHalf, .y = Window.scaledHeightHalf },
        .center_right => .{ .x = @floatFromInt(Window.scaledWidth), .y = Window.scaledHeightHalf },
        .bottom_left => .{ .x = 0, .y = @floatFromInt(Window.scaledHeight) },
        .bottom_center => .{ .x = Window.scaledWidthHalf, .y = @floatFromInt(Window.scaledHeight) },
        .bottom_right => .{ .x = @floatFromInt(Window.scaledWidth), .y = @floatFromInt(Window.scaledHeight) },
    };
}

UIManager.beginFrame();

// 1. Draw your passive, static UI parts unconditionally
const turnStr = try std.fmt.bufPrintZ(&buffer, "Turn: {}", .{TurnManager.turnNumber});
UIManager.drawTextLabel(turnNumberPos, turnNumberSize, turnStr, 25, rl.Color.white);

// 2. Draw active menus dynamically based on your state
if (Gamestate.showMenu == .action_select) {
    UIManager.beginMenu(actionMenuPos, actionMenuSize, "Pick an Action:");
    
    if (UIManager.doMenuItem(UIManager.getID("MOVE"), "MOVE")) {
        // BOOM! The action happens immediately right here.
        // No more UiCommand parsing or callbacks needed.
        handleMoveAction(); 
    }
    
    if (UIManager.doMenuItem(UIManager.getID("ATTACK"), "ATTACK")) {
        handleAttackAction();
    }
    
    UIManager.endMenu();
}

UIManager.endFrame();


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
    const source = rl.Rectangle{ 
        .x = 0, .y = 0, 
        .width = @floatFromInt(uiTexture.texture.width), 
        .height = @floatFromInt(-uiTexture.texture.height) 
    };
    
    const dest = rl.Rectangle{ 
        .x = @floatFromInt(Window.offsetx), 
        .y = @floatFromInt(Window.offsety), 
        .width = @floatFromInt(Window.scaledWidth), 
        .height = @floatFromInt(Window.scaledHeight) 
    };

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

pub fn doMenuItem(text: [:0]const u8, src: std.builtin.SourceLocation) bool {
    // Use the line number and column as a combined ID
    const id = @as(u32, @intCast(src.line)) ^ (@as(u32, @intCast(src.column)) << 16);
    
    // ... interaction logic ...
}

// Usage:
if (doMenuItem("MOVE", @src())) { ... }
