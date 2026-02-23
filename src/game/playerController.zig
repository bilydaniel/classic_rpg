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
var allocator: std.mem.Allocator = undefined;

pub const playerStateEnum = enum {
    walking,
    deploying_puppets,
    in_combat,
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
            },
            .deploying_puppets => {
                //TODO: filter out entities that are supposed to be in the combat
                // could be some mechanic around attention/stealth
                // smarter entities shout at other to help etc...

                game.player.inCombat = true;
                for (EntityManager.entities.items) |*entity| {
                    //TODO: all enemies for now
                    if (entity.data == .enemy) {
                        try playerData.inCombatWith.append(allocator, entity.id);
                        entity.resetPathing();
                        entity.inCombat = true;
                    }
                }
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

    var grid = World.getCurrentLevel().grid;
    const entityPosHash = EntityManager.positionHash;

    //TODO: @test the broundry transition and staircase
    newLocation = Movement.boundryTransition(newLocation);
    newLocation = Movement.staircaseTransition(newLocation, grid);

    const changingLevel = !Types.vector3IntCompare(currentLocation.worldPos, newLocation.worldPos);
    if (changingLevel) {
        const newLevel = World.getLevelAt(newLocation.worldPos);
        if (newLevel) |l| {
            grid = l.grid;
        }
    }

    if (!Movement.canMove(newLocation, grid, &entityPosHash)) {
        //TODO: print to the player he cant move
        return;
    }

    if (changingLevel) {
        World.changeCurrentLevel(newLocation.worldPos);
    }
    try game.player.move(newLocation);
    game.player.movementCooldown = 0;
    game.player.turnTaken = true;
}

