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
const Systems = @import("Systems.zig");
const UiManager = @import("../ui/uiManager.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub var state: playerStateEnum = undefined;
var allocator: std.mem.Allocator = undefined;

pub const playerStateEnum = enum {
    walking,
    deploying_puppets,
    in_combat,
};

pub const DeployPhase = enum {
    selecting_puppet,
    selecting_position,
};

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;
    state = .walking;
}

pub fn update(game: *Game.Game) !void {
    //TODO: figure out what happens if i dont have any puppet, wasnt possible before, now it is
    if (game.player.data != .player) {
        return;
    }

    if (TurnManager.updatingEntity != null) {
        return;
    }

    var playerData = &game.player.data.player;
    var nextState = state;
    const currState = state;
    switch (currState) {
        .walking => {
            //TODO: check if enemies are around, if it makes sense to even go to combat
            if (UiManager.getCombatToggle()) {
                nextState = .deploying_puppets;
            }

            //TODO: probably should only check when moved
            if (Combat.checkCombatStart(game.player)) {
                //nextState = .deploying_puppets;
            }
        },
        .deploying_puppets => {
            if (UiManager.getCombatToggle()) {
                //TODO: @fix, bricks pretty much everithing
                nextState = .walking;
            }

            if (playerData.allPupsDeployed()) {
                nextState = .in_combat;
            }
        },
        .in_combat => {
            if (UiManager.getCombatToggle()) {
                //TODO: @fix, bricks pretty much everithing
                //TODO: check can end combat?
                nextState = .walking;
            }

            //TODO: @fix check this condition when deploying works
            if (playerData.inCombatWith.items.len == 0) {
                nextState = .walking;
            }

            // in combat with isnt filled yet, if deploying
            // if (currState != .deploying_puppets and playerData.inCombatWith.items.len == 0) {
            //     nextState = .walking;
            // }
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
                try EntityManager.deactivatePuppets();

                //TODO: make function
                TurnManager.updatingEntity = null;
                TurnManager.switchTurn(.player);
                TurnManager.phase = .setup;
                TurnManager.enemyQueue.clearRetainingCapacity();
                TurnManager.enemyQueueIndex = 0;
                EntityManager.resetTurnFlags();

                var iterator = EntityManager.activeIterator(0);
                while (iterator.next()) |entity| {
                    if (entity.data == .enemy) {
                        entity.inCombat = false;
                        entity.resetPathing();
                    }
                }

                CameraManager.targetEntity = EntityManager.playerHandle;
            },
            .deploying_puppets => {
                TurnManager.switchTurn(.player);
                EntityManager.resetTurnFlags();

                //TODO: filter out entities that are supposed to be in the combat
                // could be some mechanic around attention/stealth
                // smarter entities shout at other to help etc...

                //TODO: @fix enemies seem to go before player

                game.player.inCombat = true;
                var iterator = EntityManager.entities.iterator(0);
                while (iterator.next()) |slot| {
                    if (!slot.occupied) {
                        continue;
                    }
                    //TODO: test out, not sure if the pointer to entity works
                    var entity = &slot.entity;
                    //TODO: all enemies for now
                    if (entity.data == .enemy) {
                        //TODO: probably should make it into a static array, like 10 elements if way more then enough
                        const handle = EntityManager.Handle.init(entity.index, slot.generation);
                        try playerData.inCombatWith.append(allocator, handle);
                        entity.resetPathing();
                        entity.inCombat = true;
                    }
                }

                game.player.turnTaken = false;
                game.player.hasMoved = false;
                //TODO: @fix @continue reset turn taken for puppets?
            },
            .in_combat => {
                Gamestate.reset();
                Gamestate.showMenu = .none;
                EntityManager.resetTurnFlags();
                game.player.movementCooldown = 0;
            },
        }
        state = nextState;
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

    const currentLocation = Types.Location.init(game.player.worldPos, game.player.pos);
    var newLocation = Types.Location.init(game.player.worldPos, game.player.pos);
    newLocation.pos = Types.vector2IntAdd(newLocation.pos, moveDelta.?);

    var level = World.getCurrentLevel();

    //TODO: @test the broundry transition and staircase
    newLocation = Movement.boundryTransition(currentLocation, newLocation);
    newLocation = Movement.staircaseTransition(newLocation, level);

    const changingLevel = !Types.vector3IntCompare(currentLocation.worldPos, newLocation.worldPos);
    if (changingLevel) {
        //TODO: do proper level swap
        const newLevel = World.getLevelAt(newLocation.worldPos);
        if (newLevel) |l| {
            level = l;
        }
    }

    if (!Movement.canMove(newLocation.pos, level.grid)) {
        //TODO: print to the player he cant move
        return;
    }

    if (changingLevel) {
        World.changeCurrentLevel(newLocation.worldPos);
        try game.player.moveLevel(newLocation);
    } else {
        try game.player.move(level, newLocation.pos);
    }
    //TODO: moving between levels no work
    game.player.movementCooldown = 0;
    game.player.turnTaken = true;
}

