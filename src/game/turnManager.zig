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
var updatingEntity: ?u32 = null;

//TODO: swap arraylist for a ring buffer queue
pub var entityQueue: std.ArrayList(u32) = undefined;
var entityQueueIndex: u32 = 0;

pub fn init(allocator: std.mem.Allocator) void {
    entityQueue = std.ArrayList(u32).init(allocator);
}

pub fn update(game: *Game.Game) !void {
    switch (phase) {
        .setup => {
            std.debug.print("setup\n", .{});
            //TODO: figure out the order of entities
            // combat entities update first
            for (EntityManager.entities.items) |e| {
                if (e.inCombat) {
                    try entityQueue.append(e.id);
                }
            }

            for (EntityManager.entities.items) |e| {
                if (!e.inCombat) {
                    try entityQueue.append(e.id);
                }
            }

            // setup done
            phase = .acting;
        },
        .acting => {
            if (entityQueueIndex >= entityQueue.items.len) {
                phase = .cleanup;
                return;
            }

            if (game.player.turnTaken) {
                turn = .enemy;
            } else if (EntityManager.allEnemiesTurnTaken()) {
                turn = .player;
            }

            //TODO: @fix
            //if i try to move a puppe as first it
            //doesent move, because the player
            //is first in the queue and so the
            //puppet cant move
            if (updatingEntity) |id| {
                var entity = EntityManager.getEntityID(id) orelse return;

                try entity.update(game);
                if (entity.turnTaken) {
                    updatingEntity = null;
                    entityQueueIndex += 1;
                }
            } else {
                if (turn == .player) {
                    //TODO: probably just copy selected entity?
                } else {
                    //TODO: separate queue for enemies??
                }
                const entityID = entityQueue.items[entityQueueIndex];
                const entity = EntityManager.getEntityID(entityID) orelse {
                    entityQueueIndex += 1;
                    return;
                };
                updatingEntity = entity.id;
            }
        },
        .cleanup => {
            std.debug.print("cleanup\n", .{});
            EntityManager.resetTurnFlags(); //TODO: might need reset it by entitiesOutCombat etc.

            entityQueueIndex = 0;

            entityQueue.clearRetainingCapacity();

            switchTurn(.player);
            phase = .setup;
        },
    }
}

pub fn switchTurn(to: TurnEnum) void {
    if (to == .player) {
        turnNumber += 1;
    }
    turn = to;
}
