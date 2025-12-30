// ============================================================================
// KEY CHANGES SUMMARY:
// ============================================================================
// 1. Added Anchor enum (9 anchor points: corners, edges, center)
// 2. Added RelativePosition struct (anchor + offset)
// 3. Element now uses: position (RelativePosition) + size (Vector2)
//    instead of: rect (Rectangle)
// 4. All drawing scales with Window.scale
// 5. Font sizes scale automatically
// ============================================================================

const std = @import("std");
const Game = @import("../game/game.zig");
const Window = @import("../game/window.zig");
const Gamestate = @import("../game/gamestate.zig");
const Types = @import("../common/types.zig");
const InputManager = @import("../game/inputManager.zig");
const EntityManager = @import("../game/entityManager.zig");
const Config = @import("../common/config.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const Updatefunction = *const fn (*Element, *Game.Game) MenuError!void;

pub var uiCommand: UiCommand = undefined;

var allocator: std.mem.Allocator = undefined;
var elements: std.ArrayList(Element) = undefined;
var menus: std.AutoHashMap(MenuType, *Element) = undefined;
var deployMenu: *Element = undefined;
var actionMenu: *Element = undefined;
var activeMenu: ?*Element = null;

// ============================================================================
// NEW: ANCHOR SYSTEM
// ============================================================================

// Anchor system for UI positioning
pub const Anchor = enum {
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

// Position relative to anchor
pub const RelativePosition = struct {
    anchor: Anchor,
    offset_x: f32, // Offset in game units (not pixels)
    offset_y: f32,

    pub fn toScreenPosition(self: RelativePosition, element_width: f32, element_height: f32) c.Vector2 {
        const base = getAnchorPosition(self.anchor);

        // Apply offset in scaled coordinates
        var x = base.x + (self.offset_x * Window.scale);
        var y = base.y + (self.offset_y * Window.scale);

        // Adjust for element size based on anchor
        switch (self.anchor) {
            .top_center, .center, .bottom_center => {
                x -= (element_width * Window.scale) / 2;
            },
            .top_right, .center_right, .bottom_right => {
                x -= element_width * Window.scale;
            },
            else => {},
        }

        switch (self.anchor) {
            .center_left, .center, .center_right => {
                y -= (element_height * Window.scale) / 2;
            },
            .bottom_left, .bottom_center, .bottom_right => {
                y -= element_height * Window.scale;
            },
            else => {},
        }

        return c.Vector2{ .x = x, .y = y };
    }
};

fn getAnchorPosition(anchor: Anchor) c.Vector2 {
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

// ============================================================================

// Anchor system for UI positioning
pub const Anchor = enum {
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

// Position relative to anchor
pub const RelativePosition = struct {
    anchor: Anchor,
    offset_x: f32, // Offset in game units (not pixels)
    offset_y: f32,

    pub fn toScreenPosition(self: RelativePosition, element_width: f32, element_height: f32) c.Vector2 {
        const base = getAnchorPosition(self.anchor);

        // Apply offset in scaled coordinates
        var x = base.x + (self.offset_x * Window.scale);
        var y = base.y + (self.offset_y * Window.scale);

        // Adjust for element size based on anchor
        switch (self.anchor) {
            .top_center, .center, .bottom_center => {
                x -= (element_width * Window.scale) / 2;
            },
            .top_right, .center_right, .bottom_right => {
                x -= element_width * Window.scale;
            },
            else => {},
        }

        switch (self.anchor) {
            .center_left, .center, .center_right => {
                y -= (element_height * Window.scale) / 2;
            },
            .bottom_left, .bottom_center, .bottom_right => {
                y -= element_height * Window.scale;
            },
            else => {},
        }

        return c.Vector2{ .x = x, .y = y };
    }
};

fn getAnchorPosition(anchor: Anchor) c.Vector2 {
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

pub fn init(alloc: std.mem.Allocator) !void {
    allocator = alloc;
    elements = std.ArrayList(Element).init(allocator);
    menus = std.AutoHashMap(MenuType, *Element).init(allocator);

    try makeUIElements();
}

pub fn update(game: *Game.Game) !void {
    uiCommand = UiCommand{};
    if (Gamestate.currentTurn != .player) {
        return;
    }
    if (Gamestate.showMenu == .none) {
        if (activeMenu != null) {
            activeMenu.?.visible = false;
            activeMenu = null;
        }
    } else {
        if (activeMenu == null) {
            activeMenu = menus.get(Gamestate.showMenu);
            activeMenu.?.visible = true;
        }
    }

    for (elements.items) |element| {
        try element.update(game, null);
    }

    var confirm = InputManager.takeConfirmInput();
    const cancel = InputManager.takeCancelInput();
    const move = InputManager.takePositionInput();

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

    const quickSelect = InputManager.takeQuickSelectInput();
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

pub fn draw() !void {
    for (elements.items) |element| {
        element.draw();
    }

    var buffer: [64:0]u8 = undefined;
    const text = try std.fmt.bufPrintZ(&buffer, "Turn: {}", .{Gamestate.turnNumber});

    // Position turn counter in top-right with anchor system
    const turn_pos = RelativePosition{
        .anchor = .top_right,
        .offset_x = -10, // 10 units from right edge
        .offset_y = 10, // 10 units from top
    };
    const screen_pos = turn_pos.toScreenPosition(0, 0);
    const font_size = @as(i32, @intFromFloat(15 * Window.scale));

    c.DrawText(text.ptr, @intFromFloat(screen_pos.x), @intFromFloat(screen_pos.y), font_size, c.RED);
}

pub fn makeUIElements() !void {
    // Character plate anchored to top-left
    const playerPlate = try makeCharacterPlate(RelativePosition{
        .anchor = .top_left,
        .offset_x = 10,
        .offset_y = 10,
    });
    try elements.append(playerPlate);

    // Deploy menu anchored to center
    deployMenu = try makeChoiceMenu(RelativePosition{
        .anchor = .center,
        .offset_x = 0,
        .offset_y = 0,
    }, "Pick a Puppet:", updatePuppetMenu);
    deployMenu.visible = false;
    try elements.append(deployMenu);

    // Action menu anchored to center
    actionMenu = try makeChoiceMenu(RelativePosition{
        .anchor = .center,
        .offset_x = 0,
        .offset_y = 0,
    }, "Pick Action:", updateActionMenu);
    actionMenu.visible = false;
    try elements.append(actionMenu);

    try menus.put(.puppet_select, deployMenu);
    try menus.put(.action_select, actionMenu);
}

pub fn showDeployMenu() void {
    deployMenu.visible = true;
    activeMenu = deployMenu;
}

pub fn hideDeployMenu() void {
    deployMenu.visible = false;
    activeMenu = null;
}

pub fn updateActiveMenu(move: Types.Vector2Int) void {
    var menuData: ?*ElementMenuData = null;

    if (activeMenu) |active_menu| {
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

pub fn showActionMenu() void {
    actionMenu.visible = true;
    activeMenu = actionMenu;
}

pub fn hideActionMenu() void {
    actionMenu.visible = false;
    activeMenu = null;
}

pub fn getSelectedItem() ?MenuItemData {
    if (activeMenu) |active_menu| {
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

pub const Element = struct {
    visible: bool,
    position: RelativePosition,
    size: c.Vector2, // Base size in game units
    color: c.Color,
    data: ElementData,
    updateFn: ?Updatefunction = null,
    elements: std.ArrayList(*Element),

    pub fn init(position: RelativePosition, size: c.Vector2, color: c.Color, data: ElementData) !*Element {
        const element = try allocator.create(Element);
        const subelements = std.ArrayList(*Element).init(allocator);
        element.* = .{
            .visible = true,
            .position = position,
            .size = size,
            .color = color,
            .data = data,
            .elements = subelements,
        };

        return element;
    }

    pub fn initBackground(position: RelativePosition, size: c.Vector2, color: c.Color) !*Element {
        var element = try Element.init(position, size, color, undefined);
        element.data = ElementData{ .background = ElementBackgroundData{} };
        return element;
    }

    pub fn initText(position: RelativePosition, text: []const u8, color: c.Color) !*Element {
        var element = try Element.init(position, c.Vector2{ .x = 0, .y = 0 }, color, undefined);
        element.data = ElementData{ .text = ElementTextData.init(text, c.WHITE) };
        return element;
    }

    pub fn initMenu(position: RelativePosition, color: c.Color, updateFunction: Updatefunction) !*Element {
        var element = try Element.init(position, c.Vector2{ .x = 0, .y = 0 }, color, undefined);
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

    fn getScreenRect(this: *Element) c.Rectangle {
        const screen_pos = this.position.toScreenPosition(this.size.x, this.size.y);
        return c.Rectangle{
            .x = screen_pos.x,
            .y = screen_pos.y,
            .width = this.size.x * Window.scale,
            .height = this.size.y * Window.scale,
        };
    }

    pub fn update(this: *Element, game: *Game.Game, rect: ?c.Rectangle) !void {
        _ = rect;
        if (this.updateFn) |_fn| {
            try _fn(this, game);
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
                const rect = this.getScreenRect();
                c.DrawRectangleRec(rect, this.color);
            },
            .menu => {
                const screen_pos = this.position.toScreenPosition(0, 0);
                var x = screen_pos.x;
                var y = screen_pos.y;
                const scaled_font_size = @as(i32, @intFromFloat(@as(f32, @floatFromInt(this.data.menu.fontSize)) * Window.scale));
                const line_height = @as(f32, @floatFromInt(scaled_font_size)) * 1.2;

                for (this.data.menu.menuItems.items, 0..) |item, i| {
                    var text_color = this.data.menu.textColor;
                    if (this.data.menu.index == i) {
                        text_color = this.data.menu.pickedTextColor;
                    }

                    c.DrawText(
                        item.text.ptr,
                        @intFromFloat(x),
                        @intFromFloat(y),
                        scaled_font_size,
                        text_color,
                    );
                    y += line_height;
                }
            },
            .bar => {},
            .text => {
                const screen_pos = this.position.toScreenPosition(0, 0);
                const scaled_font_size = @as(i32, @intFromFloat(@as(f32, @floatFromInt(this.data.text.fontSize)) * Window.scale));
                c.DrawText(
                    this.data.text.text.ptr,
                    @intFromFloat(screen_pos.x),
                    @intFromFloat(screen_pos.y),
                    scaled_font_size,
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

pub const ElementBackgroundData = struct {};

pub const ElementBarData = struct {
    min: i32,
    max: i32,
    current: i32,
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

pub fn makeCharacterPlate(position: RelativePosition) !*Element {
    const characterPlate = try Element.initBackground(
        position,
        c.Vector2{ .x = 200, .y = 150 }, // Base size in game units
        c.BEIGE,
    );

    const textPosition = RelativePosition{
        .anchor = position.anchor,
        .offset_x = position.offset_x + 3,
        .offset_y = position.offset_y + 5,
    };

    const characterText = try Element.initText(textPosition, "Player", c.BLACK);
    try characterPlate.elements.append(characterText);

    return characterPlate;
}

pub fn makeChoiceMenu(position: RelativePosition, title: []const u8, updateFunction: Updatefunction) !*Element {
    const menuBackground = try Element.initBackground(
        position,
        c.Vector2{ .x = 200, .y = 150 },
        c.BLUE,
    );

    const titlePosition = RelativePosition{
        .anchor = position.anchor,
        .offset_x = position.offset_x + 3,
        .offset_y = position.offset_y + 5,
    };

    const menuTitle = try Element.initText(titlePosition, title, c.WHITE);
    try menuBackground.elements.append(menuTitle);

    const menuPosition = RelativePosition{
        .anchor = position.anchor,
        .offset_x = position.offset_x + 3,
        .offset_y = position.offset_y + 30,
    };

    const menu = try Element.initMenu(
        menuPosition,
        c.BLUE,
        updateFunction,
    );
    try menuBackground.elements.append(menu);

    return menuBackground;
}

pub fn updatePuppetMenu(this: *Element, game: *Game.Game) MenuError!void {
    this.data.menu.menuItems.clearRetainingCapacity();

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
