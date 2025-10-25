const std = @import("std");
const Game = @import("../game/game.zig");
const Window = @import("../game/window.zig");
const Types = @import("../common/types.zig");
const c = @cImport({
    @cInclude("raylib.h");
});
//TODO: how to make some lines / additional graphics?

pub const Element = struct {
    //TODO: add stuff like margin etc. will check in the future what is needed
    rect: c.Rectangle,
    color: c.Color,
    //TODO: filled: bool, full vs only lines
    data: ElementData,
    elements: std.ArrayList(*Element),

    pub fn init(allocator: std.mem.Allocator, rect: c.Rectangle, color: c.Color, data: ElementData) !*Element {
        const element = try allocator.create(Element);
        const elements = std.ArrayList(*Element).init(allocator);
        element.* = .{
            .rect = rect,
            .color = color,
            .data = data,
            .elements = elements,
        };

        return element;
    }

    pub fn initBar(allocator: std.mem.Allocator, rect: c.Rectangle, color: c.Color) !*Element {
        const element = try allocator.create(Element);
        const elements = std.ArrayList(*Element).init(allocator);
        element.* = .{
            .rect = rect,
            .color = color,
            .data = undefined,
            .elements = elements,
        };

        return element;
    }

    pub fn initBackground(allocator: std.mem.Allocator, rect: c.Rectangle, color: c.Color) !*Element {
        var element = try init(allocator, rect, color, undefined);
        element.data = ElementData{ .background = ElementBackgroundData{} };
        return element;
    }

    pub fn initText(allocator: std.mem.Allocator, rect: c.Rectangle, color: c.Color) !*Element {
        var element = try init(allocator, rect, color, undefined);
        element.data = ElementData{ .text = ElementTextData.init("Player", c.WHITE) };
        return element;
    }

    pub fn update(this: *Element, ctx: *Game.Context, rect: ?c.Rectangle) void {
        //TODO: make logic for extracting data from ctx
        if (rect) |r| {
            this.rect = r;
        }

        for (this.elements.items) |item| {
            item.update(ctx, null);
        }
    }

    pub fn draw(this: *Element) void {
        switch (this.data) {
            .background => {
                var rect = this.rect;
                rect.height = rect.height * Window.scale;
                rect.width = rect.width * Window.scale;
                c.DrawRectangleRec(rect, this.color);
            },
            .menu => {},
            .bar => {},
            .text => {
                c.DrawText(
                    this.data.text.text.ptr,
                    @intFromFloat(this.rect.x),
                    @intFromFloat(this.rect.y),
                    this.data.text.fontSize,
                    this.data.text.textColor,
                );
            },
        }

        for (this.elements.items) |item| {
            item.draw();
        }
    }
};

pub const ElementMenuData = struct {
    items: std.ArrayList(ElementMenuItem),
    index: u32,
};

pub const ElementBackgroundData = struct {};

pub const ElementBarData = struct {
    min: i32,
    max: i32,
    current: i32,
    //TODO: make a function for copying data from ctx  to bar, I guess make a function separate for each "version" of the bar, => hp, mp, tp, etc.
};

pub const ElementTextData = struct {
    text: []const u8,
    textColor: c.Color,
    fontSize: i32,

    pub fn init(text: []const u8, textColor: c.Color) ElementTextData {
        return ElementTextData{
            .text = text,
            .textColor = textColor,
            .fontSize = 20,
        };
    }
};

pub const ElementMenuItem = struct {
    text: []u8,
};

pub const ElementType = enum {
    menu,
    background,
    bar,
    text,
};

pub const ElementData = union(ElementType) {
    menu: ElementMenuData,
    background: ElementBackgroundData,
    bar: ElementBarData,
    text: ElementTextData,
};

pub const UiManager = struct {
    allocator: std.mem.Allocator,
    ctx: *Game.Context,
    elements: std.ArrayList(*Element),

    pub fn init(allocator: std.mem.Allocator, ctx: *Game.Context) !*UiManager {
        const uimanager = try allocator.create(UiManager);

        const elements = try makeUIElements(allocator);

        //TODO: make a deploy menu
        //const deployMenu = Element.init(allocator, c.Rectangle{ .x = 0, .y = 0, .width = 100, .height = 100 }, c.RED);

        uimanager.* = .{
            .allocator = allocator,
            .ctx = ctx,
            .elements = elements,
        };
        return uimanager;
    }
    pub fn update(this: *UiManager, ctx: *Game.Context) void {
        for (this.elements.items) |element| {
            element.update(ctx, null);
        }
    }
    pub fn draw(this: *UiManager) void {
        for (this.elements.items) |element| {
            element.draw();
        }
    }
};

pub fn makeUIElements(allocator: std.mem.Allocator) !std.ArrayList(*Element) {
    var elements = std.ArrayList(*Element).init(allocator);

    const playerPlate = try makeCharacterPlate(allocator, c.Vector2{ .x = 0, .y = 0 });
    try elements.append(playerPlate);

    const deployMenu = try makeChoiceMenu(allocator, c.Vector2{ .x = 0, .y = 0 });
    try elements.append(deployMenu);

    return elements;
}

pub fn makeCharacterPlate(allocator: std.mem.Allocator, pos: c.Vector2) !*Element {
    const plateRect = c.Rectangle{
        .x = pos.x,
        .y = pos.y,
        //TODO: what to do about width and height?
        .width = 200,
        .height = 150,
    };
    const characterPlate = try Element.initBackground(
        allocator,
        plateRect,
        c.BEIGE,
    );

    const textRect = c.Rectangle{
        .x = pos.x + 3,
        .y = pos.y + 5,
        //TODO: what to do about width and height?
        .width = 0,
        .height = 0,
    };
    const characterText = try Element.initText(allocator, textRect, c.Color{
        .r = 0,
        .g = 0,
        .b = 0,
        .a = 0,
    });
    try characterPlate.elements.append(characterText);

    //const hpBar = try Element.initBar(
    //allocator,
    //);

    return characterPlate;
}

pub fn makeChoiceMenu(allocator: std.mem.Allocator, pos: c.Vector2) !*Element {
    const plateRect = c.Rectangle{
        .x = pos.x,
        .y = pos.y,
        //TODO: what to do about width and height?
        .width = 200,
        .height = 150,
    };
    const characterPlate = try Element.initBackground(
        allocator,
        plateRect,
        c.BEIGE,
    );

    const textRect = c.Rectangle{
        .x = pos.x + 3,
        .y = pos.y + 5,
        //TODO: what to do about width and height?
        .width = 0,
        .height = 0,
    };
    const characterText = try Element.initText(allocator, textRect, c.Color{
        .r = 0,
        .g = 0,
        .b = 0,
        .a = 0,
    });
    try characterPlate.elements.append(characterText);

    //const hpBar = try Element.initBar(
    //allocator,
    //);

    return characterPlate;
}
