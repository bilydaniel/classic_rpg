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

var allocator: std.mem.Allocator = undefined;

var itemIndex: i32 = 0;
var hotIndex: i32 = 0;
var itemCount: i32 = 0;

var lastShowMenu: MenuType = .none;

var confirm: bool = false;
var cancel: bool = false;
var move: ?Types.Vector2Int = null;
var combatToggle: bool = false;
var skip: bool = false;
var quickSelect: ?u8 = null;

//TODO: probalby remove
var menuSelect: ?MenuItemData = null;

var primaryColor: rl.Color = rl.Color.white;
var secondary: rl.Color = rl.Color.beige;
var hotItemColor: rl.Color = rl.Color.red;

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

// separated read input and draw for 0 frame lag between
// player controlle and ui (data form menu + opening menu from player controller)
pub fn readInput(game: *Game.Game) void {
    //TODO: maybe a different condition?
    if (game.player.inCombat and TurnManager.turn != .player) {
        return;
    }
    itemCount = 0;

    //confirm
    confirm = InputManager.takeConfirmInput();

    //cancel
    cancel = InputManager.takeCancelInput();

    //move
    move = InputManager.takePositionInput();

    //quick select
    quickSelect = InputManager.takeQuickSelectInput();

    //combat toggle
    combatToggle = InputManager.takeCombatToggle();

    skip = InputManager.takeSkipInput();

    handleMenuNavigation();
}

