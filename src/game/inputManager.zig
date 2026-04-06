const Types = @import("../common/types.zig");
const std = @import("std");
const Utils = @import("../common/utils.zig");
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
var skip: c_int = c.KEY_SPACE;

const POSITION_INPUT_COOLDOWN: f32 = 0.3;
var positionInputCooldown: f32 = POSITION_INPUT_COOLDOWN;

//TODO: take delta position and use it to update cursos/player
pub fn takePositionInput(delta: f32) ?Types.Vector2Int {
    var result: ?Types.Vector2Int = null;

    Utils.cooldown(&positionInputCooldown, delta);

    if (positionInputCooldown <= 0) {
        var buttonPressed = false;
        if (c.IsKeyDown(left)) {
            buttonPressed = true;
            result = .{ .x = -1, .y = 0 };
        } else if (c.IsKeyDown(right)) {
            buttonPressed = true;
            result = .{ .x = 1, .y = 0 };
        } else if (c.IsKeyDown(down)) {
            buttonPressed = true;
            result = .{ .x = 0, .y = 1 };
        } else if (c.IsKeyDown(up)) {
            buttonPressed = true;
            result = .{ .x = 0, .y = -1 };
        }
        if (buttonPressed) {
            positionInputCooldown = POSITION_INPUT_COOLDOWN;
        }
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

pub fn takeSkipInput() bool {
    if (c.IsKeyPressed(skip)) {
        return true;
    }
    return false;
}
