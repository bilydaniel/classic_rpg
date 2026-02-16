const std = @import("std");
const Game = @import("../game/game.zig");
const TurnManager = @import("../game/turnManager.zig");
const Window = @import("../game/window.zig");
const Gamestate = @import("../game/gamestate.zig");
const Types = @import("../common/types.zig");
const InputManager = @import("../game/inputManager.zig");
const EntityManager = @import("../game/entityManager.zig");
const Config = @import("../common/config.zig");
const Utils = @import("../common/utils.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

//TODO: how do I do some special shapes / effects for design?
// maybe attach them to an element or have them separate?
//
// TODO: switch to immeadeate mode ui watch caseys video
pub const Updatefunction = *const fn (*Element, *Game.Game) anyerror!void;

pub var uiCommand: UiCommand = undefined;

var allocator: std.mem.Allocator = undefined;
var elements: std.ArrayList(Element) = undefined;
var menus: std.AutoHashMap(MenuType, i32) = undefined; //element id
var activeMenu: ?i32 = null;
var elementGroupID: i32 = 0;
var nextElementID: i32 = 0;

pub fn init(alloc: std.mem.Allocator) !void {
    allocator = alloc;
    elements = std.ArrayList(Element).init(allocator);
    menus = std.AutoHashMap(MenuType, i32).init(allocator);

    try makeUIElements();
}

pub fn update(game: *Game.Game) !void {
    uiCommand = UiCommand{};
    if (TurnManager.turn != .player) {
        return;
    }
    if (Gamestate.showMenu == .none) {
        if (activeMenu != null) {
            const menuElement = getElementByID(activeMenu.?);
            if (menuElement) |menu| {
                hideElementGroup(menu.groupID);
                activeMenu = null;
            }
        }
    } else {
        if (activeMenu == null) {
            const menuID = menus.get(Gamestate.showMenu);
            if (menuID) |menuid| {
                const menuElement = getElementByID(menuid);
                if (menuElement) |_menu| {
                    showElementGroup(_menu.groupID);
                    activeMenu = menuid;
                }
            }
        }
    }

    for (elements.items) |*element| {
        try element.update(game);
    }

    //confirm
    var confirm = InputManager.takeConfirmInput();

    //cancel
    const cancel = InputManager.takeCancelInput();

    //move
    const move = InputManager.takePositionInput();

    //menu select
    if (move) |_move| {
        updateActiveMenu(_move);
    }

    var menuSelect: ?MenuItemData = null;
    if (confirm) {
        menuSelect = getSelectedItem();
        if (menuSelect != null) {
            confirm = false;
        }
    }

    //quick select
    const quickSelect = InputManager.takeQuickSelectInput();

    //combat toggle
    const combatToggle = InputManager.takeCombatToggle();

    const skip = InputManager.takeSkipInput();

    const uicommand = UiCommand{
        .confirm = confirm,
        .cancel = cancel,
        .move = move,
        .menuSelect = menuSelect,
        .quickSelect = quickSelect,
        .combatToggle = combatToggle,
        .skip = skip,
    };
    uiCommand = uicommand;
}

pub fn draw() !void {
    for (elements.items) |*element| {
        element.draw();
    }

    //var buffer: [64:0]u8 = undefined;
    //const text = try std.fmt.bufPrintZ(&buffer, "Turn: {}", .{Gamestate.turnNumber});

    //c.DrawText(text.ptr, Config.window_width - 200, 10, 15, c.RED);
}

pub fn makeUIElements() !void {
    const playerPlatePos = RelativePos.init(.top_left, 10, 30);
    const playerPlateSize = c.Vector2{ .x = 200, .y = 150 };
    _ = try makeCharacterPlate(playerPlatePos, playerPlateSize);

    const deployMenuPos = RelativePos.init(.bottom_center, 0, 0);
    const deployMenuSize = c.Vector2{ .x = 200, .y = 150 };
    const deployMenuID = try makeChoiceMenu(deployMenuPos, deployMenuSize, "Pick a Puppet:", MenuType.puppet_select, updatePuppetMenu);
    hideElementGroup(deployMenuID);

    const actionMenuPos = RelativePos.init(.bottom_center, 0, 0);
    const actionMenuSize = c.Vector2{ .x = 200, .y = 150 };
    const actionMenuID = try makeChoiceMenu(actionMenuPos, actionMenuSize, "Pick an Action:", MenuType.action_select, updateActionMenu);
    hideElementGroup(actionMenuID);

    const turnNumberPos = RelativePos.init(.top_right, 0, 0);
    const turnNumberSize = c.Vector2{ .x = 100, .y = 100 };

    const turnElementID = try makeText(turnNumberPos, turnNumberSize, "Turn:");
    const turnElement = getElementByID(turnElementID);
    if (turnElement) |element| {
        element.updateFn = updateTurnNumberText;
    }

    const currentTurnPos = RelativePos.init(.top_right, 0, 100);
    const currentTurnSize = c.Vector2{ .x = 100, .y = 100 };

    const currentTurnID = try makeText(currentTurnPos, currentTurnSize, "");
    const currentTurnElement = getElementByID(currentTurnID);
    if (currentTurnElement) |element| {
        element.updateFn = updateCurrentTurnText;
    }

    const combatIndicatorPos = RelativePos.init(.top_right, 0, 150);
    const combatIndicatorSize = c.Vector2{ .x = 100, .y = 100 };

    const combatIndicatorID = try makeText(combatIndicatorPos, combatIndicatorSize, "");
    const combatIndicatorElement = getElementByID(combatIndicatorID);
    if (combatIndicatorElement) |element| {
        element.updateFn = updateCombatIndicatorText;
    }
}

pub fn hideElementGroup(id: i32) void {
    for (elements.items) |*element| {
        if (element.groupID == id) {
            element.visible = false;
        }
    }
}

pub fn showElementGroup(id: i32) void {
    for (elements.items) |*element| {
        if (element.groupID == id) {
            element.visible = true;
        }
    }
}

pub fn updateActiveMenu(move: Types.Vector2Int) void {
    if (activeMenu) |active_menu| {
        const activeElement = getElementByID(active_menu) orelse return;
        var menuData = &activeElement.data.menu;
        const itemCount = @as(u32, @intCast(menuData.menuItems.items.len));
        var index = menuData.index;
        if (itemCount == 0) {
            return;
        }

        if (move.y == -1) {
            if (index <= 0) {
                index = itemCount - 1;
            } else {
                index -= 1;
            }
        } else if (move.y == 1) {
            if (index >= itemCount - 1) {
                index = 0;
            } else {
                index += 1;
            }
        }
        menuData.index = index;
    }
}

pub fn getSelectedItem() ?MenuItemData {
    if (activeMenu) |active_menu| {
        const activeElement = getElementByID(active_menu) orelse return null;

        const menu = activeElement.data.menu;
        if (menu.menuItems.items.len > 0) {
            return menu.menuItems.items[menu.index].data;
        }
    }
    return null;
}

pub fn resetActiveMenuIndex() void {
    if (activeMenu) |active_menu| {
        const activeElement = getElementByID(active_menu) orelse return;
        activeElement.data.menu.index = 0;
    }
}

fn getElementByID(id: i32) ?*Element {
    for (elements.items) |*element| {
        if (element.id == id) {
            return element;
        }
    }
    return null;
}

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
    pos: c.Vector2,

    pub fn init(anchor: AnchorEnum, x: f32, y: f32) RelativePos {
        return RelativePos{
            .anchor = anchor,
            .pos = c.Vector2{
                .x = x,
                .y = y,
            },
        };
    }
};

