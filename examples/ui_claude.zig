// Looking at your code and Casey's notes, here's the key insight for your situation: you don't store elements at all. Each frame you just call widget functions, and they draw + handle input themselves. The context just tracks which item is selected.
// For keyboard-only, hot disappears — active becomes "which menu item has keyboard focus", driven by your navigation index.
// The ID problem you're confused about: for keyboard menus you mainly need menuIndex (which item in the current menu is selected). The "owner" part just tells you which menu is open, which you already have via Gamestate.showMenu.
// Let me rewrite uiManager.zig:Decided to implement immediate mode UI code directlyDecided to implement immediate mode UI code directlyHere's the full rewrite with explanation inline:Created a file, read a fileCreated a file, read a fileHere's the mental model of what changed and why:
// Where did the stored elements list go?
// It's gone. In immediate mode, the menus are defined by code flow, not stored data. The "for menus loop" Casey describes is the switch (Gamestate.showMenu) in draw() — each branch just calls a function.
// The ID question you were stuck on:
// For keyboard-only you don't really need owner/item/index like Casey's mouse version. You only need menuIndex (which item has focus) because there's only ever one active menu at a time. The "owner" is implicit in Gamestate.showMenu.
// The navigation trick:
// Navigation (moveY) is applied at the top of update() using lastMenuItemCount from the previous frame. By the time doMenuItem calls happen in draw(), the index is already correct. doMenuItem just writes lastMenuItemCount after the final item so next frame's navigation has the right count.
// What you still need to handle:
// When Gamestate.showMenu changes to a new menu type, you probably want to reset ctx.menuIndex = 0, which currently happens in update() when showMenu == .none. If you can switch directly between menus without going through .none, add a reset in playerController when you change Gamestate.showMenu.

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

// ---------------------------------------------------------------------------
// IMMEDIATE MODE UI
//
// How it works:
//   Each frame, just CALL widget functions. They draw themselves AND return
//   whether they were activated. No stored element list.
//
//   if (doMenuItem(&ctx, "Move")) {
//       // player picked Move
//   }
//
// The UIContext tracks only what's needed across frames:
//   - menuIndex: which item in the current menu has keyboard focus
//   - lastMenuItemCount: how many items the menu had last frame (for wrap-around nav)
//   - raw inputs captured once per frame
//
// The "for menus loop" Casey talks about is just the switch in draw() below.
// You don't store menus — you just call them.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// Context
// ---------------------------------------------------------------------------

pub const UIContext = struct {
    // Keyboard navigation state
    menuIndex: u32 = 0,
    lastMenuItemCount: u32 = 0, // set at end of each menu render, used next frame for wrap

    // Raw inputs captured once per frame in update().
    // Widget functions consume these (set to false/null after reading).
    confirm: bool = false,
    cancel: bool = false,
    moveY: i32 = 0, // -1 = up, +1 = down  (from H/J/K/L or arrow keys)
    move: ?Types.Vector2Int = null, // full directional input (for player walking)
    quickSelect: ?u8 = null,
    combatToggle: bool = false,
    skip: bool = false,
};

pub var ctx: UIContext = .{};

// ---------------------------------------------------------------------------
// Public API — same surface as before so playerController doesn't change
// ---------------------------------------------------------------------------

pub fn init(alloc: std.mem.Allocator) !void {
    _ = alloc; // immediate mode needs no allocator for element storage
}

pub fn update(game: *Game.Game) !void {
    _ = game;

    // Capture all inputs once per frame into context.
    // Widget functions below will consume them.
    ctx.confirm = InputManager.takeConfirmInput();
    ctx.cancel = InputManager.takeCancelInput();
    ctx.combatToggle = InputManager.takeCombatToggle();
    ctx.skip = InputManager.takeSkipInput();
    ctx.quickSelect = InputManager.takeQuickSelectInput();

    const rawMove = InputManager.takePositionInput();
    ctx.move = rawMove;
    ctx.moveY = if (rawMove) |m| m.y else 0;

    // Navigation: apply moveY to menuIndex using LAST frame's item count.
    // This runs before any doMenuItem calls this frame, so the index is
    // already correct when we start drawing.
    if (ctx.lastMenuItemCount > 0) {
        if (ctx.moveY == -1) {
            ctx.menuIndex = if (ctx.menuIndex == 0)
                ctx.lastMenuItemCount - 1
            else
                ctx.menuIndex - 1;
            ctx.moveY = 0;
            ctx.move = null; // consumed by menu nav, don't also move the player
        } else if (ctx.moveY == 1) {
            ctx.menuIndex = if (ctx.menuIndex >= ctx.lastMenuItemCount - 1)
                0
            else
                ctx.menuIndex + 1;
            ctx.moveY = 0;
            ctx.move = null;
        }
    }

    // When no menu is open, reset navigation state so it's clean next time
    // a menu opens.
    if (Gamestate.showMenu == .none) {
        ctx.menuIndex = 0;
        ctx.lastMenuItemCount = 0;
    }
}

