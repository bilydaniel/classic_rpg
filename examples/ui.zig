const std = @import("std");
const Game = @import("../game/game.zig");
const Entity = @import("../game/entity.zig");
const Window = @import("../game/window.zig");
const Types = @import("../common/types.zig");
const Config = @import("../common/config.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

// ==================== COMMAND SYSTEM ====================
// This is the clean way to communicate from UI to game logic

pub const CommandType = enum {
    none,
    select_puppet,
    deploy_puppet,
    select_entity,
    select_action,
    confirm_move,
    confirm_attack,
    cancel,
    end_turn,
};

pub const Command = struct {
    type: CommandType,
    data: CommandData,
};

pub const CommandData = union(CommandType) {
    none: void,
    select_puppet: usize, // puppet index
    deploy_puppet: usize, // puppet index
    select_entity: usize, // entity index (0=player, 1-4=puppets)
    select_action: ActionType,
    confirm_move: Types.Vector2Int,
    confirm_attack: Types.Vector2Int,
    cancel: void,
    end_turn: void,
};

pub const ActionType = enum {
    move,
    attack,
    skills,
    items,
    wait,
};

// ==================== UI MANAGER ====================

pub const UiManager = struct {
    allocator: std.mem.Allocator,
    ctx: *Game.Context,
    elements: std.ArrayList(*Element),
    commandQueue: std.ArrayList(Command),
    activeMenu: ?*MenuElement,

    pub fn init(allocator: std.mem.Allocator, ctx: *Game.Context) !*UiManager {
        const uimanager = try allocator.create(UiManager);
        const elements = std.ArrayList(*Element).init(allocator);
        const commandQueue = std.ArrayList(Command).init(allocator);

        uimanager.* = .{
            .allocator = allocator,
            .ctx = ctx,
            .elements = elements,
            .commandQueue = commandQueue,
            .activeMenu = null,
        };

        return uimanager;
    }

    pub fn update(this: *UiManager, ctx: *Game.Context) void {
        // Handle input for active menu
        if (this.activeMenu) |menu| {
            menu.handleInput(this);
        }

        // Update all elements
        for (this.elements.items) |element| {
            element.update(ctx);
        }
    }

    pub fn draw(this: *UiManager) void {
        this.drawHUD();
        this.drawPartyPanel();

        // Draw active menu on top
        if (this.activeMenu) |menu| {
            menu.draw();
        }
    }

    // ==================== COMMAND HANDLING ====================

    pub fn pushCommand(this: *UiManager, cmd: Command) !void {
        try this.commandQueue.append(cmd);
    }

    pub fn popCommand(this: *UiManager) ?Command {
        if (this.commandQueue.items.len == 0) return null;
        return this.commandQueue.orderedRemove(0);
    }

    pub fn hasCommands(this: *UiManager) bool {
        return this.commandQueue.items.len > 0;
    }

    // ==================== MENU MANAGEMENT ====================

    pub fn openPuppetSelectMenu(this: *UiManager) !void {
        const puppets = this.ctx.player.data.player.puppets;
        var items = std.ArrayList(MenuItem).init(this.allocator);

        for (puppets.items, 0..) |puppet, i| {
            const deployed = puppet.data.puppet.deployed;
            var name_buf: [64]u8 = undefined;
            const name = std.fmt.bufPrintZ(&name_buf, "Puppet {d} {s}", .{
                i + 1,
                if (deployed) "(Deployed)" else "",
            }) catch "Puppet";

            try items.append(MenuItem{
                .text = try this.allocator.dupe(u8, name),
                .enabled = !deployed,
                .data = MenuItemData{ .puppet_index = i },
            });
        }

        const menu = try MenuElement.init(
            this.allocator,
            "Select Puppet to Deploy",
            items,
            .puppet_select,
        );

        this.activeMenu = menu;
    }

    pub fn openActionMenu(this: *UiManager) !void {
        var items = std.ArrayList(MenuItem).init(this.allocator);

        const entity = this.ctx.gamestate.selectedEntity orelse return;

        try items.append(MenuItem{
            .text = try this.allocator.dupe(u8, "Move"),
            .enabled = !entity.hasMoved,
            .data = MenuItemData{ .action = .move },
        });

        try items.append(MenuItem{
            .text = try this.allocator.dupe(u8, "Attack"),
            .enabled = !entity.hasAttacked,
            .data = MenuItemData{ .action = .attack },
        });

        try items.append(MenuItem{
            .text = try this.allocator.dupe(u8, "Skills"),
            .enabled = true,
            .data = MenuItemData{ .action = .skills },
        });

        try items.append(MenuItem{
            .text = try this.allocator.dupe(u8, "Items"),
            .enabled = true,
            .data = MenuItemData{ .action = .items },
        });

        try items.append(MenuItem{
            .text = try this.allocator.dupe(u8, "Wait"),
            .enabled = true,
            .data = MenuItemData{ .action = .wait },
        });

        const menu = try MenuElement.init(
            this.allocator,
            "Actions",
            items,
            .action_select,
        );

        this.activeMenu = menu;
    }

    pub fn closeMenu(this: *UiManager) void {
        if (this.activeMenu) |menu| {
            menu.deinit();
            this.activeMenu = null;
        }
    }

    // ==================== DRAWING ====================

    fn drawHUD(this: *UiManager) void {
        _ = this;
        const bar_height = 35;
        c.DrawRectangle(0, 0, Config.game_width, bar_height, c.Color{ .r = 30, .g = 30, .b = 40, .a = 230 });
        c.DrawLine(0, bar_height, Config.game_width, bar_height, c.GOLD);

        c.DrawText("PuppetMaster RL", 10, 8, 18, c.GOLD);
    }

    fn drawPartyPanel(this: *UiManager) void {
        const panel_height = 130;
        const panel_y = Config.game_height - panel_height;

        c.DrawRectangle(0, panel_y, Config.game_width, panel_height, c.Color{ .r = 30, .g = 30, .b = 40, .a = 230 });
        c.DrawLine(0, panel_y, Config.game_width, panel_y, c.GOLD);

        // Draw player card
        this.drawCharacterCard(this.ctx.player, 10, panel_y + 10, 0);

        // Draw puppet cards
        for (this.ctx.player.data.player.puppets.items, 0..) |puppet, i| {
            if (!puppet.data.puppet.deployed) continue;
            const x = 10 + (@as(i32, @intCast(i + 1)) * 250);
            this.drawCharacterCard(puppet, x, panel_y + 10, i + 1);
        }
    }

    fn drawCharacterCard(this: *UiManager, entity: *Entity.Entity, x: i32, y: i32, index: usize) void {
        _ = this;
        const width = 240;
        const height = 110;

        c.DrawRectangle(x, y, width, height, c.Color{ .r = 40, .g = 40, .b = 50, .a = 255 });
        c.DrawRectangleLines(x, y, width, height, c.DARKGRAY);

        // Number
        var num_buf: [8]u8 = undefined;
        const num_text = std.fmt.bufPrintZ(&num_buf, "[{d}]", .{index + 1}) catch "[?]";
        c.DrawText(num_text, x + 10, y + 8, 16, c.GOLD);

        // Name
        const name = switch (entity.data) {
            .player => "MASTER",
            .puppet => "PUPPET",
            else => "???",
        };
        c.DrawText(name, x + 50, y + 10, 14, c.WHITE);

        // HP Bar
        drawBar(x + 10, y + 35, width - 20, 16, entity.health, 100, c.RED);

        // MP Bar
        drawBar(x + 10, y + 60, width - 20, 16, entity.mana, 100, c.SKYBLUE);

        // Status
        if (entity.turnTaken) {
            c.DrawText("DONE", x + 10, y + 85, 12, c.GRAY);
        }
    }
};

// ==================== MENU ELEMENT ====================

pub const MenuType = enum {
    puppet_select,
    action_select,
    skill_select,
    item_select,
};

pub const MenuItem = struct {
    text: []const u8,
    enabled: bool,
    data: MenuItemData,
};

pub const MenuItemData = union(enum) {
    puppet_index: usize,
    action: ActionType,
    skill_id: u32,
    item_id: u32,
};

pub const MenuElement = struct {
    allocator: std.mem.Allocator,
    title: []const u8,
    items: std.ArrayList(MenuItem),
    selectedIndex: usize,
    menuType: MenuType,

    pub fn init(
        allocator: std.mem.Allocator,
        title: []const u8,
        items: std.ArrayList(MenuItem),
        menuType: MenuType,
    ) !*MenuElement {
        const menu = try allocator.create(MenuElement);
        menu.* = .{
            .allocator = allocator,
            .title = title,
            .items = items,
            .selectedIndex = 0,
            .menuType = menuType,
        };
        return menu;
    }

    pub fn deinit(this: *MenuElement) void {
        for (this.items.items) |item| {
            this.allocator.free(item.text);
        }
        this.items.deinit();
        this.allocator.destroy(this);
    }

    pub fn handleInput(this: *MenuElement, uiManager: *UiManager) void {
        // Navigate menu
        if (c.IsKeyPressed(c.KEY_J) or c.IsKeyPressed(c.KEY_DOWN)) {
            this.selectedIndex = (this.selectedIndex + 1) % this.items.items.len;
        } else if (c.IsKeyPressed(c.KEY_K) or c.IsKeyPressed(c.KEY_UP)) {
            if (this.selectedIndex == 0) {
                this.selectedIndex = this.items.items.len - 1;
            } else {
                this.selectedIndex -= 1;
            }
        }

        // Confirm selection
        if (c.IsKeyPressed(c.KEY_ENTER) or c.IsKeyPressed(c.KEY_A)) {
            const item = this.items.items[this.selectedIndex];
            if (!item.enabled) return;

            switch (this.menuType) {
                .puppet_select => {
                    uiManager.pushCommand(Command{
                        .type = .deploy_puppet,
                        .data = .{ .deploy_puppet = item.data.puppet_index },
                    }) catch return;
                },
                .action_select => {
                    uiManager.pushCommand(Command{
                        .type = .select_action,
                        .data = .{ .select_action = item.data.action },
                    }) catch return;
                },
                .skill_select => {},
                .item_select => {},
            }

            uiManager.closeMenu();
        }

        // Cancel
        if (c.IsKeyPressed(c.KEY_ESCAPE) or c.IsKeyPressed(c.KEY_X)) {
            uiManager.pushCommand(Command{
                .type = .cancel,
                .data = .{ .cancel = {} },
            }) catch return;
            uiManager.closeMenu();
        }
    }

    pub fn draw(this: *MenuElement) void {
        const menu_width = 300;
        const menu_height = 50 + (@as(i32, @intCast(this.items.items.len)) * 35);
        const menu_x = (Config.game_width - menu_width) / 2;
        const menu_y = (Config.game_height - menu_height) / 2;

        // Background
        c.DrawRectangle(menu_x, menu_y, menu_width, menu_height, c.Color{ .r = 40, .g = 40, .b = 50, .a = 255 });
        c.DrawRectangleLines(menu_x, menu_y, menu_width, menu_height, c.GOLD);

        // Title
        c.DrawText(this.title.ptr, menu_x + 20, menu_y + 10, 18, c.GOLD);

        // Items
        for (this.items.items, 0..) |item, i| {
            const item_y = menu_y + 45 + (@as(i32, @intCast(i)) * 35);
            const is_selected = i == this.selectedIndex;

            if (is_selected) {
                c.DrawRectangle(menu_x + 10, item_y, menu_width - 20, 30, c.GOLD);
            }

            const text_color = if (!item.enabled)
                c.DARKGRAY
            else if (is_selected)
                c.BLACK
            else
                c.WHITE;

            c.DrawText(item.text.ptr, menu_x + 20, item_y + 7, 16, text_color);
        }
    }
};

// ==================== ELEMENT (Your original system) ====================

pub const Element = struct {
    rect: c.Rectangle,
    color: c.Color,
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

    pub fn update(this: *Element, ctx: *Game.Context) void {
        _ = ctx;
        for (this.elements.items) |item| {
            item.update(ctx);
        }
    }

    pub fn draw(this: *Element) void {
        switch (this.data) {
            .background => {
                c.DrawRectangleRec(this.rect, this.color);
            },
            .text => {
                c.DrawText(
                    this.data.text.text.ptr,
                    @intFromFloat(this.rect.x),
                    @intFromFloat(this.rect.y),
                    this.data.text.fontSize,
                    this.data.text.textColor,
                );
            },
            .bar => {},
        }

        for (this.elements.items) |item| {
            item.draw();
        }
    }
};

pub const ElementType = enum {
    background,
    bar,
    text,
};

pub const ElementData = union(ElementType) {
    background: void,
    bar: struct { min: i32, max: i32, current: i32 },
    text: struct { text: []const u8, textColor: c.Color, fontSize: i32 },
};

// ==================== HELPERS ====================

fn drawBar(x: i32, y: i32, width: i32, height: i32, current: i32, max: i32, color: c.Color) void {
    c.DrawRectangle(x, y, width, height, c.Color{ .r = 20, .g = 20, .b = 20, .a = 255 });
    const fill_width = if (max > 0) @divFloor(width * current, max) else 0;
    c.DrawRectangle(x, y, @max(0, fill_width), height, color);
    c.DrawRectangleLines(x, y, width, height, c.BLACK);
}

// In Systems.zig, modify handlePlayerDeploying:

pub fn handlePlayerDeploying(ctx: *Game.Context) !void {
    // Check for UI commands first
    while (ctx.uiManager.hasCommands()) {
        const cmd = ctx.uiManager.popCommand() orelse break;

        switch (cmd.type) {
            .deploy_puppet => {
                const puppet_index = cmd.data.deploy_puppet;
                if (puppet_index < ctx.player.data.player.puppets.items.len) {
                    const puppet = ctx.player.data.player.puppets.items[puppet_index];
                    if (ctx.gamestate.cursor) |cursor_pos| {
                        if (canDeploy(ctx.player, ctx.gamestate, ctx.grid.*, ctx.entities)) {
                            puppet.pos = cursor_pos;
                            puppet.data.puppet.deployed = true;
                            puppet.visible = true;
                        }
                    }
                }
            },
            .cancel => {
                // Handle cancel
            },
            else => {},
        }
    }

    // Setup deployable cells
    if (ctx.gamestate.deployableCells == null) {
        const neighbours = neighboursAll(ctx.player.pos);
        ctx.gamestate.deployableCells = neighbours;
    }

    // Highlight deployable cells
    if (ctx.gamestate.deployableCells) |cells| {
        if (!ctx.gamestate.deployHighlighted) {
            for (cells) |value| {
                if (value) |val| {
                    try highlightTile(ctx.gamestate, val);
                }
            }
            ctx.gamestate.deployHighlighted = true;
        }
    }

    // Update cursor
    ctx.gamestate.makeCursor(ctx.player.pos);
    ctx.gamestate.updateCursor();

    // Open puppet menu with 'D' key
    if (c.IsKeyPressed(c.KEY_D)) {
        try ctx.uiManager.openPuppetSelectMenu();
    }

    // Check if all deployed
    if (ctx.player.data.player.allPupsDeployed()) {
        ctx.gamestate.reset();
        ctx.player.data.player.state = .in_combat;
    }

    // End combat early
    if (c.IsKeyPressed(c.KEY_F)) {
        if (canEndCombat(ctx.player, ctx.entities)) {
            ctx.gamestate.reset();
            ctx.player.endCombat();
        }
    }
}

// Similar for handlePlayerCombat - add at the beginning:

pub fn playerCombatTurn(ctx: *Game.Context) !void {
    // Process UI commands
    while (ctx.uiManager.hasCommands()) {
        const cmd = ctx.uiManager.popCommand() orelse break;

        switch (cmd.type) {
            .select_action => {
                const action = cmd.data.select_action;
                switch (action) {
                    .move => {
                        ctx.gamestate.selectedEntityMode = .moving;
                        if (ctx.gamestate.selectedEntity) |entity| {
                            ctx.gamestate.makeCursor(entity.pos);
                        }
                    },
                    .attack => {
                        ctx.gamestate.selectedEntityMode = .attacking;
                        if (ctx.gamestate.selectedEntity) |entity| {
                            ctx.gamestate.makeCursor(entity.pos);
                        }
                    },
                    .wait => {
                        if (ctx.gamestate.selectedEntity) |entity| {
                            entity.turnTaken = true;
                        }
                    },
                    else => {},
                }
            },
            .cancel => {
                ctx.gamestate.selectedEntityMode = .none;
                ctx.gamestate.removeCursor();
            },
            else => {},
        }
    }

    // Your existing combat logic
    entitySelect(ctx);
    try selectedEntityAction(ctx);
}

// In Systems.zig - create a dedicated cursor handler
pub fn handleCursorInput(ctx: *Game.Context) void {
    if (ctx.gamestate.cursor == null) return;

    if (c.IsKeyPressed(c.KEY_H) and ctx.gamestate.cursor.?.x > 0) {
        ctx.gamestate.cursor.?.x -= 1;
    } else if (c.IsKeyPressed(c.KEY_L) and ctx.gamestate.cursor.?.x < Config.level_width - 1) {
        ctx.gamestate.cursor.?.x += 1;
    } else if (c.IsKeyPressed(c.KEY_J) and ctx.gamestate.cursor.?.y < Config.level_height - 1) {
        ctx.gamestate.cursor.?.y += 1;
    } else if (c.IsKeyPressed(c.KEY_K) and ctx.gamestate.cursor.?.y > 0) {
        ctx.gamestate.cursor.?.y -= 1;
    }
}

// Then in handlePlayerDeploying:
pub fn handlePlayerDeploying(ctx: *Game.Context) !void {
    // ... setup code ...

    ctx.gamestate.makeCursor(ctx.player.pos);
    handleCursorInput(ctx); // Single call instead of updateCursor()

    // ... rest of logic ...
}