pub fn draw(game: *Game.Game) void {
    drawNonInteractive();

    switch (Gamestate.showMenu) {
        .puppet_select => drawPuppetSelectMenu(game),
        .action_select => drawActionSelectMenu(game),
        .none => {},
        else => {},
    }
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

pub const MenuType = enum {
    none,
    puppet_select,
    action_select,
    skill_select,
    item_select,
};

pub const MenuItemData = union(enum) {
    puppet_id: u32,
    action: ActionType,
};

pub const ActionType = enum {
    move,
    attack,
    skip_turn,
};

pub fn getConfirm() bool {
    const c = confirm;
    confirm = false;
    return c;
}

pub fn getCancel() bool {
    const c = cancel;
    cancel = false;
    return c;
}

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

fn drawNonInteractive() void {
    drawPlayerPlate();
    drawTurnPhase();
    drawTurnNumber();
    drawCombatIndicator();
}

fn drawCharacterPlate(relPos: RelativePos, size: rl.Vector2, name: [:0]const u8) void {
    var relativePosition = relPos;
    drawBackground(relativePosition, size);

    relativePosition.pos.x += 3;
    relativePosition.pos.y += 5;
    drawText(relativePosition, .{ .x = 0, .y = 0 }, name, primaryColor);

    drawBar();
}

fn drawCombatIndicator() void {
    const pos = RelativePos.init(.top_right, 0, 150);
    const size = rl.Vector2{ .x = 100, .y = 100 };

    const player = EntityManager.getPlayer();
    if (player.inCombat) {
        drawText(pos, size, "Combat...", primaryColor);
    } else {
        drawText(pos, size, "Exploring...", primaryColor);
    }
}

fn drawTurnPhase() void {
    const pos = RelativePos.init(.top_right, -100, 100);
    const size = rl.Vector2{ .x = 100, .y = 100 };

    if (TurnManager.turn == .player) {
        drawText(pos, size, "Current Turn: Player", primaryColor);
    } else if (TurnManager.turn == .enemy) {
        drawText(pos, size, "Current Turn: Enemies", primaryColor);
    }
}
fn drawTurnNumber() void {
    const pos = RelativePos.init(.top_right, 0, 0);
    const size = rl.Vector2{ .x = 100, .y = 100 };

    drawText(pos, size, "Turn: ", primaryColor);
}
fn drawBar() void {}

fn drawPlayerPlate() void {
    const player = EntityManager.getPlayer();
    const playerPlatePos = RelativePos.init(.top_left, 10, 30);
    const playerPlateSize = rl.Vector2{ .x = 200, .y = 150 };
    drawCharacterPlate(playerPlatePos, playerPlateSize, player.name);
}

fn drawBackground(relPos: RelativePos, size: rl.Vector2) void {
    const s = getScaledSize(size);
    const position = relativeToScreenPos(relPos, s);

    rl.drawRectangle(@intFromFloat(position.x), @intFromFloat(position.y), @intFromFloat(size.x), @intFromFloat(size.y), rl.Color.orange);
}

fn drawText(relPos: RelativePos, size: rl.Vector2, text: [:0]const u8, color: rl.Color) void {
    const s = getScaledSize(size);
    const position = relativeToScreenPos(relPos, s);
    const font_size = @as(c_int, @intFromFloat(@as(f32, @floatFromInt(fontSize)) * Window.scale));

    rl.drawText(
        text,
        @intFromFloat(position.x),
        @intFromFloat(position.y),
        font_size,
        color,
    );
}

pub fn drawToBuffer() void {
    rl.beginTextureMode(uiTexture);
    rl.clearBackground(rl.Color.blank);
    //itemCount = 0;
}

pub fn stopDrawingToBuffer() void {
    rl.endTextureMode();
    //lastItemCount = itemCount;
}

pub fn drawBufferToWindow() void {
    const source = rl.Rectangle{ .x = 0, .y = 0, .width = @floatFromInt(uiTexture.texture.width), .height = @floatFromInt(-uiTexture.texture.height) };

    const dest = rl.Rectangle{ .x = @floatFromInt(Window.offsetx), .y = @floatFromInt(Window.offsety), .width = @floatFromInt(Window.scaledWidth), .height = @floatFromInt(Window.scaledHeight) };

    rl.drawTexturePro(uiTexture.texture, source, dest, .{ .x = 0, .y = 0 }, 0, rl.Color.white);
}

fn handleMenuNavigation() void {
    if (Gamestate.showMenu != lastShowMenu) {
        hotIndex = 0;
        lastShowMenu = Gamestate.showMenu;
    }

    if (Gamestate.showMenu == .none) return;

    const count = getMenuItemsCount();
    if (count) |c| {
        itemCount = c;
    }

    if (move) |m| {
        if (m.y == -1) {
            if (hotIndex <= 0) {
                hotIndex = itemCount - 1;
            } else {
                hotIndex -= 1;
            }
        } else if (m.y == 1) {
            if (hotIndex >= itemCount - 1) {
                hotIndex = 0;
            } else {
                hotIndex += 1;
            }
        }
    }
}

fn beginMenu() void {
    itemIndex = 0;
}

fn endMenu() void {
    //itemCount = item_index;
}

fn menuItem(label: [:0]const u8, pos: RelativePos) bool {
    const isHot = hotIndex == itemIndex;
    const size = rl.Vector2{ .x = 200, .y = 150 };

    // if (is_hot) {
    //     drawBackground(pos, size);
    // }

    var color = primaryColor;
    if (isHot) {
        color = hotItemColor;
        var arrowPos = pos;
        arrowPos.pos.x -= 15;
        drawText(arrowPos, size, ">", color);
    }

    drawText(pos, size, label, color);

    const selected = isHot and confirm;
    if (selected) confirm = false;

    itemIndex += 1;
    return selected;
}

fn drawPuppetSelectMenu(game: *Game.Game) void {
    if (TurnManager.turn == .enemy) {
        return;
    }
    const panelPos = RelativePos.init(.bottom_center, -100, -180);
    drawBackground(panelPos, .{ .x = 200, .y = 150 });

    const titlePos = RelativePos.init(.bottom_center, -90, -175);
    var itemPos = titlePos;
    itemPos.pos.x += 5;
    drawText(titlePos, .{ .x = 200, .y = 150 }, "Deploy Puppet:", primaryColor);

    beginMenu();

    const puppets = &game.player.data.player.puppets;
    for (puppets.items[0..puppets.len]) |pupID| {
        const puppet = EntityManager.getEntityID(pupID) orelse continue;
        if (!puppet.data.puppet.deployed) {
            itemPos.pos.y += 25;
            if (menuItem(puppet.name, itemPos)) {
                menuSelect = .{ .puppet_id = pupID };
            }
        }
    }

    endMenu();
}

fn drawActionSelectMenu(game: *Game.Game) void {
    if (TurnManager.turn == .enemy) {
        return;
    }
    _ = game;

    if (Gamestate.selectedEntityID) |id| {
        const entity = EntityManager.getEntityID(id) orelse {
            return;
        };

        const panelPos = RelativePos.init(.bottom_center, -100, -180);
        drawBackground(panelPos, .{ .x = 200, .y = 150 });

        const titlePos = RelativePos.init(.bottom_center, -90, -175);
        drawText(titlePos, .{ .x = 200, .y = 150 }, "Choose Action:", primaryColor);
        var itemPos = titlePos;
        itemPos.pos.x += 5;

        beginMenu();

        if (!entity.hasMoved) {
            itemPos.pos.y += 25;
            if (menuItem("Move", itemPos)) {
                menuSelect = .{ .action = .move };
            }
        }

        if (!entity.hasAttacked) {
            itemPos.pos.y += 25;
            if (menuItem("Attack", itemPos)) {
                menuSelect = .{ .action = .attack };
            }
        }

        if (!entity.hasMoved or !entity.hasAttacked) {
            itemPos.pos.y += 25;
            if (menuItem("Skip turn", itemPos)) {
                menuSelect = .{ .action = .skip_turn };
            }
        }

        endMenu();
    }
}

fn getMenuItemsCount() ?i32 {
    //TODO: figure out what to do when not in a menu,
    //only have menus for now, no idea how its gonna work
    //for other widgets
    var result: i32 = 0;

    switch (Gamestate.showMenu) {
        .puppet_select => {
            const player = EntityManager.getPlayer();
            const pups = player.data.player.puppets;
            for (pups.items[0..pups.len]) |id| {
                const pup = EntityManager.getEntityID(id);
                if (pup) |p| {
                    //TODO: active or deployed?
                    if (!p.active) {
                        result += 1;
                    }
                }
            }
        },
        .action_select => {
            // result = @typeInfo(ActionType).@"enum".fields.len;

            const entityID = Gamestate.selectedEntityID;
            if (entityID) |id| {
                const entity = EntityManager.getEntityID(id);
                if (entity) |e| {
                    if (!e.hasMoved) {
                        result += 1;
                    }

                    if (!e.hasAttacked) {
                        result += 1;
                    }

                    //skip turn
                    if (!e.hasMoved or !e.hasAttacked) {
                        result += 1;
                    }
                }
            }
        },
        else => {},
    }

    return result;
}