pub fn draw(game: *Game.Game) !void {
    // Always-visible HUD elements
    drawCharacterPlate(game);
    drawTurnInfo();
    drawCombatIndicator(game);

    // ---------------------------------------------------------------------------
    // THE "for menus" LOOP Casey describes — just a switch.
    // Each branch calls a function that internally calls doMenuItem for each item.
    // There is no stored list of menus; they are defined by the code path.
    // ---------------------------------------------------------------------------
    switch (Gamestate.showMenu) {
        .none => {},
        .puppet_select => try doPuppetSelectMenu(game),
        .action_select => try doActionSelectMenu(game),
        .skill_select => {}, // TODO
        .item_select => {}, // TODO
    }
}

// ---------------------------------------------------------------------------
// Widget functions
// Each one draws itself AND returns whether it was activated.
// ---------------------------------------------------------------------------

/// A single keyboard-navigable menu item.
/// Call this in a loop for each item in a menu.
/// Returns true the frame the player confirms (Enter) on this item.
///
/// itemIndex  — position of this item in the menu (0-based)
/// itemCount  — total number of items (used to write lastMenuItemCount at the end)
pub fn doMenuItem(
    itemIndex: u32,
    itemCount: u32,
    text: [:0]const u8,
    x: i32,
    y: i32,
) bool {
    const selected = ctx.menuIndex == itemIndex;

    // Draw — highlighted if selected
    const color = if (selected) rl.Color.red else rl.Color.yellow;
    const prefix: [:0]const u8 = if (selected) "> " else "  ";
    var buf: [128:0]u8 = undefined;
    const line = std.fmt.bufPrintZ(&buf, "{s}{s}", .{ prefix, text }) catch text;
    const fontSize = @as(c_int, @intFromFloat(@as(f32, 20) * Window.scale));
    rl.drawText(line, x, y, fontSize, color);

    // After drawing the last item, record count for next-frame navigation
    if (itemIndex == itemCount - 1) {
        ctx.lastMenuItemCount = itemCount;
    }

    // Confirm: only fires for the selected item, consumes the input
    if (selected and ctx.confirm) {
        ctx.confirm = false;
        return true;
    }

    return false;
}

// ---------------------------------------------------------------------------
// Menus
// ---------------------------------------------------------------------------

fn doPuppetSelectMenu(game: *Game.Game) !void {
    const panelX = @as(i32, @intFromFloat(Window.scaledWidthHalf)) - 100;
    const panelY = @as(i32, @intFromFloat(@as(f32, @floatFromInt(Window.scaledHeight)) * 0.6));
    const panelW = 200;
    const panelH = 150;

    rl.drawRectangle(panelX, panelY, panelW, panelH, rl.Color.dark_blue);

    const titleFontSize = @as(c_int, @intFromFloat(@as(f32, 18) * Window.scale));
    rl.drawText("Pick a Puppet:", panelX + 5, panelY + 5, titleFontSize, rl.Color.white);

    // Count eligible puppets first (needed for doMenuItem's itemCount param)
    var count: u32 = 0;
    for (game.player.data.player.puppets.items) |pupID| {
        const puppet = EntityManager.getEntityID(pupID) orelse continue;
        if (!puppet.active) count += 1;
    }

    if (count == 0) return;

    // Now render each item
    var idx: u32 = 0;
    for (game.player.data.player.puppets.items) |pupID| {
        const puppet = EntityManager.getEntityID(pupID) orelse continue;
        if (puppet.active) continue;

        const itemY = panelY + 30 + @as(i32, @intCast(idx)) * 22;

        if (doMenuItem(idx, count, puppet.name, panelX + 10, itemY)) {
            // Player confirmed this puppet — write into the command slot
            // that playerController reads via getMenuSelect()
            pendingMenuSelect = MenuItemData{ .puppet_id = pupID };
        }
        idx += 1;
    }
}

