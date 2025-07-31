const std = @import("std");
const rl = @import("raylib");
const Allocator = std.mem.Allocator;

// Basic UI types
const Vec2 = struct {
    x: i32,
    y: i32,
};

const Rect = struct {
    x: i32,
    y: i32,
    w: i32,
    h: i32,

    pub fn contains(self: Rect, pos: Vec2) bool {
        return pos.x >= self.x and pos.x < self.x + self.w and
            pos.y >= self.y and pos.y < self.y + self.h;
    }
};

const Color = enum {
    white,
    gray,
    dark_gray,
    black,
    red,
    green,
    blue,
    yellow,

    pub fn toRaylib(self: Color) rl.Color {
        return switch (self) {
            .white => rl.WHITE,
            .gray => rl.GRAY,
            .dark_gray => rl.DARKGRAY,
            .black => rl.BLACK,
            .red => rl.RED,
            .green => rl.GREEN,
            .blue => rl.BLUE,
            .yellow => rl.YELLOW,
        };
    }
};

// UI Context - holds rendering state
const UiContext = struct {
    char_width: f32,
    char_height: f32,
    font_size: i32,
    hot_id: u32, // which element mouse is over
    active_id: u32, // which element is being interacted with

    pub fn init(font_size: i32) UiContext {
        const char_width = rl.MeasureText("X", font_size);
        return UiContext{
            .char_width = @floatFromInt(char_width),
            .char_height = @floatFromInt(font_size),
            .font_size = font_size,
            .hot_id = 0,
            .active_id = 0,
        };
    }

    // Convert grid coordinates to pixel coordinates
    pub fn gridToPixel(self: *const UiContext, grid_pos: Vec2) Vec2 {
        return Vec2{
            .x = @intFromFloat(@as(f32, @floatFromInt(grid_pos.x)) * self.char_width),
            .y = @intFromFloat(@as(f32, @floatFromInt(grid_pos.y)) * self.char_height),
        };
    }

    // Convert pixel coordinates to grid coordinates
    pub fn pixelToGrid(self: *const UiContext, pixel_pos: Vec2) Vec2 {
        return Vec2{
            .x = @intFromFloat(@as(f32, @floatFromInt(pixel_pos.x)) / self.char_width),
            .y = @intFromFloat(@as(f32, @floatFromInt(pixel_pos.y)) / self.char_height),
        };
    }

    // Draw a single character at grid position
    pub fn drawChar(self: *const UiContext, pos: Vec2, char: u8, color: Color) void {
        const pixel_pos = self.gridToPixel(pos);
        const text = [_:0]u8{char};
        rl.DrawText(&text, pixel_pos.x, pixel_pos.y, self.font_size, color.toRaylib());
    }

    // Draw text string at grid position
    pub fn drawText(self: *const UiContext, pos: Vec2, text: []const u8, color: Color) void {
        const pixel_pos = self.gridToPixel(pos);
        // Create null-terminated string for raylib
        var buffer: [256:0]u8 = undefined;
        @memcpy(buffer[0..text.len], text);
        buffer[text.len] = 0;
        rl.DrawText(&buffer, pixel_pos.x, pixel_pos.y, self.font_size, color.toRaylib());
    }

    // Draw a box with ASCII characters
    pub fn drawBox(self: *const UiContext, rect: Rect, color: Color) void {
        // Draw corners
        self.drawChar(Vec2{ .x = rect.x, .y = rect.y }, '+', color);
        self.drawChar(Vec2{ .x = rect.x + rect.w - 1, .y = rect.y }, '+', color);
        self.drawChar(Vec2{ .x = rect.x, .y = rect.y + rect.h - 1 }, '+', color);
        self.drawChar(Vec2{ .x = rect.x + rect.w - 1, .y = rect.y + rect.h - 1 }, '+', color);

        // Draw horizontal lines
        var x: i32 = rect.x + 1;
        while (x < rect.x + rect.w - 1) : (x += 1) {
            self.drawChar(Vec2{ .x = x, .y = rect.y }, '-', color);
            self.drawChar(Vec2{ .x = x, .y = rect.y + rect.h - 1 }, '-', color);
        }

        // Draw vertical lines
        var y: i32 = rect.y + 1;
        while (y < rect.y + rect.h - 1) : (y += 1) {
            self.drawChar(Vec2{ .x = rect.x, .y = y }, '|', color);
            self.drawChar(Vec2{ .x = rect.x + rect.w - 1, .y = y }, '|', color);
        }
    }

    // Fill a rectangle with a character
    pub fn fillRect(self: *const UiContext, rect: Rect, char: u8, color: Color) void {
        var y: i32 = rect.y;
        while (y < rect.y + rect.h) : (y += 1) {
            var x: i32 = rect.x;
            while (x < rect.x + rect.w) : (x += 1) {
                self.drawChar(Vec2{ .x = x, .y = y }, char, color);
            }
        }
    }
};

