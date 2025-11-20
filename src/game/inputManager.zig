const Types = @import("../common/types.zig");
const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

const inputStateEnum = enum {
    game,
    menu,
};

pub const InputManager = struct {
    state: inputStateEnum = .game,
    up: c_int = c.KEY_K,
    down: c_int = c.KEY_J,
    left: c_int = c.KEY_H,
    right: c_int = c.KEY_L,
    confirm: c_int = c.KEY_ENTER,

    pub fn init(allocator: std.mem.Allocator) !*InputManager {
        const input_manager = try allocator.create(InputManager);
        input_manager.* = .{};

        return input_manager;
    }

    //TODO: take delta position and use it to update cursos/player
    pub fn takePositionInput(this: *InputManager) ?Types.Vector2Int {
        var result: ?Types.Vector2Int = null;
        if (c.IsKeyPressed(this.left)) {
            result = .{ .x = -1, .y = 0 };
        } else if (c.IsKeyPressed(this.right)) {
            result = .{ .x = 1, .y = 0 };
        } else if (c.IsKeyPressed(this.down)) {
            result = .{ .x = 0, .y = 1 };
        } else if (c.IsKeyPressed(this.up)) {
            result = .{ .x = 0, .y = -1 };
        }

        return result;
    }

    pub fn takeConfirmInput(this: *InputManager) bool {
        if (c.IsKeyPressed(this.confirm)) {
            return true;
        }
        return false;
    }
};

//TODO: make unified function for inputs
//
//return whether it moved