fn getScaledSize(size: c.Vector2) c.Vector2 {
    return Utils.vector2Scale(size, Window.scale);
}

fn relativeToScreenPos(rPos: RelativePos, size: c.Vector2) c.Vector2 {
    const anchorPosition = getAnchorPosition(rPos.anchor);
    const position = Utils.vector2Scale(rPos.pos, Window.scale);
    var result = Utils.vector2Add(anchorPosition, position);

    //Adjust for element size based on anchor
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

fn getAnchorPosition(anchor: AnchorEnum) c.Vector2 {
    return switch (anchor) {
        .top_left => c.Vector2{ .x = 0, .y = 0 },
        .top_center => c.Vector2{ .x = Window.scaledWidthHalf, .y = 0 },
        .top_right => c.Vector2{ .x = @floatFromInt(Window.scaledWidth), .y = 0 },
        .center_left => c.Vector2{ .x = 0, .y = Window.scaledHeightHalf },
        .center => c.Vector2{ .x = Window.scaledWidthHalf, .y = Window.scaledHeightHalf },
        .center_right => c.Vector2{ .x = @floatFromInt(Window.scaledWidth), .y = Window.scaledHeightHalf },
        .bottom_left => c.Vector2{ .x = 0, .y = @floatFromInt(Window.scaledHeight) },
        .bottom_center => c.Vector2{ .x = Window.scaledWidthHalf, .y = @floatFromInt(Window.scaledHeight) },
        .bottom_right => c.Vector2{ .x = @floatFromInt(Window.scaledWidth), .y = @floatFromInt(Window.scaledHeight) },
    };
}

pub const Element = struct {
    id: i32,
    visible: bool,
    relPos: RelativePos,
    size: c.Vector2,
    data: ElementData,
    updateFn: ?Updatefunction = null,
    groupID: i32 = undefined,

    pub fn init(resPos: RelativePos, size: c.Vector2, data: ElementData) Element {
        const element = Element{
            .id = nextElementID,
            .visible = true,
            .relPos = resPos,
            .size = size,
            .data = data,
            .groupID = elementGroupID,
        };
        nextElementID += 1;

        return element;
    }

    pub fn initBar(resPos: RelativePos, size: c.Vector2, data: ElementData) !*Element {
        const element = Element{
            .visible = true,
            .relPos = resPos,
            .size = size,
            .data = data,
        };

        return element;
    }

    pub fn initBackground(resPos: RelativePos, size: c.Vector2, color: c.Color) Element {
        var element = Element.init(resPos, size, undefined);
        element.data = ElementData{ .background = ElementBackgroundData{ .color = color } };
        return element;
    }

    pub fn initText(resPos: RelativePos, size: c.Vector2, text: []const u8) Element {
        var element = Element.init(resPos, size, undefined);
        element.data = ElementData{ .text = ElementTextData.init(text, c.WHITE) };
        return element;
    }

    pub fn initMenu(resPos: RelativePos, size: c.Vector2, updateFunction: Updatefunction) Element {
        var element = Element.init(resPos, size, undefined);

        element.updateFn = updateFunction;

        element.data = ElementData{ .menu = ElementMenuData{
            .menuItems = std.ArrayList(ElementMenuItem).init(allocator),
            .index = 0,
            .type = .puppet_select,
        } };

        return element;
    }

    pub fn update(this: *Element, game: *Game.Game) !void {
        if (this.updateFn) |_fn| {
            try _fn(this, game);
        }
    }

    pub fn draw(this: *Element) void {
        if (!this.visible) {
            return;
        }

        switch (this.data) {
            .background => {
                const size = getScaledSize(this.size);
                const position = relativeToScreenPos(this.relPos, size);

                c.DrawRectangle(@intFromFloat(position.x), @intFromFloat(position.y), @intFromFloat(size.x), @intFromFloat(size.y), c.ORANGE);
            },
            .menu => {
                //TODO: @finish

                const size = getScaledSize(this.size);
                const position = relativeToScreenPos(this.relPos, size);

                var x = position.x;
                var y = position.y;
                for (this.data.menu.menuItems.items, 0..) |*item, i| {
                    var text_color = this.data.menu.textColor;
                    if (this.data.menu.index == i) {
                        text_color = this.data.menu.pickedTextColor;
                        //std.mem.copyForwards(const u8, item.text[2..], item.text);
                        //TODO: @continue @finish add some arrows to the item being picked
                    }

                    c.DrawText(
                        item.text.ptr,
                        @intFromFloat(x),
                        @intFromFloat(y),
                        this.data.menu.fontSize,
                        text_color,
                    );
                    x += 0;
                    y += 20;
                }
            },
            .bar => {},
            .text => {
                const size = getScaledSize(this.size);
                const position = relativeToScreenPos(this.relPos, size);
                const fontSize = @as(c_int, @intFromFloat(@as(f32, @floatFromInt(this.data.text.fontSize)) * Window.scale));

                c.DrawText(
                    &this.data.text.text,
                    @intFromFloat(position.x),
                    @intFromFloat(position.y),
                    fontSize,
                    this.data.text.textColor,
                );
            },
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
    menuItems: std.ArrayList(ElementMenuItem),
    index: u32,
    type: MenuType,
    fontSize: i32 = 20,
    textColor: c.Color = c.YELLOW,
    pickedTextColor: c.Color = c.RED,
};

//TODO: no idea if I should do it this way, maybe just use the commandType???
// its 1:1 anyway
pub const MenuType = enum {
    none,
    puppet_select,
    action_select,
    skill_select,
    item_select,
};

pub const ElementMenuItem = struct {
    text: []const u8,
    fontSize: i32 = 10,
    textColor: c.Color = c.BLACK,
    enabled: bool = true,
    data: MenuItemData,

    pub fn initPupItem(text: []const u8, puppet_id: u32) ElementMenuItem {
        const elementData = MenuItemData{ .puppet_id = puppet_id };
        return ElementMenuItem{
            .text = text,
            .data = elementData,
        };
    }

    pub fn initActionItem(text: []const u8, action: ActionType) ElementMenuItem {
        const elementData = MenuItemData{ .action = action };
        return ElementMenuItem{
            .text = text,
            .data = elementData,
        };
    }
};

pub const MenuItemData = union(enum) {
    puppet_id: u32,
    action: ActionType,
};

pub const ElementBackgroundData = struct {
    color: c.Color,
};

pub const ElementBarData = struct {
    min: i32,
    max: i32,
    current: i32,
    //TODO: make a function for copying data from ctx  to bar, I guess make a function separate for each "version" of the bar, => hp, mp, tp, etc.
};

pub const ElementTextData = struct {
    text: [64:0]u8 = undefined,
    textColor: c.Color,
    fontSize: i32,

    pub fn init(text: []const u8, textColor: c.Color) ElementTextData {
        var textBuffer: [64:0]u8 = undefined;
        @memcpy(textBuffer[0..text.len], text);
        textBuffer[text.len] = 0;
        return ElementTextData{
            .text = textBuffer,
            .textColor = textColor,
            .fontSize = 25,
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

const MenuError = error{};

pub const UiCommand = struct {
    confirm: bool = false,
    cancel: bool = false,
    move: ?Types.Vector2Int = null,
    menuSelect: ?MenuItemData = null,
    quickSelect: ?u8 = null,
    combatToggle: bool = false,
    skip: bool = false,
};

pub fn getConfirm() bool {
    const confirm = uiCommand.confirm;
    uiCommand.confirm = false;
    return confirm;
}

pub fn getCancel() bool {
    const cancel = uiCommand.cancel;
    uiCommand.cancel = false;
    return cancel;
}

pub fn getMove() ?Types.Vector2Int {
    const move = uiCommand.move;
    uiCommand.move = null;
    return move;
}

pub fn getSkip() bool {
    const skip = uiCommand.skip;
    uiCommand.skip = false;
    return skip;
}

pub fn getMenuSelect() ?MenuItemData {
    const item = uiCommand.menuSelect;
    uiCommand.menuSelect = null;
    return item;
}

pub fn getQuickSelect() ?u8 {
    const item = uiCommand.quickSelect;
    uiCommand.quickSelect = null;
    return item;
}

pub fn getCombatToggle() bool {
    const combat = uiCommand.combatToggle;
    uiCommand.combatToggle = false;
    return combat;
}

pub fn makeCharacterPlate(relPos: RelativePos, size: c.Vector2) !i32 {
    var relativePosition = relPos;
    const background = Element.initBackground(
        relativePosition,
        size,
        c.BEIGE,
    );

    relativePosition.pos.x += 3;
    relativePosition.pos.y += 5;
    const text = Element.initText(relativePosition, size, "Player");

    try elements.append(background);
    try elements.append(text);
    elementGroupID += 1;
    return background.groupID;
}

pub fn makeChoiceMenu(relPos: RelativePos, size: c.Vector2, title: []const u8, menuType: MenuType, updateFunction: Updatefunction) !i32 {
    var relativePosition = relPos;

    const background = Element.initBackground(relativePosition, size, c.BLUE);

    relativePosition.pos.x += 3;
    relativePosition.pos.y += 5;

    const titleElement = Element.initText(relativePosition, size, title);

    relativePosition.pos.x += 3;
    relativePosition.pos.y += 30;

    const menu = Element.initMenu(relativePosition, size, updateFunction);
    try menus.put(menuType, menu.id);

    try elements.append(background);
    try elements.append(titleElement);
    try elements.append(menu);
    elementGroupID += 1;
    return background.groupID;
}

pub fn makeText(relPos: RelativePos, size: c.Vector2, text: []const u8) !i32 {
    //TODO: maybe add some backgrround?
    const relativePosition = relPos;
    const textElement = Element.initText(relativePosition, size, text);
    try elements.append(textElement);
    elementGroupID += 1;
    return textElement.id;
}

pub fn updatePuppetMenu(this: *Element, game: *Game.Game) anyerror!void {
    //TODO: update every frame for now, probably can make it better
    this.data.menu.menuItems.clearRetainingCapacity();

    //TODO: this is ridicolous, maybe make a getter or something?
    for (game.player.data.player.puppets.items) |pupID| {
        //TODO: @continue @finish
        const puppet = EntityManager.getInactiveEntityID(pupID);
        if (puppet) |pup| {
            const item = ElementMenuItem.initPupItem(pup.name, pup.id);
            try this.data.menu.menuItems.append(item);
        }
    }
}

pub fn updateActionMenu(this: *Element, game: *Game.Game) anyerror!void {
    _ = game;
    this.data.menu.menuItems.clearRetainingCapacity();

    if (Gamestate.selectedEntity) |selected_entity| {
        if (!selected_entity.hasMoved) {
            const itemMove = ElementMenuItem.initActionItem("MOVE", ActionType.move);
            try this.data.menu.menuItems.append(itemMove);
        }

        if (!selected_entity.hasAttacked) {
            const itemAttack = ElementMenuItem.initActionItem("ATTACK", ActionType.attack);
            try this.data.menu.menuItems.append(itemAttack);
        }
    }
}

pub fn updateTurnNumberText(this: *Element, game: *Game.Game) anyerror!void {
    _ = game;

    _ = try std.fmt.bufPrintZ(&this.data.text.text, "Turn: {}", .{TurnManager.turnNumber});
}

pub fn updateCurrentTurnText(this: *Element, game: *Game.Game) anyerror!void {
    _ = game;

    if (TurnManager.turn == .player) {
        _ = try std.fmt.bufPrintZ(&this.data.text.text, "{s}", .{"Player"});
    } else if (TurnManager.turn == .enemy) {
        _ = try std.fmt.bufPrintZ(&this.data.text.text, "{s}", .{"Enemy"});
    }
}

pub fn updateCombatIndicatorText(this: *Element, game: *Game.Game) anyerror!void {
    _ = game;
    const player = EntityManager.getPlayer();

    if (player.inCombat) {
        _ = try std.fmt.bufPrintZ(&this.data.text.text, "{s}", .{"Combat..."});
    } else {
        _ = try std.fmt.bufPrintZ(&this.data.text.text, "{s}", .{"Exploring..."});
    }
}
