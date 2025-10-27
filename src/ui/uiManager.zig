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
    visible: bool,
    rect: c.Rectangle,
    color: c.Color,
    //TODO: filled: bool, full vs only lines
    data: ElementData,
    elements: std.ArrayList(*Element),

    pub fn init(allocator: std.mem.Allocator, rect: c.Rectangle, color: c.Color, data: ElementData) !*Element {
        const element = try allocator.create(Element);
        const elements = std.ArrayList(*Element).init(allocator);
        element.* = .{
            .visible = true,
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
            .visible = true,
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

    pub fn initMenu(allocator: std.mem.Allocator, rect: c.Rectangle, color: c.Color) !*Element {
        var element = try init(allocator, rect, color, undefined);
        element.data = ElementData{ .menu = ElementMenuData{
            .items = std.ArrayList(ElementMenuItem).init(allocator),
            .index = 0,
            .type = .puppet_select,
        } };

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
        if (!this.visible) {
            return;
        }

        switch (this.data) {
            .background => {
                var rect = this.rect;
                rect.height = rect.height * Window.scale;
                rect.width = rect.width * Window.scale;
                c.DrawRectangleRec(rect, this.color);
            },
            .menu => {
                //TODO: @finish
                for (this.data.menu.items) |item| {
                    c.DrawText(
                        item.text.ptr,
                        @intFromFloat(this.rect.x),
                        @intFromFloat(this.rect.y),
                        this.data.text.fontSize,
                        this.data.text.textColor,
                    );
                }
            },
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

pub const ElementData = union(ElementType) {
    menu: ElementMenuData,
    background: ElementBackgroundData,
    bar: ElementBarData,
    text: ElementTextData,
};

pub const ElementMenuData = struct {
    items: std.ArrayList(ElementMenuItem),
    index: u32,
    type: MenuType,
};

//TODO: no idea if I should do it this way, maybe just use the commandType???
// its 1:1 anyway
pub const MenuType = enum {
    puppet_select,
    action_select,
    skill_select,
    item_select,
};

pub const ElementMenuItem = struct {
    text: []u8,
    fontSize: i32,
    textColor: c.Color,
    enabled: bool,
    data: MenuItemData,
};

pub const MenuItemData = union(enum) {
    puppet_id: usize,
    action: ActionType,
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

pub const ElementType = enum {
    menu,
    background,
    bar,
    text,
};

pub const ActionType = enum {
    move,
    attack,
};

pub const Command = struct {
    type: CommandType,
    data: CommandData,
};

pub const CommandType = enum {
    none,
    select_puppet,
    select_action,
};

pub const CommandData = union(CommandType) {
    none: void,
    select_puppet: usize,
    select_action: ActionType,
};

pub const UiManager = struct {
    allocator: std.mem.Allocator,
    elements: std.ArrayList(*Element),
    commands: std.ArrayList(Command),
    //TODO: pointer to active element or have active value in elements?
    //accessing certain elements that are needed, maybe do this in another way?
    deployMenu: *Element,

    pub fn init(allocator: std.mem.Allocator) !*UiManager {
        const uimanager = try allocator.create(UiManager);

        const elements = try uimanager.makeUIElements(allocator);
        const commands = std.ArrayList(Command).init(allocator);

        //TODO: make a deploy menu
        //const deployMenu = Element.init(allocator, c.Rectangle{ .x = 0, .y = 0, .width = 100, .height = 100 }, c.RED);

        uimanager.* = .{
            .allocator = allocator,
            .elements = elements,
            .commands = commands,
            .deployMenu = uimanager.deployMenu,
        };
        return uimanager;
    }

    pub fn update(this: *UiManager, ctx: *Game.Context) void {
        //TODO: @continue add items into menu based on the context
        for (this.elements.items) |element| {
            element.update(ctx, null);
        }
    }

    pub fn draw(this: *UiManager) void {
        for (this.elements.items) |element| {
            element.draw();
        }
    }

    pub fn push(this: *UiManager, command: Command) !void {
        try this.commands.append(command);
    }

    pub fn pop(this: *UiManager) ?Command {
        if (this.commands.items.len < 1) {
            return null;
        }
        const command = this.commands.orderedRemove(0);
        return command;
    }

    pub fn hasCommands(this: *UiManager) bool {
        return (this.commands.items.len > 0);
    }

    pub fn makeUIElements(this: *UiManager, allocator: std.mem.Allocator) !std.ArrayList(*Element) {
        var elements = std.ArrayList(*Element).init(allocator);

        const playerPlate = try makeCharacterPlate(allocator, c.Vector2{ .x = 0, .y = 0 });
        try elements.append(playerPlate);

        const deployMenu = try makeChoiceMenu(allocator, c.Vector2{ .x = 500, .y = 500 });
        try elements.append(deployMenu);
        this.deployMenu = deployMenu;

        return elements;
    }
};

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
    const menuRect = c.Rectangle{
        .x = pos.x,
        .y = pos.y,
        //TODO: what to do about width and height?
        .width = 200,
        .height = 150,
    };
    const menuBackground = try Element.initBackground(
        allocator,
        menuRect,
        c.BLUE,
    );

    const menu = try Element.initMenu(
        allocator,
        menuRect,
        c.BLUE,
        "Select a Puppet:",
    );

    try menuBackground.elements.append(menu);

    return menuBackground;
}
