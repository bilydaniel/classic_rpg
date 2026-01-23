const Game = @import("../game/game.zig");

pub const TurnEnum = enum {
    player,
    enemy,
};

pub const PhaseEnum = enum {
    setup,
    acting,
    cleanup,
};

pub var turn: TurnEnum = .player;
pub var phase: PhaseEnum = .setup;
pub var turnNumber: i32 = 1;

pub fn switchTurn(to: CurrentTurnEnum) void {
    if (to == .player) {
        turnNumber += 1;
    }
    currentTurn = to;
}

pub fn update(game: *Game.Game) !void {
    switch (currentTurn) {
        .player => {},
        .enemy => {},
    }
}
