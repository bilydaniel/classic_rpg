const Types = @import("../common/types.zig");
const std = @import("std");
const c = @cImport({
    @cInclude("raylib.h");
});

const inputStateEnum = enum {
    game,
    menu,
};

var state: inputStateEnum = .game;

var up: c_int = c.KEY_K;
var down: c_int = c.KEY_J;
var left: c_int = c.KEY_H;
var right: c_int = c.KEY_L;
var confirm: c_int = c.KEY_ENTER;
var cancel: c_int = c.KEY_Q;
var combatToggle: c_int = c.KEY_F;
var quickSelect: [5]u8 = .{ c.KEY_ONE, c.KEY_TWO, c.KEY_THREE, c.KEY_FOUR, c.KEY_FIVE };

//TODO: take delta position and use it to update cursos/player
pub fn takePositionInput() ?Types.Vector2Int {
    var result: ?Types.Vector2Int = null;
    if (c.IsKeyPressed(left)) {
        result = .{ .x = -1, .y = 0 };
    } else if (c.IsKeyPressed(right)) {
        result = .{ .x = 1, .y = 0 };
    } else if (c.IsKeyPressed(down)) {
        result = .{ .x = 0, .y = 1 };
    } else if (c.IsKeyPressed(up)) {
        result = .{ .x = 0, .y = -1 };
    }

    return result;
}

pub fn takeConfirmInput() bool {
    if (c.IsKeyPressed(confirm)) {
        return true;
    }
    return false;
}

pub fn takeCancelInput() bool {
    if (c.IsKeyPressed(cancel)) {
        return true;
    }
    return false;
}

pub fn takeQuickSelectInput() ?u8 {
    for (0.., quickSelect) |k, v| {
        if (c.IsKeyPressed(v)) {
            return @intCast(k);
        }
    }
    return null;
}

pub fn takeCombatToggle() bool {
    if (c.IsKeyPressed(combatToggle)) {
        return true;
    }
    return false;
}