fn doActionSelectMenu(game: *Game.Game) !void {
    const selectedEntity = blk: {
        const id = Gamestate.selectedEntityID orelse return;
        break :blk EntityManager.getEntityID(id) orelse return;
    };
    _ = game;

    const panelX = @as(i32, @intFromFloat(Window.scaledWidthHalf)) - 100;
    const panelY = @as(i32, @intFromFloat(@as(f32, @floatFromInt(Window.scaledHeight)) * 0.6));
    const panelW = 200;
    const panelH = 120;

    rl.drawRectangle(panelX, panelY, panelW, panelH, rl.Color.dark_blue);

    const titleFontSize = @as(c_int, @intFromFloat(@as(f32, 18) * Window.scale));
    rl.drawText("Pick an Action:", panelX + 5, panelY + 5, titleFontSize, rl.Color.white);

    // Build available actions list — count first
    var count: u32 = 0;
    if (!selectedEntity.hasMoved) count += 1;
    if (!selectedEntity.hasAttacked) count += 1;

    if (count == 0) return;

    var idx: u32 = 0;

    if (!selectedEntity.hasMoved) {
        const itemY = panelY + 30 + @as(i32, @intCast(idx)) * 22;
        if (doMenuItem(idx, count, "MOVE", panelX + 10, itemY)) {
            pendingMenuSelect = MenuItemData{ .action = .move };
        }
        idx += 1;
    }

    if (!selectedEntity.hasAttacked) {
        const itemY = panelY + 30 + @as(i32, @intCast(idx)) * 22;
        if (doMenuItem(idx, count, "ATTACK", panelX + 10, itemY)) {
            pendingMenuSelect = MenuItemData{ .action = .attack };
        }
        idx += 1;
    }
}

// ---------------------------------------------------------------------------
// HUD — always visible, no interactivity needed
// ---------------------------------------------------------------------------

fn drawCharacterPlate(game: *Game.Game) void {
    const x = @as(i32, @intFromFloat(@as(f32, 10) * Window.scale));
    const y = @as(i32, @intFromFloat(@as(f32, 30) * Window.scale));
    const fontSize = @as(c_int, @intFromFloat(@as(f32, 18) * Window.scale));

    rl.drawRectangle(x - 5, y - 5, @intFromFloat(@as(f32, 200) * Window.scale), @intFromFloat(@as(f32, 60) * Window.scale), rl.Color.dark_gray);

    var buf: [64:0]u8 = undefined;
    const hp = std.fmt.bufPrintZ(&buf, "HP: {d}", .{game.player.health}) catch "HP: ?";
    rl.drawText("Player", x, y, fontSize, rl.Color.white);
    rl.drawText(hp, x, y + fontSize + 4, fontSize, rl.Color.green);
}

fn drawTurnInfo() void {
    const x = @as(i32, @intFromFloat(@as(f32, @floatFromInt(Window.scaledWidth)) - @as(f32, 120) * Window.scale));
    const y = @as(i32, @intFromFloat(@as(f32, 10) * Window.scale));
    const fontSize = @as(c_int, @intFromFloat(@as(f32, 18) * Window.scale));

    var buf: [64:0]u8 = undefined;
    const turnText = std.fmt.bufPrintZ(&buf, "Turn: {d}", .{TurnManager.turnNumber}) catch "Turn: ?";
    rl.drawText(turnText, x, y, fontSize, rl.Color.red);

    const whoText: [:0]const u8 = if (TurnManager.turn == .player) "Player" else "Enemy";
    rl.drawText(whoText, x, y + fontSize + 4, fontSize, rl.Color.yellow);
}

fn drawCombatIndicator(game: *Game.Game) void {
    const x = @as(i32, @intFromFloat(@as(f32, @floatFromInt(Window.scaledWidth)) - @as(f32, 120) * Window.scale));
    const y = @as(i32, @intFromFloat(@as(f32, 80) * Window.scale));
    const fontSize = @as(c_int, @intFromFloat(@as(f32, 16) * Window.scale));

    const text: [:0]const u8 = if (game.player.inCombat) "Combat..." else "Exploring...";
    rl.drawText(text, x, y, fontSize, rl.Color.orange);
}

// ---------------------------------------------------------------------------
// Command interface — same getters playerController already calls.
// Populated by widget functions above, consumed once by getters below.
// ---------------------------------------------------------------------------

var pendingMenuSelect: ?MenuItemData = null;

pub const MenuItemData = union(enum) {
    puppet_id: u32,
    action: ActionType,
};

pub const ActionType = enum {
    move,
    attack,
};

pub const MenuType = enum {
    none,
    puppet_select,
    action_select,
    skill_select,
    item_select,
};

pub fn getConfirm() bool {
    const v = ctx.confirm;
    ctx.confirm = false;
    return v;
}

pub fn getCancel() bool {
    const v = ctx.cancel;
    ctx.cancel = false;
    return v;
}

pub fn getMove() ?Types.Vector2Int {
    const v = ctx.move;
    ctx.move = null;
    return v;
}

pub fn getSkip() bool {
    const v = ctx.skip;
    ctx.skip = false;
    return v;
}

