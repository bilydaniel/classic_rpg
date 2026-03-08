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
const rl = @import("raylib");

//TODO: checkout the draw buffer:
//https://gemini.google.com/app/4caa258211f314ad
var allocator: std.mem.Allocator = undefined;

var activeID: i32 = 0;
var hotID: i32 = 0;

var menu_pos: rl.Vector2 = .{ .x = 0, .y = 0 };
var layout_y: f32 = 0;
var item_index: i32 = 0;
var hot_index: i32 = 0;
var itemCount: i32 = 0;
var lastItemCount: i32 = 0;

var confirm: bool = false;
var cancel: bool = false;
var move: ?Types.Vector2Int = null;
var combatToggle: bool = false;
var skip: bool = false;
var quickSelect: ?u8 = null;

//TODO: probalby remove
var menuSelect: ?MenuItemData = null;

var primaryColor: rl.Color = rl.Color.green;
var secondary: rl.Color = rl.Color.beige;

var fontSize: i32 = 20;

pub var uiTexture: rl.RenderTexture2D = undefined;

pub fn init(alloc: std.mem.Allocator) !void {
    allocator = alloc;
    uiTexture = try rl.loadRenderTexture(Config.game_width, Config.game_height);
}

pub fn deinit() void {
    rl.unloadTexture(uiTexture);
}

//TODO: can i separate update and draw?
pub fn updateAndDraw(game: *Game.Game) !void {
    _ = game;
    if (TurnManager.turn != .player) {
        return;
    }

    drawNonInteractive();

    itemCount = 0;

    //confirm
    confirm = InputManager.takeConfirmInput();

    //cancel
    cancel = InputManager.takeCancelInput();

    //move
    move = InputManager.takePositionInput();

    //menu select
    // if (move) |_move| {
    //     updateActiveMenu(_move);
    // }

    // var menuSelect: ?MenuItemData = null;
    // if (confirm) {
    //     menuSelect = getSelectedItem();
    //     if (menuSelect != null) {
    //         confirm = false;
    //     }
    // }

    //quick select
    // const quickSelect = InputManager.takeQuickSelectInput();
    //
    // //combat toggle
    // const combatToggle = InputManager.takeCombatToggle();
    //
    // const skip = InputManager.takeSkipInput();
}

// pub fn makeUIElements() !void {
//     const playerPlatePos = RelativePos.init(.top_left, 10, 30);
//     const playerPlateSize = rl.Vector2{ .x = 200, .y = 150 };
//     _ = try makeCharacterPlate(playerPlatePos, playerPlateSize);
//
//     const deployMenuPos = RelativePos.init(.bottom_center, 0, 0);
//     const deployMenuSize = rl.Vector2{ .x = 200, .y = 150 };
//     const deployMenuID = try makeChoiceMenu(deployMenuPos, deployMenuSize, "Pick a Puppet:", MenuType.puppet_select, updatePuppetMenu);
//     hideElementGroup(deployMenuID);
//
//     const actionMenuPos = RelativePos.init(.bottom_center, 0, 0);
//     const actionMenuSize = rl.Vector2{ .x = 200, .y = 150 };
//     const actionMenuID = try makeChoiceMenu(actionMenuPos, actionMenuSize, "Pick an Action:", MenuType.action_select, updateActionMenu);
//     hideElementGroup(actionMenuID);
//
//     const turnNumberPos = RelativePos.init(.top_right, 0, 0);
//     const turnNumberSize = rl.Vector2{ .x = 100, .y = 100 };
//
//     const turnElementID = try makeText(turnNumberPos, turnNumberSize, "Turn:");
//     const turnElement = getElementByID(turnElementID);
//     if (turnElement) |element| {
//         element.updateFn = updateTurnNumberText;
//     }
//
//     const currentTurnPos = RelativePos.init(.top_right, 0, 100);
//     const currentTurnSize = rl.Vector2{ .x = 100, .y = 100 };
//
//     const currentTurnID = try makeText(currentTurnPos, currentTurnSize, "");
//     const currentTurnElement = getElementByID(currentTurnID);
//     if (currentTurnElement) |element| {
//         element.updateFn = updateCurrentTurnText;
//     }
//
//     const combatIndicatorPos = RelativePos.init(.top_right, 0, 150);
//     const combatIndicatorSize = rl.Vector2{ .x = 100, .y = 100 };
//
//     const combatIndicatorID = try makeText(combatIndicatorPos, combatIndicatorSize, "");
//     const combatIndicatorElement = getElementByID(combatIndicatorID);
//     if (combatIndicatorElement) |element| {
//         element.updateFn = updateCombatIndicatorText;
//     }
// }

