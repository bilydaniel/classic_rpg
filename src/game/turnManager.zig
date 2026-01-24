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
var updatingEntity: ?*Entity.Entity = null;

//TODO: swap arraylist for a ring buffer queue
pub var entitiesInCombat: std.ArrayList(u32) = undefined;
var entitiesInCombatIndex: u32 = 0;

pub var entitiesOutCombat: std.ArrayList(u32) = undefined;
var entitiesOutCombatIndex: u32 = 0;

pub fn init(allocator: std.mem.Allocator) void {
    entitiesInCombat = std.ArrayList(u32).init(allocator);
    entitiesOutCombat = std.ArrayList(u32).init(allocator);
}

pub fn update(game: *Game.Game) !void {
    switch (phase) {
        .setup => {
            std.debug.print("setup\n", .{});
            //TODO: figure out the order of entities
            for (EntityManager.entities.items) |e| {
                if (e.inCombat) {
                    try entitiesInCombat.append(e.id);
                } else {
                    if (e.data == .player or e.data == .enemy) {
                        try entitiesOutCombat.append(e.id);
                    }
                }
            }

            // setup done
            phase = .acting;
        },
        .acting => {
            if (game.player.turnTaken) {
                turn = .enemy;
            } else if (EntityManager.allEnemiesTurnTaken()) {
                turn = .player;
            }

            std.debug.assert(!(entitiesOutCombat.items.len == 0 and entitiesInCombat.items.len == 0));
            //combat first
            if (entitiesInCombat.items.len > 0) {
                if (entitiesInCombatIndex <= entitiesInCombat.items.len - 1) {
                    if (updatingEntity == null) {
                        const entity = EntityManager.getEntityID(entitiesInCombat.items[entitiesInCombatIndex]);
                        if (entity) |e| {
                            updatingEntity = e;
                        } else {
                            entitiesInCombatIndex += 1;
                        }
                    }

                    if (updatingEntity) |e| {
                        try e.update(game);
                        if (e.turnTaken) {
                            updatingEntity = null;
                            entitiesInCombatIndex += 1;
                        }
                    }
                }
            }

            //non combat second
            if (entitiesOutCombat.items.len > 0) {
                if (entitiesInCombat.items.len == 0 or entitiesInCombatIndex > entitiesInCombat.items.len - 1) {
                    if (entitiesOutCombatIndex <= entitiesOutCombat.items.len - 1) {
                        if (updatingEntity == null) {
                            const entity = EntityManager.getEntityID(entitiesOutCombat.items[entitiesOutCombatIndex]);
                            if (entity) |e| {
                                updatingEntity = e;
                            } else {
                                entitiesOutCombatIndex += 1;
                            }
                        }

                        if (updatingEntity) |e| {
                            try e.update(game);
                            if (e.turnTaken) {
                                updatingEntity = null;
                                entitiesOutCombatIndex += 1;
                            }
                        }
                    }
                }
            }

            std.debug.print("c_i: {}\n", .{entitiesInCombatIndex});
            std.debug.print("c_l: {}\n", .{entitiesInCombat.items.len});
            std.debug.print("n_i: {}\n", .{entitiesOutCombatIndex});
            std.debug.print("n_l: {}\n", .{entitiesOutCombat.items.len});
            std.debug.print("****************************\n", .{});

            if (entitiesOutCombatIndex >= entitiesOutCombat.items.len and entitiesInCombatIndex >= entitiesInCombat.items.len) {
                phase = .cleanup;
            }
        },
        .cleanup => {
            std.debug.print("cleanup\n", .{});
            EntityManager.resetTurnFlags(); //TODO: might need reset it by entitiesOutCombat etc.

            entitiesOutCombatIndex = 0;
            entitiesInCombatIndex = 0;

            entitiesOutCombat.clearRetainingCapacity();
            entitiesInCombat.clearRetainingCapacity();

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
