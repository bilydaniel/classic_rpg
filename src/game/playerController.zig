const Config = @import("../common/config.zig");
const Utils = @import("../common/utils.zig");
const World = @import("world.zig");
const Combat = @import("combat.zig");
const Movement = @import("movement.zig");
const CameraManager = @import("cameraManager.zig");
const Entity = @import("entity.zig");
const Gamestate = @import("gamestate.zig");
const Level = @import("level.zig");
const Types = @import("../common/types.zig");
const std = @import("std");
const Pathfinder = @import("../game/pathfinder.zig");
const InputManager = @import("../game/inputManager.zig");
const TurnManager = @import("../game/turnManager.zig");
const Game = @import("game.zig");
const ShaderManager = @import("shaderManager.zig");
const EntityManager = @import("entityManager.zig");
const UiManager = @import("../ui/uiManager.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub var state: playerStateEnum = undefined;

pub const playerStateEnum = enum {
    walking,
    deploying_puppets,
    in_combat,
};

pub fn init() void {
    state = .walking;
}

pub fn update(game: *Game.Game) void {
    if (game.player.data != .player) {
        return;
    }
    const playerData = game.player.data.player;
    var nextState = state;
    const currState = state;
    switch (currState) {
        .walking => {
            //TODO: check if enemies are around, if it makes sense to even go to combat
            if (UiManager.getCombatToggle()) {
                nextState = .deploying_puppets;
            }

            //TODO: probably should only check when moved
            if (Combat.checkCombatStart(game.player, EntityManager.entities)) {
                nextState = .deploying_puppets;
            }
        },
        .deploying_puppets => {
            if (UiManager.getCombatToggle()) {
                nextState = .walking;
            }

            if (playerData.allPupsDeployed()) {
                nextState = .in_combat;
            }
        },
        .in_combat => {
            if (UiManager.getCombatToggle()) {
                //TODO: check can end combat?
                nextState = .walking;
            }

            if (playerData.inCombatWith.items.len == 0) {
                nextState = .walking;
            }
        },
    }

    //
    // TRANSITION
    //
    if (currState != nextState) {

        //switching from a state
        switch (currState) {
            //not needed for now
            .walking => {},
            .deploying_puppets => {},
            .in_combat => {},
        }

        //swithing to a state
        switch (nextState) {
            .walking => {
                Gamestate.reset();
                game.player.endCombat();
                Gamestate.showMenu = .none;
            },
            .deploying_puppets => {
                //TODO: filter out entities that are supposed to be in the combat
                // could be some mechanic around attention/stealth
                // smarter entities shout at other to help etc...

                game.player.inCombat = true;
                for (EntityManager.entities.items) |*entity| {
                    try playerData.inCombatWith.append(entity.id);
                    entity.resetPathing();
                    entity.inCombat = true;
                }
            },
            .in_combat => {
                Gamestate.reset();
                Gamestate.showMenu = .none;
                game.player.movementCooldown = 0;
            },
        }

        playerData.state = nextState;
    }

    switch (state) {
        .walking => {
            try handlePlayerWalking(game);
        },
        .deploying_puppets => {
            try handlePlayerDeploying(game);
        },
        .in_combat => {
            try handlePlayerCombat(game);
        },
    }
}

pub fn handlePlayerWalking(game: *Game.Game) !void {
    //TODO: @refactor what should i move into the player update??
    game.player.movementCooldown += game.delta;
    if (game.player.movementCooldown < Config.movement_animation_duration) {
        return;
    }

    const skipMove = UiManager.getSkip();
    const moveDelta = UiManager.getMove();
    if (skipMove == false and moveDelta == null) {
        return;
    }
    if (skipMove) {
        game.player.movementCooldown = 0;
        game.player.turnTaken = true;
        return;
    }

    var new_pos = Types.vector2IntAdd(game.player.pos, moveDelta.?);
    const grid = World.getCurrentLevel().grid;
    const entities = EntityManager.entities;
    if (!Movement.canMove(new_pos, grid, entities)) {
        return;
    }

    //TODO: only staircase for now, add boundry transitions
    new_pos = staircaseTransition(new_pos);

    game.player.move(new_pos);
    game.player.movementCooldown = 0;
    game.player.turnTaken = true;
}