pub fn getMenuSelect() ?MenuItemData {
    const v = pendingMenuSelect;
    pendingMenuSelect = null;
    return v;
}

pub fn getQuickSelect() ?u8 {
    const v = ctx.quickSelect;
    ctx.quickSelect = null;
    return v;
}

pub fn getCombatToggle() bool {
    const v = ctx.combatToggle;
    ctx.combatToggle = false;
    return v;
}

pub fn resetActiveMenuIndex() void {
    ctx.menuIndex = 0;
}


//
//TRADING
//

For trading specifically, I'd combine them into one context rather than switching between two independent menus. Here's why:
Trading is fundamentally one interaction — you're always looking at both sides simultaneously, and the two lists are coupled (what you pick on left affects what's valid on right). Switching active menus means you lose the visual connection between them.
The key insight from Casey's approach: just extend UIContext with a second index and a "which side is active" flag. Both menus render every frame, you just route navigation and confirm to whichever side is active.
zig
pub const UIContext = struct {
    menuIndex: u32 = 0,
    lastMenuItemCount: u32 = 0,

    // Trading extension
    tradeActivePane: enum { left, right } = .left,
    tradeRightIndex: u32 = 0,
    tradeRightLastCount: u32 = 0,

    // ... rest unchanged
};
Then the trading menu function looks like this:
zig
fn doTradeMenu(game: *Game.Game, trader: *Entity.Entity) !void {
    // Left pane — player inventory
    drawPaneBackground(leftPanelX, panelY);
    rl.drawText("Your Items", ...);

    const playerItemCount = game.player.inventory.len;
    for (game.player.inventory, 0..) |item, i| {
        // Route index: left pane uses ctx.menuIndex
        const idx: u32 = @intCast(i);
        if (doMenuItemPane(.left, idx, playerItemCount, item.name, x, y)) {
            pendingTradeOffer = item.id; // player offered this item
        }
    }

    // Right pane — trader inventory
    drawPaneBackground(rightPanelX, panelY);
    rl.drawText("Trader Items", ...);

    const traderItemCount = trader.inventory.len;
    for (trader.inventory, 0..) |item, i| {
        // Route index: right pane uses ctx.tradeRightIndex
        const idx: u32 = @intCast(i);
        if (doMenuItemPane(.right, idx, traderItemCount, item.name, x, y)) {
            pendingTradeRequest = item.id;
        }
    }

    // Tab switches active pane, consuming the input
    if (rl.isKeyPressed(.tab)) {
        ctx.tradeActivePane = if (ctx.tradeActivePane == .left) .right else .left;
        // Don't reset indexes — player keeps their position in each list
    }
}
The pane-aware version of doMenuItem just routes to the right index:
zig
fn doMenuItemPane(
    pane: enum { left, right },
    itemIndex: u32,
    itemCount: u32,
    text: [:0]const u8,
    x: i32, y: i32,
) bool {
    const activePane = ctx.tradeActivePane;
    const currentIndex = if (pane == .left) ctx.menuIndex else ctx.tradeRightIndex;
    const selected = currentIndex == itemIndex and activePane == pane;

    // Draw with dimmed color if this pane is inactive
    const color: rl.Color = if (selected)
        rl.Color.red
    else if (activePane == pane)
        rl.Color.yellow
    else
        rl.Color.dark_gray; // dimmed — other pane is active

    // ... draw text with color

    // Track item count for navigation
    if (itemIndex == itemCount - 1) {
        if (pane == .left) ctx.lastMenuItemCount = itemCount
        else ctx.tradeRightLastCount = itemCount;
    }

    if (selected and ctx.confirm) {
        ctx.confirm = false;
        return true;
    }
    return false;
}
And in update() you extend the navigation block:
zig// Navigation routes to whichever pane is active
const activeCount = if (ctx.tradeActivePane == .left)
    ctx.lastMenuItemCount
else
    ctx.tradeRightLastCount;

const activeIndex = if (ctx.tradeActivePane == .left)
    &ctx.menuIndex
else
    &ctx.tradeRightIndex;

if (activeCount > 0 and Gamestate.showMenu == .trade) {
    if (ctx.moveY == -1) {
        activeIndex.* = if (activeIndex.* == 0) activeCount - 1 else activeIndex.* - 1;
        ctx.move = null;
    } else if (ctx.moveY == 1) {
        activeIndex.* = if (activeIndex.* >= activeCount - 1) 0 else activeIndex.* + 1;
        ctx.move = null;
    }
}
The thing to resist is making this two separate menu systems that you swap between — that forces you to save/restore index state and you lose the ability to show both sides highlighted simultaneously. One context, two index fields, one active-pane flag is all you need.




//
//TODO: RESULT:
//