// pub fn updateActiveMenu(move: Types.Vector2Int) void {
//     if (activeMenu) |active_menu| {
//         const activeElement = getElementByID(active_menu) orelse return;
//         var menuData = &activeElement.data.menu;
//         const itemCount = @as(u32, @intCast(menuData.menuItems.items.len));
//         var index = menuData.index;
//         if (itemCount == 0) {
//             return;
//         }
//
//         if (move.y == -1) {
//             if (index <= 0) {
//                 index = itemCount - 1;
//             } else {
//                 index -= 1;
//             }
//         } else if (move.y == 1) {
//             if (index >= itemCount - 1) {
//                 index = 0;
//             } else {
//                 index += 1;
//             }
//         }
//         menuData.index = index;
//     }
// }

// pub fn getSelectedItem() ?MenuItemData {
//     if (activeMenu) |active_menu| {
//         const activeElement = getElementByID(active_menu) orelse return null;
//
//         const menu = activeElement.data.menu;
//         if (menu.menuItems.items.len > 0) {
//             return menu.menuItems.items[menu.index].data;
//         }
//     }
//     return null;
// }

// pub fn resetActiveMenuIndex() void {
//     if (activeMenu) |active_menu| {
//         const activeElement = getElementByID(active_menu) orelse return;
//         activeElement.data.menu.index = 0;
//     }
// }

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
        return RelativePos{
            .anchor = anchor,
            .pos = rl.Vector2{
                .x = x,
                .y = y,
            },
        };
    }
};

fn getScaledSize(size: rl.Vector2) rl.Vector2 {
    return Utils.vector2Scale(size, Window.scale);
}

fn relativeToScreenPos(rPos: RelativePos, size: rl.Vector2) rl.Vector2 {
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

fn getAnchorPosition(anchor: AnchorEnum) rl.Vector2 {
    return switch (anchor) {
        .top_left => rl.Vector2{ .x = 0, .y = 0 },
        .top_center => rl.Vector2{ .x = Window.scaledWidthHalf, .y = 0 },
        .top_right => rl.Vector2{ .x = @floatFromInt(Window.scaledWidth), .y = 0 },
        .center_left => rl.Vector2{ .x = 0, .y = Window.scaledHeightHalf },
        .center => rl.Vector2{ .x = Window.scaledWidthHalf, .y = Window.scaledHeightHalf },
        .center_right => rl.Vector2{ .x = @floatFromInt(Window.scaledWidth), .y = Window.scaledHeightHalf },
        .bottom_left => rl.Vector2{ .x = 0, .y = @floatFromInt(Window.scaledHeight) },
        .bottom_center => rl.Vector2{ .x = Window.scaledWidthHalf, .y = @floatFromInt(Window.scaledHeight) },
        .bottom_right => rl.Vector2{ .x = @floatFromInt(Window.scaledWidth), .y = @floatFromInt(Window.scaledHeight) },
    };
}

// pub fn draw(this: *Element) void {
//     if (!this.visible) {
//         return;
//     }
//
//     switch (this.data) {
//         .menu => {
//             //TODO: @finish
//
//             const size = getScaledSize(this.size);
//             const position = relativeToScreenPos(this.relPos, size);
//
//             var x = position.x;
//             var y = position.y;
//             for (this.data.menu.menuItems.items, 0..) |*item, i| {
//                 var text_color = this.data.menu.textColor;
//                 if (this.data.menu.index == i) {
//                     text_color = this.data.menu.pickedTextColor;
//                     //std.mem.copyForwards(const u8, item.text[2..], item.text);
//                     //TODO: @continue @finish add some arrows to the item being picked
//                 }
//
//                 rl.drawText(
//                     item.text,
//                     @intFromFloat(x),
//                     @intFromFloat(y),
//                     this.data.menu.fontSize,
//                     text_color,
//                 );
//                 x += 0;
//                 y += 20;
//             }
//         },
//         .bar => {},
//     }
// }

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
    textColor: rl.Color = rl.Color.yellow,
    pickedTextColor: rl.Color = rl.Color.red,
};

pub const MenuType = enum {
    none,
    puppet_select,
    action_select,
    skill_select,
    item_select,
};

