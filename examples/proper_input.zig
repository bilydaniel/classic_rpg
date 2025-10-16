const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});
const Types = @import("../common/types.zig");
const Config = @import("../common/config.zig");

// Actions that can be performed in the game
pub const Action = enum {
    move_up,
    move_down,
    move_left,
    move_right,
    move_up_left,
    move_up_right,
    move_down_left,
    move_down_right,

    confirm,
    cancel,

    toggle_combat,
    deploy_puppet,

    select_entity_1,
    select_entity_2,
    select_entity_3,
    select_entity_4,
    select_entity_5,

    select_move_mode,
    select_attack_mode,
    skip_action,

    // Mouse-specific
    mouse_primary,
    mouse_secondary,
};

pub const InputState = enum {
    released,
    just_pressed,
    held,
    just_released,
};

pub const MouseButton = enum {
    left,
    right,
    middle,
};

// Binding configuration
pub const Binding = union(enum) {
    keyboard: c_int,
    mouse: MouseButton,

    pub fn isPressed(self: Binding) bool {
        return switch (self) {
            .keyboard => |key| c.IsKeyPressed(key),
            .mouse => |btn| switch (btn) {
                .left => c.IsMouseButtonPressed(c.MOUSE_BUTTON_LEFT),
                .right => c.IsMouseButtonPressed(c.MOUSE_BUTTON_RIGHT),
                .middle => c.IsMouseButtonPressed(c.MOUSE_BUTTON_MIDDLE),
            },
        };
    }

    pub fn isDown(self: Binding) bool {
        return switch (self) {
            .keyboard => |key| c.IsKeyDown(key),
            .mouse => |btn| switch (btn) {
                .left => c.IsMouseButtonDown(c.MOUSE_BUTTON_LEFT),
                .right => c.IsMouseButtonDown(c.MOUSE_BUTTON_RIGHT),
                .middle => c.IsMouseButtonDown(c.MOUSE_BUTTON_MIDDLE),
            },
        };
    }

    pub fn isReleased(self: Binding) bool {
        return switch (self) {
            .keyboard => |key| c.IsKeyReleased(key),
            .mouse => |btn| switch (btn) {
                .left => c.IsMouseButtonReleased(c.MOUSE_BUTTON_LEFT),
                .right => c.IsMouseButtonReleased(c.MOUSE_BUTTON_RIGHT),
                .middle => c.IsMouseButtonReleased(c.MOUSE_BUTTON_MIDDLE),
            },
        };
    }
};

