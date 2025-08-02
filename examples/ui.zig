const std = @import("std");
const raylib = @import("raylib");
const Allocator = std.mem.Allocator;

// Core GUI types
pub const Color = raylib.Color;
pub const Vector2 = raylib.Vector2;
pub const Rectangle = raylib.Rectangle;

pub const Theme = struct {
    background: Color = raylib.BLACK,
    foreground: Color = raylib.WHITE,
    border: Color = raylib.GRAY,
    highlight: Color = raylib.YELLOW,
    accent: Color = raylib.GREEN,
    font_size: i32 = 16,
    char_width: f32 = 8,
    char_height: f32 = 16,
};

pub const Alignment = enum {
    left,
    center,
    right,
};

// Base widget interface
pub const Widget = struct {
    rect: Rectangle,
    visible: bool = true,
    focusable: bool = false,
    focused: bool = false,

    const Self = @This();

    pub fn contains_point(self: *const Self, point: Vector2) bool {
        return raylib.CheckCollisionPointRec(point, self.rect);
    }
};

// Panel - container for other widgets
pub const Panel = struct {
    widget: Widget,
    title: ?[]const u8 = null,
    border: bool = true,
    theme: *const Theme,

    const Self = @This();

    pub fn init(rect: Rectangle, theme: *const Theme) Self {
        return Self{
            .widget = Widget{ .rect = rect },
            .theme = theme,
        };
    }

    pub fn draw(self: *const Self) void {
        if (!self.widget.visible) return;

        // Draw background
        raylib.DrawRectangleRec(self.widget.rect, self.theme.background);

        // Draw border if enabled
        if (self.border) {
            raylib.DrawRectangleLinesEx(self.widget.rect, 1, self.theme.border);

            // Draw ASCII-style corners and edges
            const x = @as(i32, @intFromFloat(self.widget.rect.x));
            const y = @as(i32, @intFromFloat(self.widget.rect.y));
            const w = @as(i32, @intFromFloat(self.widget.rect.width));
            const h = @as(i32, @intFromFloat(self.widget.rect.height));

            // Corners
            raylib.DrawText("┌", x, y, self.theme.font_size, self.theme.border);
            raylib.DrawText("┐", x + w - 8, y, self.theme.font_size, self.theme.border);
            raylib.DrawText("└", x, y + h - 16, self.theme.font_size, self.theme.border);
            raylib.DrawText("┘", x + w - 8, y + h - 16, self.theme.font_size, self.theme.border);
        }

        // Draw title if present
        if (self.title) |title| {
            const title_x = @as(i32, @intFromFloat(self.widget.rect.x + 16));
            const title_y = @as(i32, @intFromFloat(self.widget.rect.y + 2));
            raylib.DrawText(@ptrCast(title.ptr), title_x, title_y, self.theme.font_size, self.theme.foreground);
        }
    }
};

// Text widget
pub const Text = struct {
    widget: Widget,
    content: []const u8,
    alignment: Alignment = .left,
    theme: *const Theme,

    const Self = @This();

    pub fn init(rect: Rectangle, content: []const u8, theme: *const Theme) Self {
        return Self{
            .widget = Widget{ .rect = rect },
            .content = content,
            .theme = theme,
        };
    }

    pub fn draw(self: *const Self) void {
        if (!self.widget.visible) return;

        var x = @as(i32, @intFromFloat(self.widget.rect.x));
        const y = @as(i32, @intFromFloat(self.widget.rect.y));

        // Calculate alignment offset
        switch (self.alignment) {
            .center => {
                const text_width = raylib.MeasureText(@ptrCast(self.content.ptr), self.theme.font_size);
                x += @as(i32, @intFromFloat(self.widget.rect.width)) / 2 - text_width / 2;
            },
            .right => {
                const text_width = raylib.MeasureText(@ptrCast(self.content.ptr), self.theme.font_size);
                x += @as(i32, @intFromFloat(self.widget.rect.width)) - text_width;
            },
            .left => {},
        }

        raylib.DrawText(@ptrCast(self.content.ptr), x, y, self.theme.font_size, self.theme.foreground);
    }
};

