const std = @import("std");
const Game = @import("../game/game.zig");
const Window = @import("../game/window.zig");
const Types = @import("../common/types.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const Element = struct {
    rect: c.Rectangle,
    color: c.Color,
    data: ElementData,

    pub fn init(allocator: std.mem.Allocator, rect: c.Rectangle, color: c.Color) *Element {
        const element = allocator.create(Element);
        element.* = .{
            .rect = rect,
            .color = color,
            .data = undefined,
        };

        return element;
    }
};

pub const ElementMenuData = struct {
    items: std.ArrayList(ElementMenuItem),
    index: u32,
};

pub const ElementMenuItem = struct {
    text: []u8,
};

pub const ElementData = union(ElementType) {
    menu: ElementMenuData,
};

pub const ElementType = enum {
    menu,
};

pub const UiManager = struct {
    allocator: std.mem.Allocator,
    ctx: *Game.Context,
    elements: std.ArrayList(*Element),

    pub fn init(allocator: std.mem.Allocator, ctx: *Game.Context) !*UiManager {
        const uimanager = try allocator.create(UiManager);
        const elements = std.ArrayList(*Element);



        const deployMenu = Element.init(allocator, , color: c.Color)
        elements.append();

        uimanager.* = .{
            .allocator = allocator,
            .ctx = ctx,
        };
        return uimanager;
    }
    pub fn update(this: *UiManager, ctx: *Game.Context) void {
        _ = this;
        _ = ctx;
    }
    pub fn draw(this: *UiManager) void {
        _ = this;
        const rectHeight = Window.windowHeight;
        const rectWidth = @divFloor(Window.windowWidth, 10);

        //_ = rectHeight;
        //_ = rectWidth;
        c.DrawRectangle(0, 0, rectWidth, rectHeight, c.ORANGE);
    }
};