pub const InputManager = struct {
    bindings: std.AutoHashMap(Action, []const Binding),
    action_states: std.AutoHashMap(Action, InputState),
    allocator: std.mem.Allocator,

    mouse_pos_screen: c.Vector2,
    mouse_pos_world: c.Vector2,
    mouse_tile_pos: ?Types.Vector2Int,

    pub fn init(allocator: std.mem.Allocator) !InputManager {
        var manager = InputManager{
            .bindings = std.AutoHashMap(Action, []const Binding).init(allocator),
            .action_states = std.AutoHashMap(Action, InputState).init(allocator),
            .allocator = allocator,
            .mouse_pos_screen = .{ .x = 0, .y = 0 },
            .mouse_pos_world = .{ .x = 0, .y = 0 },
            .mouse_tile_pos = null,
        };

        try manager.setupDefaultBindings();
        return manager;
    }

    pub fn deinit(self: *InputManager) void {
        var iter = self.bindings.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
        self.bindings.deinit();
        self.action_states.deinit();
    }

    fn setupDefaultBindings(self: *InputManager) !void {
        // Movement
        try self.bindAction(.move_up, &[_]Binding{ .{ .keyboard = c.KEY_UP }, .{ .keyboard = c.KEY_K } });
        try self.bindAction(.move_down, &[_]Binding{ .{ .keyboard = c.KEY_DOWN }, .{ .keyboard = c.KEY_J } });
        try self.bindAction(.move_left, &[_]Binding{ .{ .keyboard = c.KEY_LEFT }, .{ .keyboard = c.KEY_H } });
        try self.bindAction(.move_right, &[_]Binding{ .{ .keyboard = c.KEY_RIGHT }, .{ .keyboard = c.KEY_L } });

        // Diagonal movement
        try self.bindAction(.move_up_left, &[_]Binding{.{ .keyboard = c.KEY_Y }});
        try self.bindAction(.move_up_right, &[_]Binding{.{ .keyboard = c.KEY_U }});
        try self.bindAction(.move_down_left, &[_]Binding{.{ .keyboard = c.KEY_B }});
        try self.bindAction(.move_down_right, &[_]Binding{.{ .keyboard = c.KEY_N }});

        // Actions
        try self.bindAction(.confirm, &[_]Binding{ .{ .keyboard = c.KEY_A }, .{ .keyboard = c.KEY_ENTER }, .{ .mouse = .left } });
        try self.bindAction(.cancel, &[_]Binding{ .{ .keyboard = c.KEY_ESCAPE }, .{ .mouse = .right } });

        try self.bindAction(.toggle_combat, &[_]Binding{.{ .keyboard = c.KEY_F }});
        try self.bindAction(.deploy_puppet, &[_]Binding{.{ .keyboard = c.KEY_D }});

        // Entity selection
        try self.bindAction(.select_entity_1, &[_]Binding{.{ .keyboard = c.KEY_ONE }});
        try self.bindAction(.select_entity_2, &[_]Binding{.{ .keyboard = c.KEY_TWO }});
        try self.bindAction(.select_entity_3, &[_]Binding{.{ .keyboard = c.KEY_THREE }});
        try self.bindAction(.select_entity_4, &[_]Binding{.{ .keyboard = c.KEY_FOUR }});
        try self.bindAction(.select_entity_5, &[_]Binding{.{ .keyboard = c.KEY_FIVE }});

        // Combat modes
        try self.bindAction(.select_move_mode, &[_]Binding{.{ .keyboard = c.KEY_Q }});
        try self.bindAction(.select_attack_mode, &[_]Binding{.{ .keyboard = c.KEY_W }});
        try self.bindAction(.skip_action, &[_]Binding{.{ .keyboard = c.KEY_SPACE }});

        // Mouse
        try self.bindAction(.mouse_primary, &[_]Binding{.{ .mouse = .left }});
        try self.bindAction(.mouse_secondary, &[_]Binding{.{ .mouse = .right }});
    }

    fn bindAction(self: *InputManager, action: Action, bindings: []const Binding) !void {
        const binding_copy = try self.allocator.dupe(Binding, bindings);
        try self.bindings.put(action, binding_copy);
        try self.action_states.put(action, .released);
    }

    pub fn update(self: *InputManager, camera: c.Camera2D) void {
        // Update action states
        var iter = self.bindings.iterator();
        while (iter.next()) |entry| {
            const action = entry.key_ptr.*;
            const bindings = entry.value_ptr.*;

            const current_state = self.action_states.get(action) orelse .released;
            var any_pressed = false;
            var any_down = false;

            for (bindings) |binding| {
                if (binding.isPressed()) any_pressed = true;
                if (binding.isDown()) any_down = true;
            }

            const new_state: InputState = switch (current_state) {
                .released => if (any_pressed) .just_pressed else .released,
                .just_pressed => if (any_down) .held else .just_released,
                .held => if (any_down) .held else .just_released,
                .just_released => if (any_pressed) .just_pressed else .released,
            };

            self.action_states.put(action, new_state) catch {};
        }

        // Update mouse position
        self.mouse_pos_screen = c.GetMousePosition();
        self.mouse_pos_world = c.GetScreenToWorld2D(self.mouse_pos_screen, camera);

        const tile_x = @divFloor(@as(i32, @intFromFloat(self.mouse_pos_world.x)), Config.tile_width);
        const tile_y = @divFloor(@as(i32, @intFromFloat(self.mouse_pos_world.y)), Config.tile_height);

        if (tile_x >= 0 and tile_x < Config.level_width and tile_y >= 0 and tile_y < Config.level_height) {
            self.mouse_tile_pos = Types.Vector2Int{ .x = tile_x, .y = tile_y };
        } else {
            self.mouse_tile_pos = null;
        }
    }

    pub fn isActionPressed(self: *InputManager, action: Action) bool {
        const state = self.action_states.get(action) orelse return false;
        return state == .just_pressed;
    }

    pub fn isActionHeld(self: *InputManager, action: Action) bool {
        const state = self.action_states.get(action) orelse return false;
        return state == .held or state == .just_pressed;
    }

    pub fn isActionReleased(self: *InputManager, action: Action) bool {
        const state = self.action_states.get(action) orelse return false;
        return state == .just_released;
    }

    pub fn getMovementInput(self: *InputManager) ?Types.Vector2Int {
        var dir = Types.Vector2Int{ .x = 0, .y = 0 };
        var has_input = false;

        if (self.isActionPressed(.move_up)) {
            dir.y -= 1;
            has_input = true;
        }
        if (self.isActionPressed(.move_down)) {
            dir.y += 1;
            has_input = true;
        }
        if (self.isActionPressed(.move_left)) {
            dir.x -= 1;
            has_input = true;
        }
        if (self.isActionPressed(.move_right)) {
            dir.x += 1;
            has_input = true;
        }

        // Diagonals override WASD if pressed
        if (self.isActionPressed(.move_up_left)) {
            dir = Types.Vector2Int{ .x = -1, .y = -1 };
            has_input = true;
        }
        if (self.isActionPressed(.move_up_right)) {
            dir = Types.Vector2Int{ .x = 1, .y = -1 };
            has_input = true;
        }
        if (self.isActionPressed(.move_down_left)) {
            dir = Types.Vector2Int{ .x = -1, .y = 1 };
            has_input = true;
        }
        if (self.isActionPressed(.move_down_right)) {
            dir = Types.Vector2Int{ .x = 1, .y = 1 };
            has_input = true;
        }

        return if (has_input) dir else null;
    }

    pub fn getMouseTilePos(self: *InputManager) ?Types.Vector2Int {
        return self.mouse_tile_pos;
    }
};


//how to use:
// Instead of: if (c.IsKeyPressed(c.KEY_D))
if (ctx.input.isActionPressed(.deploy_puppet))

// Instead of: if (c.IsKeyPressed(c.KEY_F))
if (ctx.input.isActionPressed(.toggle_combat))

// Movement becomes:
if (ctx.input.getMovementInput()) |direction| {
    const new_pos = Types.vector2IntAdd(entity.pos, direction);
    // ... handle movement
}

// Mouse support:
if (ctx.input.getMouseTilePos()) |tile_pos| {
    if (ctx.input.isActionPressed(.mouse_primary)) {
        // Handle click at tile_pos
    }
}