pub fn handlePlayerDeploying(game: *Game.Game) !void {
    //
    // puppet select
    //
    if (Gamestate.selectedPupId == null) {
        Gamestate.showMenu = .puppet_select;

        if (UiManager.getMenuSelect()) |menu_item| {
            switch (menu_item) {
                .puppet_id => |pid| {
                    Gamestate.selectedPupId = pid;
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
    if (Gamestate.selectedPupId) |selected_pup| {
        Gamestate.showMenu = .none;
        Gamestate.makeUpdateCursor(game.player.pos);

        //TODO: put deploycells / highlight  into function
        if (Gamestate.deployableCells == null) {
            const neighbours = Movement.neighboursAll(game.player.pos);
            Gamestate.deployableCells = neighbours;
        }
        if (Gamestate.deployableCells) |cells| {
            if (!Gamestate.deployHighlighted) {
                for (cells) |value| {
                    if (value) |val| {
                        try Gamestate.highlightTile(val);
                        Gamestate.deployHighlighted = true;
                    }
                }
            }
        }
        if (UiManager.getConfirm()) {
            if (canDeploy(game.player)) {
                if (Gamestate.cursor) |curs| {
                    const worldPos = World.getCurrentLevel().worldPos;
                    const location = Types.Location.init(worldPos, curs);
                    try deployPuppet(selected_pup, location);
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
    UiManager.resetActiveMenuIndex();
    //TODO: reset the active menu index
    if (entityIndex == 0) {
        //Player
        Gamestate.selectedEntityID = game.player.id;
    } else {
        //Puppets
        if (game.player.data.player.puppets.items.len >= entityIndex) {
            const pupID = game.player.data.player.puppets.items[entityIndex - 1];
            Gamestate.selectedEntityID = pupID;
        }
    }

    if (Gamestate.selectedEntityID) |id| {
        const selectedEntity = EntityManager.getEntityID(id);
        if (selectedEntity) |se| {
            CameraManager.targetEntity = id;
            Gamestate.removeCursor();
            Gamestate.highlightEntity(se.pos);
            Gamestate.selectedAction = null;
        }
    }
}

pub fn entityAction(game: *Game.Game) !void {
    if (Gamestate.selectedEntityID) |id| {
        const selectedEntity = EntityManager.getEntityID(id);
        if (selectedEntity) |entity| {
            if (Gamestate.selectedAction == null) {
                Gamestate.showMenu = .action_select;

                if (UiManager.getMenuSelect()) |menu_item| {
                    switch (menu_item) {
                        .puppet_id => {
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
            const entityPosHash = EntityManager.positionHash;

            switch (selectedAction) {
                .move => {
                    Gamestate.showMenu = .none;
                    Gamestate.makeUpdateCursor(entity.pos);
                    try Gamestate.highlightMovement(entity);

                    if (UiManager.getConfirm()) {
                        if (Gamestate.cursor) |cur| {
                            const level = World.getCurrentLevel();
                            const location = Types.Location.init(level.worldPos, cur);
                            if (Gamestate.isinMovable(cur) and Movement.canMove(location, grid, &entityPosHash)) {
                                entity.path = try Pathfinder.findPath(entity.pos, cur, level.*, &entityPosHash);

                                TurnManager.updatingEntity = entity.id;

                                Gamestate.resetMovementHighlight();
                                Gamestate.removeCursor();
                                Gamestate.selectedAction = null;
                            }
                        }
                    }

                    if (c.IsKeyPressed(c.KEY_SPACE)) {
                        //TODO: manage state after skip
                        skipMovement();
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
                                const attackedEntity = EntityManager.getEntityByPos(cur, World.currentLevel);
                                try ShaderManager.spawnSlash(entity.pos, cur);
                                try ShaderManager.spawnImpact(cur);

                                attack(game, entity, attackedEntity);

                                entity.hasAttacked = true;

                                //cant move after attack
                                entity.hasMoved = true;

                                TurnManager.updatingEntity = entity.id;

                                Gamestate.resetAttackHighlight();
                                Gamestate.removeCursor();
                                Gamestate.selectedAction = null;
                            }
                        }
                    }

                    if (c.IsKeyPressed(c.KEY_SPACE)) {
                        //TODO: manage state after skip
                        skipAttack();
                    }
                },
            }
        }
    }
}

//TODO: put somewhere else?
pub fn canDeploy(player: *Entity.Entity) bool {
    //TODO: @refactor change the api
    const deploy_pos = Gamestate.cursor;
    if (deploy_pos) |dep_pos| {
        if (Types.vector2IntCompare(player.pos, dep_pos)) {
            return false;
        }

        const entity = EntityManager.getEntityByPos(dep_pos, World.currentLevel);
        if (entity) |_| {
            return false;
        }

        const grid = World.getCurrentLevel().grid;
        if (!Movement.isTileWalkable(grid, dep_pos)) {
            return false;
        }

        if (Gamestate.deployableCells) |deployable_cells| {
            if (!isDeployable(dep_pos, &deployable_cells)) {
                return false;
            }
        }

        return true;
    }
    return false;
}

pub fn deployPuppet(pupId: u32, location: Types.Location) !void {
    const puppet = EntityManager.getEntityID(pupId);
    if (puppet) |pup| {
        try pup.move(location);

        pup.data.puppet.deployed = true;
        pup.visible = true;
        //TODO: @check if correct
        pup.inCombat = true;
        Gamestate.selectedPupId = null; //TODO: maybe wrong, check

        try EntityManager.activateEntity(pupId);

        return;
    }
}

pub fn isDeployable(pos: Types.Vector2Int, cells: []const ?Types.Vector2Int) bool {
    for (cells) |cell| {
        if (cell) |cell_| {
            if (Types.vector2IntCompare(pos, cell_)) {
                return true;
            }
        }
    }
    return false;
}

pub fn skipMovement() void {
    if (Gamestate.selectedEntity) |entity| {
        entity.hasMoved = true;
    }
    Gamestate.resetMovementHighlight();
    Gamestate.removeCursor();
    Gamestate.selectedAction = null;
}

pub fn skipAttack() void {
    if (Gamestate.selectedEntity) |entity| {
        entity.hasAttacked = true;
    }
    Gamestate.resetAttackHighlight();
    Gamestate.removeCursor();
    Gamestate.selectedAction = null;
}

//TODO: @refactor probably a combat file or something
pub fn attack(game: *Game.Game, entity: *Entity.Entity, attackedEntity: ?*Entity.Entity) void {
    _ = game;
    if (attackedEntity) |attacked_entity| {
        attacked_entity.health -= entity.attack;
    } else {}
}
