const Game = @import("../game/game.zig");
const EntityManager = @import("../game/entityManager.zig");
const Entity = @import("../game/entity.zig");
const std = @import("std");

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

pub var updatingEntity: ?u32 = null;

pub var enemyQueue: std.ArrayList(u32) = undefined;
var enemyQueueIndex: u32 = 0;

pub fn init(allocator: std.mem.Allocator) void {
    enemyQueue = std.ArrayList(u32).init(allocator);
}

pub fn update(game: *Game.Game) !void {
    switch (phase) {
        .setup => {
            std.debug.print("setup\n", .{});

            for (EntityManager.entities.items) |e| {
                if (e.data == .enemy) {
                    try enemyQueue.append(e.id);
                }
            }

            // setup done
            phase = .acting;
        },
        .acting => {
            switch (turn) {
                .player => try updatePlayerTurn(game),
                .enemy => try updateEnemyTurn(game),
            }
        },
        .cleanup => {
            std.debug.print("cleanup\n", .{});
            EntityManager.resetTurnFlags(); //TODO: might need reset it by entitiesOutCombat etc.

            enemyQueueIndex = 0;

            enemyQueue.clearRetainingCapacity();

            switchTurn(.player);
            phase = .setup;
        },
    }
}

fn updatePlayerTurn(game: *Game.Game) !void {
    if (updatingEntity) |id| {
        var entity = EntityManager.getEntityID(id) orelse {
            updatingEntity = null;
            return;
        };

        try entity.update(game);

        if (entity.turnTaken) {
            updatingEntity = null;

            if (EntityManager.allPlayerUnitsTurnTaken()) {
                switchTurn(.enemy);
            }
        }
    }
}
fn updateEnemyTurn(game: *Game.Game) !void {
    if (enemyQueueIndex >= enemyQueue.items.len) {
        phase = .cleanup;
        return;
    }

    // if (EntityManager.allEnemiesTurnTaken()) {
    //     turn = .player;
    //     return;
    // }

    const entityID = enemyQueue.items[enemyQueueIndex];
    const entity = EntityManager.getEntityID(entityID) orelse {
        enemyQueueIndex += 1;
        return;
    };

    if (entity.data != .enemy) {
        enemyQueueIndex += 1;
        return;
    }

    updatingEntity = entity.id;
    try entity.update(game);
    if (entity.turnTaken) {
        updatingEntity = null;
        enemyQueueIndex += 1;
    }
}

pub fn switchTurn(to: TurnEnum) void {
    if (to == .player) {
        turnNumber += 1;
    }
    turn = to;
}
