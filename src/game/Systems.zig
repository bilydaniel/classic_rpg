const Config = @import("../common/config.zig");
const Utils = @import("../common/utils.zig");
const World = @import("world.zig");
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
const Movement = @import("movement.zig");
const ShaderManager = @import("shaderManager.zig");
const EntityManager = @import("entityManager.zig");
const UiManager = @import("../ui/uiManager.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

//TODO: refactor this file, split into more / better files
//TODO: add an optiom to "look around", get info on enemies, etc.
// TODO: go through all the state management, make some fool proof system
// of writing the state transitions / resets of variables

// pub fn updatePlayer(game: *Game.Game) !void {
//
//     if (TurnManager.turn != .player) {
//         return;
//     }
//     //
//     // FIND NEXT STATE
//     //
//     std.debug.assert(game.player.data == .player);
//     const playerData = &game.player.data.player;
//     var nextState = playerData.state;
//     const currState = playerData.state;
//     switch (currState) {
//         .walking => {
//             //TODO: check if enemies are around, if it makes sense to even go to combat
//             if (UiManager.getCombatToggle()) {
//                 nextState = .deploying_puppets;
//             }
//
//             //TODO: probably should only check when moved
//             if (checkCombatStart(game.player, EntityManager.entities)) {
//                 nextState = .deploying_puppets;
//             }
//         },
//         .deploying_puppets => {
//             if (UiManager.getCombatToggle()) {
//                 nextState = .walking;
//             }
//
//             if (game.player.data.player.allPupsDeployed()) {
//                 nextState = .in_combat;
//             }
//         },
//         .in_combat => {
//             if (UiManager.getCombatToggle()) {
//                 //TODO: check can end combat?
//                 nextState = .walking;
//             }
//
//             if (game.player.data.player.inCombatWith.items.len == 0) {
//                 nextState = .walking;
//             }
//         },
//     }
//
//     //
//     // TRANSITION
//     //
//     if (currState != nextState) {
//
//         //switching from a state
//         switch (currState) {
//             //not needed for now
//             .walking => {},
//             .deploying_puppets => {},
//             .in_combat => {},
//         }
//
//         //swithing to a state
//         switch (nextState) {
//             .walking => {
//                 Gamestate.reset(); //TODO: make more reset functions depending on the state?
//                 game.player.endCombat();
//                 Gamestate.showMenu = .none;
//             },
//             .deploying_puppets => {
//                 //TODO: filter out entities that are supposed to be in the combat
//                 // could be some mechanic around attention/stealth
//                 // smarter entities shout at other to help etc...
//
//                 game.player.inCombat = true;
//                 for (EntityManager.entities.items) |*entity| {
//                     try game.player.data.player.inCombatWith.append(entity.id);
//                     entity.resetPathing();
//                     entity.inCombat = true;
//                 }
//             },
//             .in_combat => {
//                 Gamestate.reset();
//                 Gamestate.showMenu = .none;
//                 game.player.movementCooldown = 0;
//             },
//         }
//
//         playerData.state = nextState;
//     }
//
//     switch (playerData.state) {
//         .walking => {
//             try handlePlayerWalking(game);
//         },
//         .deploying_puppets => {
//             try handlePlayerDeploying(game);
//         },
//         .in_combat => {
//             try handlePlayerCombat(game);
//         },
//     }
//
//     if (TurnManager.turn != .player) {
//         return;
//     }
//
//     //std.debug.print("goal: {?}\n", .{game.player.goal});
//     try updateEntityMovement(game.player, game);
// }

pub fn getEntityById(entities: std.ArrayList(*Entity.Entity), id: u32) ?*Entity.Entity {
    for (entities.items) |entity| {
        if (entity.id == id) {
            return entity;
        }
    }
    return null;
}

pub fn calculateFOV(center: Types.Vector2Int, radius: usize) void {
    var grid = World.getCurrentLevel().grid;
    var idx: usize = 0;
    while (idx < grid.len) : (idx += 1) {
        grid[idx].visible = false;
    }

    const rays = radius * 8;
    var i: i32 = 0;
    while (i < rays) : (i += 1) {
        const angle = @as(f32, @floatFromInt(i)) * (2.0 * std.math.pi) / @as(f32, @floatFromInt(rays));

        const target = Types.Vector2Int{
            .x = center.x + @as(i32, @intFromFloat(@cos(angle) * @as(f32, @floatFromInt(radius)))),
            .y = center.y + @as(i32, @intFromFloat(@sin(angle) * @as(f32, @floatFromInt(radius)))),
        };
        castRay(grid, center, target);
    }
}

pub fn castRay(grid: []Level.Tile, center: Types.Vector2Int, target: Types.Vector2Int) void {
    const dx = @as(i32, @intCast(@abs(target.x - center.x)));
    const dy = @as(i32, @intCast(@abs(target.y - center.y)));
    var current_pos = center;

    const x_inc: i32 = if (target.x > center.x) 1 else -1;
    const y_inc: i32 = if (target.y > center.y) 1 else -1;
    var err = dx - dy;

    while (true) {
        const tileIndex = Utils.posToIndex(current_pos);
        if (tileIndex) |tile_index| {
            grid[tile_index].visible = true;
            grid[tile_index].seen = true;

            if (grid[tile_index].solid == true) {
                break;
            }

            // Check if we've reached the end point
            if (Types.vector2IntCompare(current_pos, target)) {
                break;
            }

            const e2 = 2 * err;
            if (e2 > -dy) {
                err -= dy;
                current_pos.x += x_inc;
            }
            if (e2 < dx) {
                err += dx;
                current_pos.y += y_inc;
            }
        }
    }
}

pub fn neighboursDistance(pos: Types.Vector2Int, distance: u32, result: *std.ArrayList(Types.Vector2Int)) !void {
    const n = 2 * distance + 1;
    const start = Types.vector2IntSub(pos, Types.Vector2Int{ .x = @intCast(distance), .y = @intCast(distance) });
    var x: i32 = 0;
    var y: i32 = 0;

    while (y < n) : (y += 1) {
        while (x < n) : (x += 1) {
            if (x == distance and y == distance) {
                continue;
            }
            const newPos = Types.vector2IntAdd(start, Types.Vector2Int{ .x = x, .y = y });
            try result.append(newPos);
        }
        x = 0;
    }
}

pub fn canEndCombat(player: *Entity.Entity) bool {
    _ = player;
    //TODO: end of combat rules
    return true;
}

pub fn removeEntitiesType(entities: *std.ArrayList(*Entity.Entity), entityType: Entity.EntityType) void {
    var i = entities.items.len;
    while (i > 0) {
        i -= 1;
        if (entities.items[i].data == entityType) {
            if (entityType == .puppet) {
                entities.items[i].data.puppet.deployed = false;
            }
            _ = entities.swapRemove(i);
        }
    }
}

// pub fn handlePlayerWalking(game: *Game.Game) !void {
//     //TODO: @refactor what should i move into the player update??
//     game.player.movementCooldown += game.delta;
//     if (game.player.movementCooldown < Config.movement_animation_duration) {
//         return;
//     }
//
//     const skipMove = UiManager.getSkip();
//     const moveDelta = UiManager.getMove();
//     if (skipMove == false and moveDelta == null) {
//         return;
//     }
//     if (skipMove) {
//         game.player.movementCooldown = 0;
//         game.player.turnTaken = true;
//         return;
//     }
//
//     var new_pos = Types.vector2IntAdd(game.player.pos, moveDelta.?);
//     if (!canMove(new_pos)) {
//         return;
//     }
//
//     //TODO: only staircase for now, add boundry transitions
//     new_pos = staircaseTransition(new_pos);
//
//     game.player.move(new_pos);
//     game.player.movementCooldown = 0;
//     game.player.turnTaken = true;
// }

// pub fn handlePlayerDeploying(game: *Game.Game) !void {
//     //
//     // puppet select
//     //
//     if (Gamestate.selectedPupId == null) {
//         Gamestate.showMenu = .puppet_select;
//
//         if (UiManager.getMenuSelect()) |menu_item| {
//             switch (menu_item) {
//                 .puppet_id => |pid| {
//                     Gamestate.selectedPupId = pid;
//                 },
//                 .action => {
//                     std.debug.print("menu_item is .action instead of .puppet_id", .{});
//                 },
//             }
//         }
//     }
//
//     //
//     // puppet deploy
//     //
//     if (Gamestate.selectedPupId) |selected_pup| {
//         Gamestate.showMenu = .none;
//         Gamestate.makeUpdateCursor(game.player.pos);
//
//         //TODO: put deploycells / highlight  into function
//         if (Gamestate.deployableCells == null) {
//             const neighbours = neighboursAll(game.player.pos);
//             Gamestate.deployableCells = neighbours;
//         }
//         if (Gamestate.deployableCells) |cells| {
//             if (!Gamestate.deployHighlighted) {
//                 for (cells) |value| {
//                     if (value) |val| {
//                         try highlightTile(val);
//                         Gamestate.deployHighlighted = true;
//                     }
//                 }
//             }
//         }
//         if (UiManager.getConfirm()) {
//             if (canDeploy(game.player)) {
//                 try deployPuppet(selected_pup);
//             }
//         }
//     }
// }

// pub fn handlePlayerCombat(game: *Game.Game) !void {
//     switch (TurnManager.turn) {
//         .player => {
//             entitySelect(game);
//             try entityAction(game);
//         },
//
//         .enemy => {},
//     }
// }

// pub fn entitySelect(game: *Game.Game) void {
//     const entityIndex = UiManager.getQuickSelect() orelse return;
//
//     Gamestate.resetMovementHighlight();
//     Gamestate.resetAttackHighlight();
//     UiManager.resetActiveMenuIndex();
//     //TODO: reset the active menu index
//     //TODO: make a menu for swapping puppets in the array(different index => different keybind)
//     if (entityIndex == 0) {
//         //Player
//         Gamestate.selectedEntity = game.player;
//     } else {
//         //Puppets
//         if (game.player.data.player.puppets.items.len >= entityIndex) {
//             const pupID = game.player.data.player.puppets.items[entityIndex - 1];
//             Gamestate.selectedEntity = EntityManager.getEntityID(pupID);
//         }
//     }
//
//     if (Gamestate.selectedEntity) |selected_entity| {
//         CameraManager.targetEntity = selected_entity.id;
//         Gamestate.removeCursor();
//         highlightEntity(selected_entity.pos);
//         Gamestate.selectedAction = null;
//     }
// }
// pub fn entityAction(game: *Game.Game) !void {
//     if (Gamestate.selectedEntity) |entity| {
//         if (Gamestate.selectedAction == null) {
//             Gamestate.showMenu = .action_select;
//
//             if (UiManager.getMenuSelect()) |menu_item| {
//                 switch (menu_item) {
//                     .puppet_id => {
//                         std.debug.print("menu_item is .puppet_id instead of .action", .{});
//                     },
//                     .action => |action| {
//                         Gamestate.selectedAction = action;
//                     },
//                 }
//             }
//         }
//
//         const selectedAction = Gamestate.selectedAction orelse return;
//         switch (selectedAction) {
//             .move => {
//                 Gamestate.showMenu = .none;
//                 Gamestate.makeUpdateCursor(entity.pos);
//                 try Gamestate.highlightMovement(entity);
//
//                 if (UiManager.getConfirm()) {
//                     if (Gamestate.cursor) |cur| {
//                         if (Gamestate.isinMovable(cur)) {
//                             //TODO: @fix
//                             entity.path = try Pathfinder.findPath(entity.pos, cur);
//
//                             Gamestate.resetMovementHighlight();
//                             Gamestate.removeCursor();
//                             Gamestate.selectedAction = null;
//                         }
//                     }
//                 }
//
//                 if (c.IsKeyPressed(c.KEY_SPACE)) {
//                     //TODO: manage state after skip
//                     skipMovement();
//                 }
//             },
//             .attack => {
//                 Gamestate.showMenu = .none;
//                 Gamestate.makeUpdateCursor(entity.pos);
//                 try Gamestate.highlightAttack(entity);
//
//                 if (UiManager.getConfirm()) {
//                     if (Gamestate.cursor) |cur| {
//                         if (Gamestate.isinAttackable(cur)) {
//                             const attackedEntity = EntityManager.getEntityByPos(cur, World.currentLevel);
//                             try ShaderManager.spawnSlash(entity.pos, cur);
//                             try ShaderManager.spawnImpact(cur);
//
//                             attack(game, entity, attackedEntity);
//                             Gamestate.resetAttackHighlight();
//                             Gamestate.removeCursor();
//                             entity.hasAttacked = true;
//                             Gamestate.selectedAction = null;
//                         }
//                     }
//                 }
//
//                 if (c.IsKeyPressed(c.KEY_SPACE)) {
//                     //TODO: manage state after skip
//                     skipAttack();
//                 }
//             },
//         }
//
//         if (entity.hasMoved and !entity.canAttack()) {
//             //TODO:
//         }
//
//         if (entity.hasMoved and entity.hasAttacked) {
//             entity.turnTaken = true;
//         }
//     }
// }

pub fn selectedEntityAttack(game: *Game.Game, entity: *Entity.Entity) !void {
    try Gamestate.highlightAttack(entity);

    if (c.IsKeyPressed(c.KEY_A)) {
        if (Gamestate.cursor) |cur| {
            if (Gamestate.isinAttackable(cur)) {
                const attackedEntity = EntityManager.getEntityByPos(cur, World.currentLevel);

                try ShaderManager.spawnSlash(entity.pos, cur);
                try ShaderManager.spawnImpact(cur);

                attack(game, entity, attackedEntity);
                Gamestate.resetAttackHighlight();
                Gamestate.removeCursor();
                entity.hasAttacked = true;
            }
        }
    }
}
pub fn attack(game: *Game.Game, entity: *Entity.Entity, attackedEntity: ?*Entity.Entity) void {
    _ = game;
    if (attackedEntity) |attacked_entity| {
        attacked_entity.health -= entity.attack;
    } else {}
}

pub fn getPupById(entities: std.ArrayList(*Entity.Entity), id: u32) ?*Entity.Entity {
    for (entities.items) |entity| {
        if (entity.id == id) {
            return entity;
        }
    }

    return null;
}

pub fn updatePuppet(puppet: *Entity.Entity, game: *Game.Game) !void {
    if (TurnManager.turn != .player) {
        return;
    }
    //TODO: correct?
    // if (game.player.inCombat) {
    //     try updateEntityMovementIC(puppet, game);
    // } else {
    //     try updateEntityMovementOOC(puppet, game);
    // }

    try updateEntityMovement(puppet, game);
}

pub fn updateEnemy(enemy: *Entity.Entity, game: *Game.Game) !void {
    //TODO: figure out where to put this,
    //good for now, might need some updating
    //late even if its not mu turn
    if (TurnManager.turn != .enemy) {
        return;
    }

    if (enemy.inCombat) {
        if (enemy.aiBehaviourCombat == null) {
            return error.value_missing;
        }
        try enemy.aiBehaviourCombat.?(enemy, game);
    } else {
        if (enemy.aiBehaviourWalking == null) {
            return error.value_missing;
        }
        try enemy.aiBehaviourWalking.?(enemy, game);
    }
}

pub fn updateEntityMovement(entity: *Entity.Entity, game: *Game.Game) !void {
    //const grid = World.getLevelAt(entity.worldPos) orelse return;
    //const entities = //WHERE I NEED TO GET THE ENTITIES;
    if (entity.path == null and entity.goal != null) {
        const newPath = try Pathfinder.findPath(entity.pos, entity.goal.?);
        if (newPath) |new_path| {
            entity.setNewPath(new_path);
            entity.stuck = 0;
        } else {
            entity.stuck += 1;
            return;
        }
    }

    if (entity.hasMoved or entity.path == null) {
        return;
    }

    if (entity.inCombat) {
        entity.movementCooldown += game.delta;
        if (entity.movementCooldown < Config.movement_animation_duration_in_combat) {
            return;
        }
        entity.movementCooldown = 0;
    }

    const path = &entity.path.?;
    const nextIndex = path.currIndex + 1;

    //TODO: @remove
    if (entity.data == .player) {
        std.debug.print("p: {?}\n", .{path.nodes.items.len});
        std.debug.print("i: {}\n", .{nextIndex});
        std.debug.print("g: {?}\n", .{entity.goal});
    }
    if (nextIndex >= path.nodes.items.len) {
        if (entity.data == .player) {
            std.debug.print("reseting...\n", .{});
        }
        entity.removePathGoal();
        entity.finishMovement();
        return;
    }

    const new_pos = path.nodes.items[nextIndex];
    const new_pos_entity = EntityManager.getEntityByPos(new_pos, World.currentLevel);

    // position has entity, recalculate
    if (new_pos_entity) |_| {
        entity.removePath();
        entity.stuck += 1;
        return;
    }

    entity.move(new_pos);
    entity.stuck = 0;
    path.currIndex = nextIndex;

    if (entity.inCombat) {
        entity.movedDistance += 1;
        if (entity.movedDistance >= entity.movementDistance) {
            entity.finishMovement();
            entity.removePath();
        }
    } else {
        entity.hasMoved = true;
    }
}

pub fn enemyCombatBehaviour(enemy: *Entity.Entity, game: *Game.Game) void {
    const left = Types.Vector2Int.init(-1, 0);
    const target = Types.vector2IntAdd(enemy.pos, left);
    wanderTowards(enemy, target, game);
}

pub fn enemyWanderBehaviour(enemy: *Entity.Entity, game: *Game.Game) void {
    _ = enemy;
    _ = game;
}

fn wanderTowards(enemy: *Entity.Entity, target: Types.Vector2Int, game: *Game.Game) void {
    if (Utils.posToIndex(target)) |idx| {
        const tile = game.grid.*[idx];
        if (!tile.solid) {
            if (EntityManager.getEntityByPos(target) == null) {
                enemy.pos = target;
            }
        }
    }
}
pub fn getRandomPosition() Types.Vector2Int {
    const x = std.crypto.random.intRangeAtMost(i32, 0, Config.level_width);
    const y = std.crypto.random.intRangeAtMost(i32, 0, Config.level_height);
    return Types.Vector2Int.init(x, y);
}

pub fn getRandomValidPosition(grid: []Level.Tile) Types.Vector2Int {
    var valid: bool = false;
    var position: Types.Vector2Int = undefined;

    while (!valid) {
        position = getRandomPosition();
        if (Movement.isTileWalkable(grid, position)) {
            valid = true;
        }
    }

    return position;
}