pub const ElementMenuItem = struct {
    text: [:0]const u8,
    fontSize: i32 = 10,
    textColor: rl.Color = rl.Color.black,
    enabled: bool = true,
    data: MenuItemData,

    pub fn initPupItem(text: [:0]const u8, puppet_id: u32) ElementMenuItem {
        const elementData = MenuItemData{ .puppet_id = puppet_id };
        return ElementMenuItem{
            .text = text,
            .data = elementData,
        };
    }

    pub fn initActionItem(text: [:0]const u8, action: ActionType) ElementMenuItem {
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
    color: rl.Color,
};

pub const ElementBarData = struct {
    min: i32,
    max: i32,
    current: i32,
    //TODO: make a function for copying data from ctx  to bar, I guess make a function separate for each "version" of the bar, => hp, mp, tp, etrl.
};

pub const ElementTextData = struct {
    text: [64:0]u8 = undefined,
    textColor: rl.Color,
    fontSize: i32,

    pub fn init(text: []const u8, textColor: rl.Color) ElementTextData {
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

const MenuError = error{};

pub fn getConfirm() bool {
    const c = confirm;
    confirm = false;
    return c;
}

// pub fn getCancel() bool {
//     const cancel = uiCommand.cancel;
//     uiCommand.cancel = false;
//     return cancel;
// }

pub fn getMove() ?Types.Vector2Int {
    const m = move;
    move = null;
    return m;
}

pub fn getSkip() bool {
    const s = skip;
    skip = false;
    return s;
}

pub fn getMenuSelect() ?MenuItemData {
    const item = menuSelect;
    menuSelect = null;
    return item;
}

pub fn getQuickSelect() ?u8 {
    const item = quickSelect;
    quickSelect = null;
    return item;
}

pub fn getCombatToggle() bool {
    const combat = combatToggle;
    combatToggle = false;
    return combat;
}

// pub fn makeCharacterPlate(relPos: RelativePos, size: rl.Vector2) !i32 {
//     var relativePosition = relPos;
//     const background = Element.initBackground(
//         relativePosition,
//         size,
//         rl.Color.beige,
//     );
//
//     relativePosition.pos.x += 3;
//     relativePosition.pos.y += 5;
//     const text = Element.initText(relativePosition, size, "Player");
//
//     try elements.append(allocator, background);
//     try elements.append(allocator, text);
//     elementGroupID += 1;
//     return background.groupID;
// }

// pub fn makeChoiceMenu(relPos: RelativePos, size: rl.Vector2, title: []const u8, menuType: MenuType, updateFunction: Updatefunction) !i32 {
//     var relativePosition = relPos;
//
//     const background = Element.initBackground(relativePosition, size, rl.Color.blue);
//
//     relativePosition.pos.x += 3;
//     relativePosition.pos.y += 5;
//
//     const titleElement = Element.initText(relativePosition, size, title);
//
//     relativePosition.pos.x += 3;
//     relativePosition.pos.y += 30;
//
//     const menu = Element.initMenu(relativePosition, size, updateFunction);
//     try menus.put(menuType, menu.id);
//
//     try elements.append(allocator, background);
//     try elements.append(allocator, titleElement);
//     try elements.append(allocator, menu);
//     elementGroupID += 1;
//     return background.groupID;
// }

// pub fn makeText(relPos: RelativePos, size: rl.Vector2, text: []const u8) !i32 {
//     //TODO: maybe add some backgrround?
//     const relativePosition = relPos;
//     const textElement = Element.initText(relativePosition, size, text);
//     try elements.append(allocator, textElement);
//     elementGroupID += 1;
//     return textElement.id;
// }

// pub fn updatePuppetMenu(this: *Element, game: *Game.Game) anyerror!void {
//     //TODO: update every frame for now, probably can make it better
//     this.data.menu.menuItems.clearRetainingCapacity();
//
//     //TODO: this is ridicolous, maybe make a getter or something?
//     for (game.player.data.player.puppets.items) |pupID| {
//         const puppet = EntityManager.getEntityID(pupID);
//         if (puppet) |pup| {
//             if (!pup.active) {
//                 const item = ElementMenuItem.initPupItem(pup.name, pup.id);
//                 try this.data.menu.menuItems.append(allocator, item);
//             }
//         }
//     }
// }

// pub fn updateActionMenu(this: *Element, game: *Game.Game) anyerror!void {
//     _ = game;
//     this.data.menu.menuItems.clearRetainingCapacity();
//
//     if (Gamestate.selectedEntityID) |id| {
//         const selectedEntity = EntityManager.getEntityID(id);
//         if (selectedEntity) |se| {
//             if (!se.hasMoved) {
//                 const itemMove = ElementMenuItem.initActionItem("MOVE", ActionType.move);
//                 try this.data.menu.menuItems.append(allocator, itemMove);
//             }
//
//             if (!se.hasAttacked) {
//                 const itemAttack = ElementMenuItem.initActionItem("ATTACK", ActionType.attack);
//                 try this.data.menu.menuItems.append(allocator, itemAttack);
//             }
//         }
//     }
// }

// pub fn updateTurnNumberText(this: *Element, game: *Game.Game) anyerror!void {
//     _ = game;
//
//     _ = try std.fmt.bufPrintZ(&this.data.text.text, "Turn: {}", .{TurnManager.turnNumber});
// }

// pub fn updateCurrentTurnText(this: *Element, game: *Game.Game) anyerror!void {
//     _ = game;
//
//     if (TurnManager.turn == .player) {
//         _ = try std.fmt.bufPrintZ(&this.data.text.text, "{s}", .{"Player"});
//     } else if (TurnManager.turn == .enemy) {
//         _ = try std.fmt.bufPrintZ(&this.data.text.text, "{s}", .{"Enemy"});
//     }
// }

// pub fn updateCombatIndicatorText(this: *Element, game: *Game.Game) anyerror!void {
//     _ = game;
//     const player = EntityManager.getPlayer();
//
//     if (player.inCombat) {
//         _ = try std.fmt.bufPrintZ(&this.data.text.text, "{s}", .{"Combat..."});
//     } else {
//         _ = try std.fmt.bufPrintZ(&this.data.text.text, "{s}", .{"Exploring..."});
//     }
// }

fn drawNonInteractive() void {
    drawPlayerPlate();
    drawTurnPhase();
    drawTurnNumber();
    drawCombatIndicator();
}

fn drawCharacterPlate(relPos: RelativePos, size: rl.Vector2) void {
    var relativePosition = relPos;
    drawBackground(relativePosition, size);

    relativePosition.pos.x += 3;
    relativePosition.pos.y += 5;
    //drawText();

    //drawBar();
}

fn drawCombatIndicator() void {
    const pos = RelativePos.init(.top_right, 0, 150);
    const size = rl.Vector2{ .x = 100, .y = 100 };

    const player = EntityManager.getPlayer();
    if (player.inCombat) {
        drawText(pos, size, "Combat...");
    } else {
        drawText(pos, size, "Exploring...");
    }
}

fn drawTurnPhase() void {
    const pos = RelativePos.init(.top_right, 0, 100);
    const size = rl.Vector2{ .x = 100, .y = 100 };

    if (TurnManager.turn == .player) {
        drawText(pos, size, "Current Turn: Player");
    } else if (TurnManager.turn == .enemy) {
        drawText(pos, size, "Current Turn: Enemies");
    }
}
fn drawTurnNumber() void {
    const pos = RelativePos.init(.top_right, 0, 0);
    const size = rl.Vector2{ .x = 100, .y = 100 };

    drawText(pos, size, "Turn: ");
}
fn drawBar() void {}

fn drawPlayerPlate() void {
    const playerPlatePos = RelativePos.init(.top_left, 10, 30);
    const playerPlateSize = rl.Vector2{ .x = 200, .y = 150 };
    drawCharacterPlate(playerPlatePos, playerPlateSize);
}

fn drawBackground(relPos: RelativePos, size: rl.Vector2) void {
    const s = getScaledSize(size);
    const position = relativeToScreenPos(relPos, s);

    rl.drawRectangle(@intFromFloat(position.x), @intFromFloat(position.y), @intFromFloat(size.x), @intFromFloat(size.y), rl.Color.orange);
}

fn drawText(relPos: RelativePos, size: rl.Vector2, text: [:0]const u8) void {
    const s = getScaledSize(size);
    const position = relativeToScreenPos(relPos, s);
    const font_size = @as(c_int, @intFromFloat(@as(f32, @floatFromInt(fontSize)) * Window.scale));

    rl.drawText(
        text,
        @intFromFloat(position.x),
        @intFromFloat(position.y),
        font_size,
        primaryColor,
    );
}

pub fn drawToBuffer() void {
    rl.beginTextureMode(uiTexture);
    rl.clearBackground(rl.Color.blank);
    itemCount = 0;
}

pub fn stopDrawingToBuffer() void {
    rl.endTextureMode();
    lastItemCount = itemCount;
}

pub fn drawBufferToWindow() void {
    const source = rl.Rectangle{ .x = 0, .y = 0, .width = @floatFromInt(uiTexture.texture.width), .height = @floatFromInt(-uiTexture.texture.height) };

    const dest = rl.Rectangle{ .x = @floatFromInt(Window.offsetx), .y = @floatFromInt(Window.offsety), .width = @floatFromInt(Window.scaledWidth), .height = @floatFromInt(Window.scaledHeight) };

    rl.drawTexturePro(uiTexture.texture, source, dest, .{ .x = 0, .y = 0 }, 0, rl.Color.white);
}