// https://gemini.google.com/app/20a4973dde216575
pub fn handlePlayerDeploying(game: *Game.Game) !void {
    //
    // puppet select
    //
    //TODO: should i switch to DeployPhase enum?
    if (Gamestate.selectedPupHandle == null) {
        Gamestate.showMenu = .puppet_select;

        if (UiManager.getMenuSelect()) |menu_item| {
            std.debug.print("menu_item: {}\n", .{menu_item});
            switch (menu_item) {
                .puppet_handle => |handle| {
                    Gamestate.selectedPupHandle = handle;
                },
                .action => {
                    std.debug.print("menu_item is .action instead of .puppet_id", .{});
                },
            }
        }
    }

    //
    // puppet deploy
    //
    //TODO: probably refactor the whole deploying logic, do i need deployable cells?
    if (Gamestate.selectedPupHandle) |selected_pup| {
        Gamestate.showMenu = .none;
        Gamestate.makeUpdateCursor(game.player.pos);

        //TODO: put deploycells / highlight  into function
        if (Gamestate.deployableCells.items.len == 0) {
            try Systems.neighboursDistance(game.player.pos, game.player.data.player.deployDistance, &Gamestate.deployableCells);
        }
        if (Gamestate.deployableCells.items.len > 0 and !Gamestate.deployHighlighted) {
            for (Gamestate.deployableCells.items) |cell| {
                try Gamestate.highlightTile(cell);
                Gamestate.deployHighlighted = true;
            }
        }

        if (UiManager.getConfirm()) {
            //TODO: @finish @continue @refactor deployable cells, more than 8
            if (Gamestate.cursor) |curs| {
                const level = World.getCurrentLevel();
                if (canDeploy(curs, level, Gamestate.deployableCells)) {
                    try deployPuppet(selected_pup, curs, level);
                }
            }
        }
    }
}

pub fn handlePlayerCombat(game: *Game.Game) !void {
    switch (TurnManager.turn) {
        .player => {
            entitySelect(game);
            try entityAction(game);
        },

        .enemy => {},
    }
}

pub fn entitySelect(game: *Game.Game) void {
    const entityIndex = UiManager.getQuickSelect() orelse return;

    Gamestate.resetMovementHighlight();
    Gamestate.resetAttackHighlight();
    //UiManager.resetActiveMenuIndex();
    //TODO: reset the active menu index
    if (entityIndex == 0) {
        //Player
        Gamestate.selectedEntityHandle = EntityManager.playerHandle;
    } else {
        //Puppets
        if (game.player.data.player.puppets.items.len >= entityIndex) {
            const pupID = game.player.data.player.puppets.items[entityIndex - 1];
            Gamestate.selectedEntityHandle = pupID;
        }
    }

    if (Gamestate.selectedEntityHandle) |handle| {
        const selectedEntity = EntityManager.getEntityHandle(handle);
        if (selectedEntity) |se| {
            CameraManager.targetEntity = handle;
            Gamestate.removeCursor();
            Gamestate.highlightEntity(se.pos);
            Gamestate.selectedAction = null;
        }
    }
}