// Menu widget for selections
pub const Menu = struct {
    widget: Widget,
    items: [][]const u8,
    selected_index: usize = 0,
    theme: *const Theme,

    const Self = @This();

    pub fn init(rect: Rectangle, items: [][]const u8, theme: *const Theme) Self {
        return Self{
            .widget = Widget{
                .rect = rect,
                .focusable = true,
            },
            .items = items,
            .theme = theme,
        };
    }

    pub fn handle_input(self: *Self) bool {
        if (!self.widget.focused) return false;

        var changed = false;

        if (raylib.IsKeyPressed(raylib.KEY_UP) or raylib.IsKeyPressed(raylib.KEY_K)) {
            if (self.selected_index > 0) {
                self.selected_index -= 1;
                changed = true;
            }
        }

        if (raylib.IsKeyPressed(raylib.KEY_DOWN) or raylib.IsKeyPressed(raylib.KEY_J)) {
            if (self.selected_index < self.items.len - 1) {
                self.selected_index += 1;
                changed = true;
            }
        }

        return changed;
    }

    pub fn is_item_selected(self: *const Self) bool {
        return raylib.IsKeyPressed(raylib.KEY_ENTER) or raylib.IsKeyPressed(raylib.KEY_SPACE);
    }

    pub fn draw(self: *const Self) void {
        if (!self.widget.visible) return;

        const x = @as(i32, @intFromFloat(self.widget.rect.x));
        var y = @as(i32, @intFromFloat(self.widget.rect.y));

        for (self.items, 0..) |item, i| {
            const color = if (i == self.selected_index) self.theme.highlight else self.theme.foreground;
            const prefix = if (i == self.selected_index) "> " else "  ";

            // Draw selection indicator
            raylib.DrawText(@ptrCast(prefix.ptr), x, y, self.theme.font_size, color);

            // Draw menu item
            raylib.DrawText(@ptrCast(item.ptr), x + 16, y, self.theme.font_size, color);

            y += self.theme.font_size + 2;
        }
    }
};

// Button widget
pub const Button = struct {
    widget: Widget,
    label: []const u8,
    pressed: bool = false,
    theme: *const Theme,

    const Self = @This();

    pub fn init(rect: Rectangle, label: []const u8, theme: *const Theme) Self {
        return Self{
            .widget = Widget{
                .rect = rect,
                .focusable = true,
            },
            .label = label,
            .theme = theme,
        };
    }

    pub fn handle_input(self: *Self, mouse_pos: Vector2) bool {
        self.pressed = false;

        if (self.widget.contains_point(mouse_pos)) {
            if (raylib.IsMouseButtonPressed(raylib.MOUSE_BUTTON_LEFT)) {
                self.pressed = true;
                return true;
            }
        }

        // Keyboard activation when focused
        if (self.widget.focused and raylib.IsKeyPressed(raylib.KEY_ENTER)) {
            self.pressed = true;
            return true;
        }

        return false;
    }

    pub fn draw(self: *const Self) void {
        if (!self.widget.visible) return;

        const bg_color = if (self.widget.focused) self.theme.accent else self.theme.background;
        const border_color = if (self.widget.focused) self.theme.highlight else self.theme.border;

        // Draw button background
        raylib.DrawRectangleRec(self.widget.rect, bg_color);
        raylib.DrawRectangleLinesEx(self.widget.rect, 1, border_color);

        // Draw label centered
        const text_width = raylib.MeasureText(@ptrCast(self.label.ptr), self.theme.font_size);
        const x = @as(i32, @intFromFloat(self.widget.rect.x + self.widget.rect.width / 2)) - text_width / 2;
        const y = @as(i32, @intFromFloat(self.widget.rect.y + self.widget.rect.height / 2)) - self.theme.font_size / 2;

        raylib.DrawText(@ptrCast(self.label.ptr), x, y, self.theme.font_size, self.theme.foreground);
    }
};

// GUI Manager to handle focus and input routing
pub const GuiManager = struct {
    theme: Theme,
    focused_widget: ?*Widget = null,
    allocator: Allocator,

    const Self = @This();

    pub fn init(allocator: Allocator) Self {
        return Self{
            .theme = Theme{},
            .allocator = allocator,
        };
    }

    pub fn set_focus(self: *Self, widget: ?*Widget) void {
        if (self.focused_widget) |current| {
            current.focused = false;
        }

        self.focused_widget = widget;

        if (widget) |w| {
            if (w.focusable) {
                w.focused = true;
            }
        }
    }

    pub fn handle_tab_navigation(self: *Self, widgets: []Widget) void {
        if (raylib.IsKeyPressed(raylib.KEY_TAB)) {
            // Find focusable widgets
            var focusable_widgets = std.ArrayList(*Widget).init(self.allocator);
            defer focusable_widgets.deinit();

            for (widgets) |*widget| {
                if (widget.focusable and widget.visible) {
                    focusable_widgets.append(widget) catch continue;
                }
            }

            if (focusable_widgets.items.len == 0) return;

            // Find current focus index and move to next
            var next_index: usize = 0;
            if (self.focused_widget) |current| {
                for (focusable_widgets.items, 0..) |widget, i| {
                    if (widget == current) {
                        next_index = (i + 1) % focusable_widgets.items.len;
                        break;
                    }
                }
            }

            self.set_focus(focusable_widgets.items[next_index]);
        }
    }
};

// Example usage and helper functions
pub fn create_status_panel(rect: Rectangle, theme: *const Theme, title: []const u8) Panel {
    var panel = Panel.init(rect, theme);
    panel.title = title;
    panel.border = true;
    return panel;
}
