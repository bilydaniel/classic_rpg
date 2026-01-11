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
const Game = @import("game.zig");
const ShaderManager = @import("shaderManager.zig");
const EntityManager = @import("entityManager.zig");
const UiManager = @import("../ui/uiManager.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

//TODO: add an optiom to "look around", get info on enemies, etc.
pub fn updatePlayer(player: *Entity.Entity, game: *Game.Game) !void {
    switch (player.data.player.state) {
        // TODO: go through everything, make more functions, messy
        // TODO: go through all the state management, make some fool proof system
        // of writing the state transitions / resets of variables
        // RESETING OF VARIABLES IS IMPORTANT, THATS WHERE I MAKE MISTAKES
        .walking => {
            if (try preWalkingTransitions(game)) {
                return;
            }
            try handlePlayerWalking(game);
        },
        .deploying_puppets => {
            if (try preDeployingTransitions(game)) {
                return;
            }
            try handlePlayerDeploying(game);
        },
        .in_combat => {
            if (try preCombatTransitions(game)) {
                return;
            }
            try handlePlayerCombat(game);
        },
    }

    if (Gamestate.currentTurn != .player) {
        return;
    }

    if (player.inCombat) {
        try updateEntityMovementIC(player, game);
    } else {
        try updateEntityMovementOOC(player, game);
    }
}

pub fn preWalkingTransitions(game: *Game.Game) !bool {
    if (UiManager.getCombatToggle()) {
        //TODO: check in enemies are around, if it makes sense to even go to combat
        try playerChangeState(game, .deploying_puppets);
        return true;
    }

    if (checkCombatStart(game.player, EntityManager.entities)) {
        try playerChangeState(game, .deploying_puppets);
        return true;
    }

    return false;
}

pub fn preDeployingTransitions(game: *Game.Game) !bool {
    if (UiManager.getCombatToggle()) {
        try playerChangeState(game, .walking);
        return true;
    }

    if (game.player.data.player.allPupsDeployed()) {
        try playerChangeState(game, .in_combat);
        return true;
    }

    return false;
}

pub fn preCombatTransitions(game: *Game.Game) !bool {
    if (UiManager.getCombatToggle()) {
        //TODO: check can end combat?
        try playerChangeState(game, .walking);
        return true;
    }

    if (game.player.data.player.inCombatWith.items.len == 0) {
        try playerChangeState(game, .walking);
        return true;
    }
    return false;
}

pub fn deployPuppet(pupId: u32) !void {
    const puppet = EntityManager.getEntityID(pupId);
    if (puppet) |pup| {
        if (!pup.data.puppet.deployed) {
            if (Gamestate.cursor) |curs| {
                pup.pos = curs;
                pup.data.puppet.deployed = true;
                pup.visible = true;
                Gamestate.selectedPupId = null; //TODO: maybe wrong, check
                return;
            }
        }
    }
}

pub fn canDeploy(player: *Entity.Entity) bool {
    const deploy_pos = Gamestate.cursor;
    if (deploy_pos) |dep_pos| {
        if (Types.vector2IntCompare(player.pos, dep_pos)) {
            return false;
        }

        const entity = EntityManager.getEntityByPos(dep_pos);
        if (entity) |_| {
            return false;
        }

        const grid = World.currentLevel.grid;
        if (!isTileWalkable(grid, dep_pos)) {
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

pub fn isTileWalkable(grid: []Level.Tile, pos: Types.Vector2Int) bool {
    const index = posToIndex(pos) orelse return false;
    const tile = grid[index];

    if (tile.solid) {
        return false;
    }

    if (!tile.walkable) {
        return false;
    }

    return true;
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

pub fn getEntityById(entities: std.ArrayList(*Entity.Entity), id: u32) ?*Entity.Entity {
    for (entities.items) |entity| {
        if (entity.id == id) {
            return entity;
        }
    }
    return null;
}

pub fn calculateFOV(center: Types.Vector2Int, radius: usize) void {
    var grid = World.currentLevel.grid;
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
        const tileIndex = posToIndex(current_pos);
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

//TODO: @refactor put into world
pub fn switchLevel(levelID: u32) void {
    for (World.levels.items) |level| {
        if (level.id == levelID) {
            World.currentLevel = level;
        }
    }
}

pub fn old_highlightTile(grid: []Level.Tile, pos: Types.Vector2Int, color: c.Color) void {
    const pos_index = posToIndex(pos);
    if (pos_index) |index| {
        if (index >= 0 and index < grid.len) {
            var tile = &grid[index];
            tile.tempBackground = color;
        }
    }
}

//TODO: @refactor put into gamestate
pub fn highlightTile(pos: Types.Vector2Int) !void {
    try Gamestate.highlightedTiles.append(Gamestate.Highlight{
        .pos = pos,
        .type = .pup_deploy,
    });
}

//TODO: @refactor put into gamestate
pub fn highlightEntity(pos: Types.Vector2Int) void {
    Gamestate.selectedEntityHighlight = Gamestate.Highlight{
        .pos = pos,
        .type = .circle,
    };
}

//TODO: put into world / probably gonna remove links anyway
pub fn isStaircase(pos: Types.Vector2Int) bool {
    //TODO: probably should add a check for the tile type
    for (World.levelLinks.items) |levelLink| {
        if (levelLink.from.level == World.currentLevel.id and Types.vector2IntCompare(levelLink.from.pos, pos)) {
            return true;
        }
    }
    return false;
}

pub fn getStaircaseDestination(pos: Types.Vector2Int) ?Level.Location {
    for (World.levelLinks.items) |levelLink| {
        if (levelLink.from.level == World.currentLevel.id and Types.vector2IntCompare(levelLink.from.pos, pos)) {
            return levelLink.to;
        }
    }
    return null;
}
pub fn getAvailableTileAround(pos: Types.Vector2Int) ?Types.Vector2Int {
    if (canMove(pos)) {
        return pos;
    }

    const neighbours = neighboursAll(pos);
    for (neighbours) |neighbor| {
        const neigh = neighbor orelse continue;
        if (canMove(neigh)) {
            return neigh;
        }
    }

    return null;
}
//TODO: move somewhere else?
pub fn canMove(pos: Types.Vector2Int) bool {
    const grid = World.currentLevel.grid;
    const pos_index = posToIndex(pos);
    if (pos_index) |index| {
        if (index < grid.len) {
            if (grid[index].solid) {
                //TODO: probably gonna add something like walkable
                return false;
            }
        }
    }
    const entity = EntityManager.getEntityByPos(pos);
    if (entity == null) {
        return true;
    }

    return false;
}

pub fn posToIndex(pos: Types.Vector2Int) ?usize {
    if (pos.x < 0 or pos.y < 0) {
        return null;
    }
    const result: usize = @intCast(pos.y * Config.level_width + pos.x);
    if (result >= Config.level_width * Config.level_height) {
        return null;
    }
    return result;
}

pub fn indexToPos(index: i32) Types.Vector2Int {
    const x = (index % Config.level_width);
    const y = (@divFloor(index, Config.level_width));
    return Types.Vector2Int.init(x, y);
}

pub fn indexToPixel(index: i32) c.Vector2 {
    const x = (index % Config.level_width) * Config.tile_width;
    const y = (@divFloor(index, Config.level_width)) * Config.tile_height;
    return c.Vector2{ .x = x, .y = y };
}

pub fn getTileIdx(grid: []Level.Tile, index: usize) ?Level.Tile {
    if (index < 0) {
        return null;
    }

    if (index >= grid.len) {
        return null;
    }
    return grid[index];
}

pub fn getTilePos(grid: []Level.Tile, pos: Types.Vector2Int) ?Level.Tile {
    const idx = posToIndex(pos);
    if (idx) |index| {
        return getTileIdx(grid, index);
    }
    return null;
}

pub fn neighboursAll(pos: Types.Vector2Int) [8]?Types.Vector2Int {
    var result: [8]?Types.Vector2Int = undefined;

    var count: usize = 0;
    const sides = [_]i32{ -1, 0, 1 };
    for (sides) |y_side| {
        for (sides) |x_side| {
            if (x_side == 0 and y_side == 0) {
                continue;
            }
            const dif_pos = Types.Vector2Int.init(x_side, y_side);
            const result_pos = Types.vector2IntAdd(pos, dif_pos);
            if (result_pos.x >= 0 and result_pos.y >= 0 and result_pos.x < Config.level_width and result_pos.y < Config.level_height) {
                result[count] = result_pos;
            }
            count += 1;
        }
    }
    return result;
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

pub fn checkCombatStart(player: *Entity.Entity, entities: std.ArrayList(Entity.Entity)) bool {
    for (entities.items) |entity| {
        if (entity.data == .enemy) {
            const distance = Types.vector2Distance(player.pos, entity.pos);
            if (distance < 3) {
                return true;
            }
        }
    }
    return false;
}

pub fn canEndCombat(player: *Entity.Entity) bool {
    _ = player;
    //TODO: end of combat rules
    return true;
}

pub fn findEmptyCloseCell(grid: []Level.Tile, entities: *std.ArrayList(*Entity.Entity), pos: Types.Vector2Int) Types.Vector2Int {
    const neighbours = neighboursAll(pos);
    _ = neighbours;
    _ = grid;
    _ = entities;
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

pub fn handlePlayerWalking(game: *Game.Game) !void {
    game.player.movementCooldown += game.delta;
    if (game.player.movementCooldown < Config.movement_animation_duration) {
        return;
    }

    //TODO: take input from uimanager?
    const skipMove = UiManager.getSkip();
    const moveDelta = UiManager.getMove();
    if (skipMove == false and moveDelta == null) {
        return;
    }
    if (skipMove) {
        game.player.movementCooldown = 0;
        Gamestate.switchTurn(.enemy);
        return;
    }

    var new_pos = Types.vector2IntAdd(game.player.pos, moveDelta.?);
    if (!canMove(new_pos)) {
        return;
    }

    new_pos = staircaseTransition(new_pos);

    game.player.move(new_pos);
    game.player.movementCooldown = 0;
    Gamestate.switchTurn(.enemy);
}
pub fn handlePlayerDeploying(game: *Game.Game) !void {
    //TODO: should I put all the code just in the handleplayerdeploying?
    //j_blow says so, have a look into it, kinda makes sense
    //maybe should try to stop only changing the game values and have some local variables / returns, feels kinda wierd
    try puppetSelection();
    try puppetDeployment(game);
}
pub fn handlePlayerCombat(game: *Game.Game) !void {
    switch (Gamestate.currentTurn) {
        .player => {
            entitySelect(game);
            try entityAction(game);
            resolveTurnTaken(game);
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
    //TODO: make a menu for swapping puppets in the array(different index => different keybind)
    if (entityIndex == 0) {
        //Player
        Gamestate.selectedEntity = game.player;
    } else {
        //Puppets
        if (game.player.data.player.puppets.items.len >= entityIndex) {
            const pupID = game.player.data.player.puppets.items[entityIndex - 1];
            Gamestate.selectedEntity = EntityManager.getEntityID(pupID);
        }
    }

    if (Gamestate.selectedEntity) |selected_entity| {
        CameraManager.targetEntity = selected_entity.id;
        Gamestate.removeCursor();
        highlightEntity(selected_entity.pos);
        Gamestate.selectedAction = null;
    }
}
pub fn entityAction(game: *Game.Game) !void {
    if (Gamestate.selectedEntity) |entity| {
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
        switch (selectedAction) {
            .move => {
                Gamestate.showMenu = .none;
                Gamestate.makeUpdateCursor(entity.pos);
                try Gamestate.highlightMovement(entity);

                if (UiManager.getConfirm()) {
                    if (Gamestate.cursor) |cur| {
                        if (Gamestate.isinMovable(cur)) {
                            entity.path = try Pathfinder.findPath(entity.pos, cur);
                            Gamestate.resetMovementHighlight();
                            Gamestate.removeCursor();
                            Gamestate.selectedAction = null;

                            EntityManager.setActingEntity(entity);
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
                            const attackedEntity = EntityManager.getEntityByPos(cur);
                            try ShaderManager.spawnSlash(entity.pos, cur);
                            try ShaderManager.spawnImpact(cur);

                            attack(game, entity, attackedEntity);
                            Gamestate.resetAttackHighlight();
                            Gamestate.removeCursor();
                            entity.hasAttacked = true;
                            Gamestate.selectedAction = null;
                        }
                    }
                }

                if (c.IsKeyPressed(c.KEY_SPACE)) {
                    //TODO: manage state after skip
                    skipAttack();
                }
                // Gamestate.showMenu = .none;
                // std.debug.print("attacking\n", .{});
                // Gamestate.updateCursor();
                // try selectedEntityAttack(game, entity);
                // if (c.IsKeyPressed(c.KEY_SPACE)) {
                //     skipAttack(game);
                // }
            },
        }

        if (entity.hasMoved and !entity.canAttack()) {
            //TODO:
        }

        if (entity.hasMoved and entity.hasAttacked) {
            entity.turnTaken = true;
        }
    }
}

pub fn resolveTurnTaken(game: *Game.Game) void {
    if (game.player.data.player.inCombatWith.items.len > 0) {
        if (game.player.turnTaken or game.player.allPupsTurnTaken()) {
            // finished turn
            if (EntityManager.actingEntity == null) {
                Gamestate.switchTurn(.enemy);
                game.player.resetTurnTakens();
                Gamestate.reset();
            }
        }
    }
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

pub fn selectedEntityMove(game: *Game.Game, entity: *Entity.Entity) !void {
    //TODO: absolutely change this
    try Gamestate.highlightMovement(entity);

    if (c.IsKeyPressed(c.KEY_A)) {
        if (Gamestate.cursor) |cur| {
            if (Gamestate.isinMovable(cur)) {
                entity.path = try Pathfinder.findPath(game.grid.*, entity.pos, cur, game.entities.*);
                entity.hasMoved = true;
                Gamestate.resetMovementHighlight();
                Gamestate.removeCursor();
                Gamestate.selectedAction = null;
            }
        }
    }
}
pub fn selectedEntityAttack(game: *Game.Game, entity: *Entity.Entity) !void {
    try Gamestate.highlightAttack(entity);

    if (c.IsKeyPressed(c.KEY_A)) {
        if (Gamestate.cursor) |cur| {
            if (Gamestate.isinAttackable(cur)) {
                const attackedEntity = EntityManager.getEntityByPos(cur);

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

pub fn puppetSelection() !void {
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
}

pub fn puppetDeployment(game: *Game.Game) !void {
    if (Gamestate.selectedPupId) |selected_pup| {
        Gamestate.showMenu = .none;
        Gamestate.makeUpdateCursor(game.player.pos);

        //TODO: put deploycells / highlight  into function
        if (Gamestate.deployableCells == null) {
            const neighbours = neighboursAll(game.player.pos);
            Gamestate.deployableCells = neighbours;
        }
        if (Gamestate.deployableCells) |cells| {
            if (!Gamestate.deployHighlighted) {
                for (cells) |value| {
                    if (value) |val| {
                        try highlightTile(val);
                        Gamestate.deployHighlighted = true;
                    }
                }
            }
        }
        if (UiManager.getConfirm()) {
            if (canDeploy(game.player)) {
                try deployPuppet(selected_pup);
            }
        }
    }
}

pub fn staircaseTransition(newPos: Types.Vector2Int) Types.Vector2Int {
    if (!isStaircase(newPos)) {
        return newPos;
    }

    if (getStaircaseDestination(newPos)) |lvllocation| {
        switchLevel(lvllocation.level);
        return lvllocation.pos;
    }

    return newPos;
}

//TODO: maybe add more states to the enum?
//should things like picking a puppet from the menu has its own state?
pub fn playerChangeState(game: *Game.Game, newState: Entity.playerStateEnum) !void {
    var player = EntityManager.getPlayer();
    const oldState = player.data.player.state;
    if (oldState == newState) {
        //state is the same
        return;
    }

    //exit previous state
    switch (oldState) {
        .walking => try exitWalking(game),
        .deploying_puppets => try exitDeployingPuppets(game),
        .in_combat => try exitCombat(game),
    }

    //change state
    //TODO: should I first switch the state or call enter and then switch?
    player.data.player.state = newState;

    //enter new state
    switch (newState) {
        .walking => try enterWalking(game),
        .deploying_puppets => try enterDeployingPuppets(game),
        .in_combat => try enterCombat(game),
    }
}

pub fn enterWalking(game: *Game.Game) !void {
    if (canEndCombat(game.player)) {
        Gamestate.reset(); //TODO: make more reset functions depending on the state?
        game.player.endCombat();
        Gamestate.showMenu = .none;
    }
}
pub fn exitWalking(game: *Game.Game) !void {
    _ = game;
    //TODO:
}
pub fn enterDeployingPuppets(game: *Game.Game) !void {
    //TODO: filter out entities that are supposed to be in the combat
    // could be some mechanic around attention/stealth
    // smarter entities shout at other to help etc...

    game.player.inCombat = true;

    for (EntityManager.entities.items) |*entity| {
        try game.player.data.player.inCombatWith.append(entity.id);
        entity.resetPathing();
        entity.inCombat = true;
    }
}
pub fn exitDeployingPuppets(game: *Game.Game) !void {
    _ = game;
}
pub fn enterCombat(game: *Game.Game) !void {
    Gamestate.reset();
    Gamestate.showMenu = .none;
    game.player.movementCooldown = 0;
}
pub fn exitCombat(game: *Game.Game) !void {
    _ = game;
    //TODO:
}

pub fn updatePuppet(puppet: *Entity.Entity, game: *Game.Game) !void {
    if (Gamestate.currentTurn != .player) {
        return;
    }
    //TODO: correct?
    if (game.player.inCombat) {
        try updateEntityMovementIC(puppet, game);
    } else {
        try updateEntityMovementOOC(puppet, game);
    }
}

pub fn updateEnemy(enemy: *Entity.Entity, game: *Game.Game) !void {
    //TODO: figure out where to put this,
    //good for now, might need some updating
    //late even if its not mu turn
    if (Gamestate.currentTurn != .enemy) {
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

pub fn updateEntityMovementOOC(entity: *Entity.Entity, game: *Game.Game) !void {
    _ = game;

    if (entity.path == null and entity.goal != null) {
        const newPath = try Pathfinder.findPath(entity.pos, entity.goal.?);
        if (newPath) |new_path| {
            entity.setNewPath(new_path);
            entity.stuck = 0;
        } else {
            entity.stuck += 1;
        }
    }

    if (entity.hasMoved) {
        return;
    }

    if (entity.path) |_| {
        const path = &entity.path.?;

        if (path.currIndex + 1 >= path.nodes.items.len) {
            entity.removePathGoal();
            entity.finishMovement();
            return;
        }
        path.currIndex += 1;

        const new_pos = path.nodes.items[path.currIndex];
        const new_pos_entity = EntityManager.getEntityByPos(new_pos);

        // position has entity, recalculate
        if (new_pos_entity) |_| {
            entity.removePath();
            entity.stuck += 1;
            return;
        }

        if (!entity.hasMoved) {
            entity.move(new_pos);
            entity.hasMoved = true;
            entity.stuck = 0;
        }
    }
}

pub fn updateEntityMovementIC(entity: *Entity.Entity, game: *Game.Game) !void {
    if (entity.path == null and entity.goal != null) {
        const newPath = try Pathfinder.findPath(entity.pos, entity.goal.?);
        if (newPath) |new_path| {
            entity.setNewPath(new_path);
            entity.stuck = 0;
        } else {
            entity.stuck += 1;
        }
    }

    if (entity.hasMoved) {
        return;
    }

    if (entity.path) |_| {
        const path = &entity.path.?;

        EntityManager.setActingEntity(entity);
        entity.movementCooldown += game.delta;
        if (entity.movementCooldown < Config.movement_animation_duration) {
            return;
        }
        entity.movementCooldown = 0;

        if (path.currIndex + 1 >= path.nodes.items.len) {
            entity.removePathGoal();
            entity.finishMovement();
            return;
        }
        path.currIndex += 1;

        const new_pos = path.nodes.items[path.currIndex];
        const new_pos_entity = EntityManager.getEntityByPos(new_pos);

        // position has entity, recalculate
        if (new_pos_entity) |_| {
            entity.removePath();
            entity.stuck += 1;
            return;
        }

        if (!entity.hasMoved) {
            entity.move(new_pos);
            entity.movedDistance += 1;
            if (entity.movedDistance >= entity.movementDistance) {
                entity.finishMovement();
            }
        }
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
    if (posToIndex(target)) |idx| {
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
        if (isTileWalkable(grid, position)) {
            valid = true;
        }
    }

    return position;
}