pub fn entityAction(game: *Game.Game) !void {
    _ = game;
    if (Gamestate.selectedEntityHandle) |handle| {
        const selectedEntity = EntityManager.getEntityHandle(handle);
        if (selectedEntity) |entity| {
            if (Gamestate.selectedAction == null) {
                Gamestate.showMenu = .action_select;

                if (UiManager.getMenuSelect()) |menu_item| {
                    switch (menu_item) {
                        .puppet_handle => {
                            std.debug.print("menu_item is .puppet_id instead of .action", .{});
                        },
                        .action => |action| {
                            Gamestate.selectedAction = action;
                        },
                    }
                }
            }
            const selectedAction = Gamestate.selectedAction orelse return;

            const grid = World.getCurrentLevel().grid;

            const level = World.getCurrentLevel();
            switch (selectedAction) {
                .move => {
                    Gamestate.showMenu = .none;
                    Gamestate.makeUpdateCursor(entity.pos);
                    try Gamestate.highlightMovement(entity);

                    if (UiManager.getConfirm()) {
                        if (Gamestate.cursor) |cur| {
                            if (Gamestate.isinMovable(cur) and Movement.canMove(cur, grid)) {
                                const newPath = try Pathfinder.findPath(entity.pos, cur, level);
                                if (newPath) |np| {
                                    entity.setNewPath(np);
                                }

                                TurnManager.updatingEntity = handle;

                                Gamestate.resetMovementHighlight();
                                Gamestate.removeCursor();
                                Gamestate.selectedAction = null;
                            }
                        }
                    }

                    if (c.IsKeyPressed(c.KEY_SPACE)) {
                        skipMovement(entity);
                    }
                },
                .attack => {
                    Gamestate.showMenu = .none;
                    Gamestate.makeUpdateCursor(entity.pos);
                    try Gamestate.highlightAttack(entity);

                    if (UiManager.getConfirm()) {
                        if (Gamestate.cursor) |cur| {
                            if (Gamestate.isinAttackable(cur)) {
                                //TODO: maybe gonna make some attack animation / resolving similar
                                // to movement
                                const attackedEntity = level.getEntityByPos(cur);
                                try ShaderManager.spawnSlash(entity.pos, cur);
                                try ShaderManager.spawnImpact(cur);

                                try Combat.attack(entity, attackedEntity);

                                entity.hasAttacked = true;

                                //cant move after attack
                                entity.hasMoved = true;

                                TurnManager.updatingEntity = handle;

                                Gamestate.resetAttackHighlight();
                                Gamestate.removeCursor();
                                Gamestate.selectedAction = null;
                            }
                        }
                    }

                    if (c.IsKeyPressed(c.KEY_SPACE)) {
                        //TODO: manage state after skip
                        //TODO: @fix, skipping doesent work
                        skipAttack(entity);
                    }
                },
                .skip_turn => {
                    Gamestate.showMenu = .none;
                    entity.hasAttacked = true;
                    entity.hasMoved = true;
                    entity.turnTaken = true;
                    Gamestate.selectedAction = null;
                },
            }
        }
    }
}

//TODO: put somewhere else?
pub fn canDeploy(deployPos: Types.Vector2Int, level: *Level.Level, deployableCells: std.ArrayList(Types.Vector2Int)) bool {
    if (deployableCells.items.len == 0) {
        return false;
    }

    if (!Movement.canMove(deployPos, level.grid)) {
        return false;
    }

    if (!isDeployable(deployPos, deployableCells)) {
        return false;
    }

    return true;
}

pub fn deployPuppet(pupHandle: EntityManager.Handle, pos: Types.Vector2Int, level: *Level.Level) !void {
    _ = level;
    const puppet = EntityManager.getEntityHandle(pupHandle);
    if (puppet) |pup| {
        try pup.forceMove(pos);

        pup.data.puppet.deployed = true;
        pup.visible = true;
        //TODO: @check if correct
        pup.inCombat = true;
        Gamestate.selectedPupHandle = null; //TODO: maybe wrong, check

        try EntityManager.activateEntity(pupHandle);
        Systems.calculateFOV(pos, 8);

        return;
    }
}

pub fn isDeployable(pos: Types.Vector2Int, cells: std.ArrayList(Types.Vector2Int)) bool {
    for (cells.items) |cell| {
        if (Types.vector2IntCompare(pos, cell)) {
            return true;
        }
    }
    return false;
}

pub fn skipMovement(entity: *Entity.Entity) void {
    entity.hasMoved = true;

    Gamestate.resetMovementHighlight();
    Gamestate.removeCursor();
    Gamestate.selectedAction = null;
}

pub fn skipAttack(entity: *Entity.Entity) void {
    entity.hasAttacked = true;
    entity.hasMoved = true;
    entity.turnTaken = true;

    Gamestate.resetAttackHighlight();
    Gamestate.removeCursor();
    Gamestate.selectedAction = null;
}
