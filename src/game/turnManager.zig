const Game = @import("../game/game.zig");
const EntityManager = @import("../game/entityManager.zig");
const CameraManager = @import("../game/cameraManager.zig");
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

var allocator: std.mem.Allocator = undefined;

pub fn init(alloc: std.mem.Allocator) void {
    enemyQueue = std.ArrayList(u32).empty;
    allocator = alloc;
}

pub fn update(game: *Game.Game) !void {
    switch (phase) {
        .setup => {
            std.debug.print("setup\n", .{});

            for (EntityManager.entities.items) |e| {
                if (e.data == .enemy) {
                    try enemyQueue.append(allocator, e.id);
                }
            }
            //TODO: order enemies, some heuristic(distance to goal)

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
            //TODO: remove all the dead entities here so i dont fuck up any pointers during the update
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
    if (EntityManager.allPlayerUnitsTurnTaken()) {
        switchTurn(.enemy);
        return;
    }

    if (updatingEntity) |id| {
        CameraManager.targetEntity = id;
        var entity = EntityManager.getEntityID(id) orelse {
            updatingEntity = null;
            return;
        };

        try entity.update(game);

        if (entity.turnTaken) {
            updatingEntity = null;
        }
    }
}
fn updateEnemyTurn(game: *Game.Game) !void {
    //TODO: entities in combat need to be updated through updatingEntity
    if (enemyQueueIndex >= enemyQueue.items.len) {
        phase = .cleanup;
        return;
    }

    if (updatingEntity) |id| {
        CameraManager.targetEntity = id;
        var entity = EntityManager.getEntityID(id) orelse {
            updatingEntity = null;
            enemyQueueIndex += 1;
            return;
        };

        try entity.update(game);

        if (entity.turnTaken) {
            updatingEntity = null;
            enemyQueueIndex += 1;
        }
        return;
    }

    const entityID = enemyQueue.items[enemyQueueIndex];
    const entity = EntityManager.getEntityID(entityID) orelse {
        enemyQueueIndex += 1;
        return;
    };

    if (entity.data != .enemy) {
        enemyQueueIndex += 1;
        return;
    }

    if (entity.inCombat) {
        updatingEntity = entity.id;
    } else {
        try entity.update(game);
        if (entity.turnTaken) {
            enemyQueueIndex += 1;
        }
    }
}

pub fn switchTurn(to: TurnEnum) void {
    if (to == .player) {
        turnNumber += 1;
    }
    turn = to;
}
