const std = @import("std");
const Game = @import("../game/game.zig");
const Window = @import("../game/window.zig");
const Gamestate = @import("../game/gamestate.zig");
const Types = @import("../common/types.zig");
const InputManager = @import("../game/inputManager.zig");
const EntityManager = @import("../game/entityManager.zig");
const c = @cImport({
    @cInclude("raylib.h");
});
//TODO: REWRITE ALL OF THIS

//TODO: how to make some lines / additional graphics?
pub const Updatefunction = *const fn (*Element, *Game.Game) MenuError!void;

//TODO: @finish
pub var uiCommand: UiCommand = undefined;

pub const Element = struct {
    //TODO: add stuff like margin etc. will check in the future what is needed
    visible: bool,
    rect: c.Rectangle,
    color: c.Color,
    //TODO: filled: bool, full vs only lines
    elements: std.ArrayList(*Element),
    data: ElementData,
    updateFn: ?Updatefunction = null,

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

    pub fn initText(allocator: std.mem.Allocator, rect: c.Rectangle, text: []const u8, color: c.Color) !*Element {
        var element = try init(allocator, rect, color, undefined);
        element.data = ElementData{ .text = ElementTextData.init(text, c.WHITE) };
        return element;
    }

    pub fn initMenu(allocator: std.mem.Allocator, rect: c.Rectangle, color: c.Color, updateFunction: Updatefunction) !*Element {
        var element = try init(allocator, rect, color, undefined);

        element.updateFn = updateFunction;

        element.data = ElementData{ .menu = ElementMenuData{
            .menuItems = std.ArrayList(ElementMenuItem).init(allocator),
            .index = 0,
            .type = .puppet_select,
        } };

        return element;
    }

    pub fn getChild(this: *Element, elementType: ElementType) ?*Element {
        for (this.elements.items) |element| {
            if (element.data == elementType) {
                return element;
            }
        }
        return null;
    }

    pub fn update(this: *Element, game: *Game.Game, rect: ?c.Rectangle) !void {
        if (this.updateFn) |_fn| {
            try _fn(this, game);
        }
        //TODO: make logic for extracting data from ctx
        if (rect) |r| {
            this.rect = r;
        }

        for (this.elements.items) |item| {
            try item.update(game, null);
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
                var x = this.rect.x;
                var y = this.rect.y;
                for (this.data.menu.menuItems.items, 0..) |item, i| {
                    var text_color = this.data.menu.textColor;
                    if (this.data.menu.index == i) {
                        text_color = this.data.menu.pickedTextColor;
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

    //TODO: @continue @finish

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

const MenuError = error{OutOfMemory};

pub const UiCommand = struct {
    confirm: bool = false,
    cancel: bool = false,
    move: ?Types.Vector2Int = null,
    menuSelect: ?MenuItemData = null,
    quickSelect: ?u8 = null,
    combatToggle: bool = false,

    pub fn getConfirm(this: *UiCommand) bool {
        const confirm = this.confirm;
        this.confirm = false;
        return confirm;
    }

    pub fn getCancel(this: *UiCommand) bool {
        const cancel = this.cancel;
        this.cancel = false;
        return cancel;
    }

    pub fn getMove(this: *UiCommand) ?Types.Vector2Int {
        const move = this.move;
        this.move = null;
        return move;
    }

    pub fn getMenuSelect(this: *UiCommand) ?MenuItemData {
        const item = this.menuSelect;
        this.menuSelect = null;
        return item;
    }

    pub fn getQuickSelect(this: *UiCommand) ?u8 {
        const item = this.quickSelect;
        this.quickSelect = null;
        return item;
    }

    pub fn getCombatToggle(this: *UiCommand) bool {
        const combat = this.combatToggle;
        this.combatToggle = false;
        return combat;
    }
};

pub const UiManager = struct {
    allocator: std.mem.Allocator,
    elements: std.ArrayList(*Element),
    commands: std.ArrayList(Command),
    //TODO: pointer to active element or have active value in elements?
    //accessing certain elements that are needed, maybe do this in another way?
    menus: std.AutoHashMap(MenuType, *Element),
    deployMenu: *Element,
    actionMenu: *Element,
    activeMenu: ?*Element = null,

    pub fn init(allocator: std.mem.Allocator) !*UiManager {
        const uimanager = try allocator.create(UiManager);

        const menus = std.AutoHashMap(MenuType, *Element).init(allocator);
        uimanager.menus = menus;

        const elements = try uimanager.makeUIElements(allocator);
        const commands = std.ArrayList(Command).init(allocator);

        //TODO: make a deploy menu
        //const deployMenu = Element.init(allocator, c.Rectangle{ .x = 0, .y = 0, .width = 100, .height = 100 }, c.RED);

        uimanager.* = .{
            .allocator = allocator,
            .elements = elements,
            .commands = commands,
            .deployMenu = uimanager.deployMenu,
            .actionMenu = uimanager.actionMenu,
            .menus = uimanager.menus,
        };
        return uimanager;
    }

    pub fn update(this: *UiManager, game: *Game.Game) !void {
        uiCommand = UiCommand{};
        if (Gamestate.currentTurn != .player) {
            return;
        }
        if (Gamestate.showMenu == .none) {
            if (this.activeMenu != null) {
                this.activeMenu.?.visible = false;
                this.activeMenu = null;
            }
        } else {
            if (this.activeMenu == null) {
                this.activeMenu = this.menus.get(Gamestate.showMenu);
                this.activeMenu.?.visible = true;
            }
        }
        //
        // if (ctx.gamestate.showPupDeployMenu) {
        //     //this.showDeployMenu();
        // } else {
        //     //this.hideDeployMenu();
        //     //TODO: @continue cant just put it to null, bug with action menu
        // }
        //
        // if (ctx.gamestate.showActionMenu) {
        //     //this.showActionMenu();
        // } else {
        //     //this.hideActionMenu();
        // }

        //TODO: @continue add items into menu based on the context
        for (this.elements.items) |element| {
            try element.update(game, null);
        }

        //confirm
        var confirm = InputManager.takeConfirmInput();

        //cancel
        const cancel = InputManager.takeCancelInput();

        //move
        const move = InputManager.takePositionInput();

        //menu select
        if (move) |_move| {
            this.updateActiveMenu(_move);
        }

        var menuSelect: ?MenuItemData = null;
        if (confirm) {
            menuSelect = this.getSelectedItem();
            if (menuSelect != null) {
                confirm = false;
            }
        }

        //quick select
        const quickSelect = InputManager.takeQuickSelectInput();

        //combat toggle
        const combatToggle = InputManager.takeCombatToggle();

        const uicommand = UiCommand{
            .confirm = confirm,
            .cancel = cancel,
            .move = move,
            .menuSelect = menuSelect,
            .quickSelect = quickSelect,
            .combatToggle = combatToggle,
        };
        uiCommand = uicommand;
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

        const deployMenu = try makeChoiceMenu(allocator, c.Vector2{ .x = 500, .y = 500 }, "Pick a Puppet:", updatePuppetMenu);
        deployMenu.visible = false;
        try elements.append(deployMenu);
        this.deployMenu = deployMenu;

        const actionMenu = try makeChoiceMenu(allocator, c.Vector2{ .x = 500, .y = 500 }, "Pick Action:", updateActionMenu);
        actionMenu.visible = false;
        try elements.append(actionMenu);
        this.actionMenu = actionMenu;

        try this.menus.put(.puppet_select, deployMenu);
        try this.menus.put(.action_select, actionMenu);

        return elements;
    }

    pub fn showDeployMenu(this: *UiManager) void {
        this.deployMenu.visible = true;
        this.activeMenu = this.deployMenu;
    }

    pub fn hideDeployMenu(this: *UiManager) void {
        this.deployMenu.visible = false;
        this.activeMenu = null;
    }

    pub fn updateActiveMenu(this: *UiManager, move: Types.Vector2Int) void {
        var menuData: ?*ElementMenuData = null;

        if (this.activeMenu) |active_menu| {
            const menu = active_menu.getChild(.menu);
            if (menu) |_menu| {
                menuData = &_menu.data.menu;
            }

            if (menuData) |menu_data| {
                const itemCount = @as(u32, @intCast(menu_data.menuItems.items.len));
                var index = menu_data.index;
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
                menu_data.index = index;
            }
        }
    }

    pub fn showActionMenu(this: *UiManager) void {
        this.actionMenu.visible = true;
        this.activeMenu = this.actionMenu;
    }

    pub fn hideActionMenu(this: *UiManager) void {
        this.actionMenu.visible = false;
        this.activeMenu = null;
    }

    pub fn getSelectedItem(this: *UiManager) ?MenuItemData {
        if (this.activeMenu) |active_menu| {
            const menu = active_menu.getChild(.menu);
            if (menu) |_menu| {
                const menuData = &_menu.data.menu;
                if (menuData.menuItems.items.len > 0) {
                    return menuData.menuItems.items[menuData.index].data;
                }
            }
        }
        return null;
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
    const characterText = try Element.initText(allocator, textRect, "Player", c.Color{
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

pub fn makeChoiceMenu(allocator: std.mem.Allocator, pos: c.Vector2, title: []const u8, updateFunction: Updatefunction) !*Element {
    const backgroundRect = c.Rectangle{
        .x = pos.x,
        .y = pos.y,
        //TODO: what to do about width and height?
        .width = 200,
        .height = 150,
    };
    const menuBackground = try Element.initBackground(
        allocator,
        backgroundRect,
        c.BLUE,
    );

    const titleRect = c.Rectangle{
        .x = pos.x + 3,
        .y = pos.y + 5,
        .width = 0,
        .height = 0,
    };

    //TODO: title
    const menuTitle = try Element.initText(allocator, titleRect, title, c.WHITE);
    try menuBackground.elements.append(menuTitle);

    //TODO: figure out the offsets, probably based on fontsize??? not really clue how it works
    const menuRect = c.Rectangle{
        .x = pos.x + 3,
        .y = pos.y + 30,
        .width = 0,
        .height = 0,
    };

    const menu = try Element.initMenu(
        allocator,
        menuRect,
        c.BLUE,
        updateFunction,
    );
    try menuBackground.elements.append(menu);

    return menuBackground;
}

pub fn updatePuppetMenu(this: *Element, game: *Game.Game) MenuError!void {
    //TODO: update every frame for now, probably can make it better
    this.data.menu.menuItems.clearRetainingCapacity();

    //TODO: this is ridicolous, maybe make a getter or something?
    for (game.player.data.player.puppets.items) |pupID| {
        const puppet = EntityManager.getEntityID(pupID);
        if (puppet) |pup| {
            if (!pup.data.puppet.deployed) {
                const item = ElementMenuItem.initPupItem(pup.name, pup.id);
                try this.data.menu.menuItems.append(item);
            }
        }
    }
}

pub fn updateActionMenu(this: *Element, game: *Game.Game) MenuError!void {
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