// Simple UI elements
const Panel = struct {
    rect: Rect,
    title: []const u8,

    pub fn draw(self: *const Panel, ctx: *const UiContext) void {
        // Draw box border
        ctx.drawBox(self.rect, .white);

        // Draw title if it exists
        if (self.title.len > 0) {
            ctx.drawText(Vec2{ .x = self.rect.x + 1, .y = self.rect.y }, self.title, .yellow);
        }
    }

    pub fn getContentRect(self: *const Panel) Rect {
        return Rect{
            .x = self.rect.x + 1,
            .y = self.rect.y + if (self.title.len > 0) 2 else 1,
            .w = self.rect.w - 2,
            .h = self.rect.h - if (self.title.len > 0) 3 else 2,
        };
    }
};

const Button = struct {
    rect: Rect,
    text: []const u8,
    id: u32,

    pub fn update(self: *const Button, ctx: *UiContext) bool {
        const mouse_pos = Vec2{
            .x = rl.GetMouseX(),
            .y = rl.GetMouseY(),
        };
        const grid_mouse = ctx.pixelToGrid(mouse_pos);
        const is_hot = self.rect.contains(grid_mouse);

        if (is_hot) {
            ctx.hot_id = self.id;
            if (rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT)) {
                ctx.active_id = self.id;
            }
        }

        const is_active = ctx.active_id == self.id;
        const clicked = is_active and rl.IsMouseButtonReleased(rl.MOUSE_BUTTON_LEFT);

        if (clicked) {
            ctx.active_id = 0;
        }

        return clicked;
    }

    pub fn draw(self: *const Button, ctx: *const UiContext) void {
        const is_hot = ctx.hot_id == self.id;
        const is_active = ctx.active_id == self.id;

        const bg_color: Color = if (is_active) .dark_gray else if (is_hot) .gray else .black;
        const text_color: Color = if (is_hot) .yellow else .white;

        // Fill background
        ctx.fillRect(self.rect, ' ', bg_color);

        // Draw border
        ctx.drawBox(self.rect, if (is_hot) .yellow else .white);

        // Draw centered text
        const text_x = self.rect.x + (self.rect.w - @as(i32, @intCast(self.text.len))) / 2;
        const text_y = self.rect.y + self.rect.h / 2;
        ctx.drawText(Vec2{ .x = text_x, .y = text_y }, self.text, text_color);
    }
};

// Example usage structure
const GameUI = struct {
    ctx: UiContext,
    game_panel: Panel,
    stats_panel: Panel,
    log_panel: Panel,
    quit_button: Button,

    pub fn init() GameUI {
        return GameUI{
            .ctx = UiContext.init(16),
            .game_panel = Panel{
                .rect = Rect{ .x = 0, .y = 0, .w = 60, .h = 40 },
                .title = "Game World",
            },
            .stats_panel = Panel{
                .rect = Rect{ .x = 61, .y = 0, .w = 20, .h = 20 },
                .title = "Stats",
            },
            .log_panel = Panel{
                .rect = Rect{ .x = 61, .y = 21, .w = 20, .h = 19 },
                .title = "Log",
            },
            .quit_button = Button{
                .rect = Rect{ .x = 65, .y = 35, .w = 10, .h = 3 },
                .text = "Quit",
                .id = 1,
            },
        };
    }

    pub fn update(self: *GameUI) void {
        // Reset hot id each frame
        self.ctx.hot_id = 0;

        // Update interactive elements
        if (self.quit_button.update(&self.ctx)) {
            // Handle quit button click
            rl.CloseWindow();
        }
    }

    pub fn draw(self: *const GameUI) void {
        rl.ClearBackground(rl.BLACK);

        // Draw panels
        self.game_panel.draw(&self.ctx);
        self.stats_panel.draw(&self.ctx);
        self.log_panel.draw(&self.ctx);

        // Draw buttons
        self.quit_button.draw(&self.ctx);

        // Example content in panels
        const stats_content = self.stats_panel.getContentRect();
        self.ctx.drawText(Vec2{ .x = stats_content.x, .y = stats_content.y }, "HP: 100/100", .green);
        self.ctx.drawText(Vec2{ .x = stats_content.x, .y = stats_content.y + 1 }, "MP: 50/50", .blue);

        const log_content = self.log_panel.getContentRect();
        self.ctx.drawText(Vec2{ .x = log_content.x, .y = log_content.y }, "Game started", .gray);
        self.ctx.drawText(Vec2{ .x = log_content.x, .y = log_content.y + 1 }, "Ready for action", .white);

        // Example game world content
        const game_content = self.game_panel.getContentRect();
        self.ctx.drawChar(Vec2{ .x = game_content.x + 10, .y = game_content.y + 10 }, '@', .yellow);
        self.ctx.drawChar(Vec2{ .x = game_content.x + 15, .y = game_content.y + 12 }, 'G', .red);
    }
};
