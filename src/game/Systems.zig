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
const EntityManager = @import("entityManager.zig");
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

    if (game.gamestate.currentTurn != .player) {
        return;
    }

    try updateEntityMovement(player, game);
}

pub fn preWalkingTransitions(game: *Game.Game) !bool {
    if (game.uiCommand.getCombatToggle()) {
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
    if (game.uiCommand.getCombatToggle()) {
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
    if (game.uiCommand.getCombatToggle()) {
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

pub fn deployPuppet(game: *Game.Game, pupId: u32) !void {
    const puppet = getPupById(game.player.data.player.puppets, pupId);
    if (puppet) |pup| {
        if (!pup.data.puppet.deployed) {
            if (game.gamestate.cursor) |curs| {
                pup.pos = curs;
                pup.data.puppet.deployed = true;
                pup.visible = true;
                game.gamestate.selectedPupId = null; //TODO: maybe wrong, check
                return;
            }
        }
    }
}

pub fn canDeploy(player: *Entity.Entity, gamestate: *Gamestate.gameState, grid: []Level.Tile, entities: *std.ArrayList(*Entity.Entity)) bool {
    const deploy_pos = gamestate.cursor;
    if (deploy_pos) |dep_pos| {
        if (Types.vector2IntCompare(player.pos, dep_pos)) {
            return false;
        }

        const entity = getEntityByPos(entities.*, dep_pos);
        if (entity) |_| {
            return false;
        }

        if (!isTileWalkable(grid, dep_pos)) {
            return false;
        }

        if (gamestate.deployableCells) |deployable_cells| {
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

pub fn getEntityByPos(entities: std.ArrayList(Entity.Entity), pos: Types.Vector2Int) ?*Entity.Entity {
    for (entities.items) |*entity| {
        if (Types.vector2IntCompare(entity.pos, pos)) {
            return entity;
        }
    }
    return null;
}

pub fn getEntityById(entities: std.ArrayList(*Entity.Entity), id: u32) ?*Entity.Entity {
    for (entities.items) |entity| {
        if (entity.id == id) {
            return entity;
        }
    }
    return null;
}

pub fn calculateFOV(grid: []Level.Tile, center: Types.Vector2Int, radius: usize) void {
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

pub fn highlightTile(gamestate: *Gamestate.gameState, pos: Types.Vector2Int) !void {
    try gamestate.highlightedTiles.append(Gamestate.highlight{
        .pos = pos,
        .type = .pup_deploy,
    });
}

//TODO: put this somwhere else
pub fn drawGameState(gamestate: *Gamestate.gameState, currentLevel: *Level.Level) void {
    _ = currentLevel;
    if (gamestate.highlightedTiles.items.len > 0) {
        for (gamestate.highlightedTiles.items) |highlight| {
            var highlightColor = c.RED;

            if (highlight.type == .movable) {
                highlightColor = c.BLUE;
            }

            c.DrawRectangleLines(highlight.pos.x * Config.tile_width, highlight.pos.y * Config.tile_height, Config.tile_width, Config.tile_height, highlightColor);
        }
    }

    if (gamestate.selectedEntityHighlight) |highlight| {
        if (highlight.type == .circle) {
            var highColor = c.RED;
            if (highlight.type == .entity) {
                highColor = c.YELLOW;
            }
            c.DrawCircleLines(highlight.pos.x * Config.tile_width + Config.tile_width / 2, highlight.pos.y * Config.tile_height + Config.tile_height / 2, Config.tile_width / 2, highColor);
            //c.DrawEllipseLines(highlight.pos.x * Config.tile_width + Config.tile_width / 2, highlight.pos.y * Config.tile_height + Config.tile_height, Config.tile_width / 2, Config.tile_height / 3, highlight.color);
            //TODO: figure out the elipse, circle for now
        }
    }

    if (gamestate.cursor) |cur| {
        c.DrawRectangleLines(cur.x * Config.tile_width, cur.y * Config.tile_height, Config.tile_width, Config.tile_height, c.YELLOW);
    }
}

pub fn highlightEntity(gamestate: *Gamestate.gameState, pos: Types.Vector2Int) void {
    gamestate.selectedEntityHighlight = Gamestate.highlight{
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

pub fn canMove(grid: []Level.Tile, pos: Types.Vector2Int, entities: std.ArrayList(Entity.Entity)) bool {
    const pos_index = posToIndex(pos);
    if (pos_index) |index| {
        if (index < grid.len) {
            if (grid[index].solid) {
                //TODO: probably gonna add something like walkable
                return false;
            }
        }
    }
    const entity = getEntityByPos(entities, pos);
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
    const moveDelta = InputManager.takePositionInput() orelse return;
    std.debug.print("move: {}\n", .{moveDelta});

    var new_pos = Types.vector2IntAdd(game.player.pos, moveDelta);
    if (!canMove(World.currentLevel.grid, new_pos, EntityManager.entities)) {
        return;
    }

    new_pos = staircaseTransition(game, new_pos);

    game.player.move(new_pos, World.currentLevel.grid);
    game.player.movementCooldown = 0;
    Gamestate.currentTurn = .enemy;
}
pub fn handlePlayerDeploying(game: *Game.Game) !void {
    //TODO: should I put all the code just in the handleplayerdeploying?
    //j_blow says so, have a look into it, kinda makes sense
    //maybe should try to stop only changing the game values and have some local variables / returns, feels kinda wierd
    try puppetSelection(game);
    try puppetDeployment(game);
}
pub fn handlePlayerCombat(game: *Game.Game) !void {
    switch (game.gamestate.currentTurn) {
        .player => {
            entitySelect(game);
            try entityAction(game);
            resolveTurnTaken(game);
        },

        .enemy => {},
    }
}

pub fn entitySelect(game: *Game.Game) void {
    const entityIndex = game.uiCommand.getQuickSelect() orelse return;

    game.gamestate.resetMovementHighlight();
    game.gamestate.resetAttackHighlight();
    //TODO: make a menu for swapping puppets in the array(different index => different keybind)
    if (entityIndex == 0) {
        //Player
        game.gamestate.selectedEntity = game.player;
    } else {
        //Puppets
        if (game.player.data.player.puppets.items.len >= entityIndex) {
            game.gamestate.selectedEntity = game.player.data.player.puppets.items[entityIndex - 1];
        }
    }

    if (game.gamestate.selectedEntity) |selected_entity| {
        game.cameraManager.targetEntity = selected_entity;
        game.gamestate.removeCursor();
        highlightEntity(game.gamestate, selected_entity.pos);
        game.gamestate.selectedAction = null;
    }
}
pub fn entityAction(game: *Game.Game) !void {
    if (game.gamestate.selectedEntity) |entity| {
        if (game.gamestate.selectedAction == null) {
            game.gamestate.showMenu = .action_select;

            if (game.uiCommand.getMenuSelect()) |menu_item| {
                switch (menu_item) {
                    .puppet_id => {
                        std.debug.print("menu_item is .puppet_id instead of .action", .{});
                    },
                    .action => |action| {
                        game.gamestate.selectedAction = action;
                    },
                }
            }
        }

        const selectedAction = game.gamestate.selectedAction orelse return;
        switch (selectedAction) {
            .move => {
                game.gamestate.showMenu = .none;
                game.gamestate.makeUpdateCursor(entity.pos);
                try game.gamestate.highlightMovement(entity);

                if (game.uiCommand.getConfirm()) {
                    if (game.gamestate.cursor) |cur| {
                        if (game.gamestate.isinMovable(cur)) {
                            entity.path = try game.pathfinder.findPath(game.grid.*, entity.pos, cur, game.entities.*);
                            entity.hasMoved = true;
                            game.gamestate.resetMovementHighlight();
                            game.gamestate.removeCursor();
                            game.gamestate.selectedAction = null;
                        }
                    }
                }

                if (c.IsKeyPressed(c.KEY_SPACE)) {
                    //TODO: manage state after skip
                    skipMovement(game);
                }
            },
            .attack => {
                game.gamestate.showMenu = .none;
                game.gamestate.makeUpdateCursor(entity.pos);
                try game.gamestate.highlightAttack(entity);

                if (game.uiCommand.getConfirm()) {
                    if (game.gamestate.cursor) |cur| {
                        if (game.gamestate.isinAttackable(cur)) {
                            const attackedEntity = getEntityByPos(game.entities.*, cur);
                            try game.shaderManager.spawnSlash(entity.pos, cur);
                            try game.shaderManager.spawnImpact(cur);

                            attack(game, entity, attackedEntity);
                            game.gamestate.resetAttackHighlight();
                            game.gamestate.removeCursor();
                            entity.hasAttacked = true;
                            game.gamestate.selectedAction = null;
                        }
                    }
                }

                if (c.IsKeyPressed(c.KEY_SPACE)) {
                    //TODO: manage state after skip
                    skipAttack(game);
                }
                // game.gamestate.showMenu = .none;
                // std.debug.print("attacking\n", .{});
                // game.gamestate.updateCursor();
                // try selectedEntityAttack(game, entity);
                // if (c.IsKeyPressed(c.KEY_SPACE)) {
                //     skipAttack(game);
                // }
            },
        }

        if (entity.hasMoved and !entity.canAttack(game)) {
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
            game.gamestate.currentTurn = .enemy;
            game.player.resetTurnTakens();
            game.gamestate.reset();
        }
    }
}

pub fn skipMovement(game: *Game.Game) void {
    if (game.gamestate.selectedEntity) |entity| {
        entity.hasMoved = true;
    }
    game.gamestate.resetMovementHighlight();
    game.gamestate.removeCursor();
    game.gamestate.selectedAction = null;
}

pub fn skipAttack(game: *Game.Game) void {
    if (game.gamestate.selectedEntity) |entity| {
        entity.hasAttacked = true;
    }
    game.gamestate.resetAttackHighlight();
    game.gamestate.removeCursor();
    game.gamestate.selectedAction = null;
}

pub fn selectedEntityMove(game: *Game.Game, entity: *Entity.Entity) !void {
    //TODO: absolutely change this
    try game.gamestate.highlightMovement(entity);

    if (c.IsKeyPressed(c.KEY_A)) {
        if (game.gamestate.cursor) |cur| {
            if (game.gamestate.isinMovable(cur)) {
                entity.path = try game.pathfinder.findPath(game.grid.*, entity.pos, cur, game.entities.*);
                entity.hasMoved = true;
                game.gamestate.resetMovementHighlight();
                game.gamestate.removeCursor();
                game.gamestate.selectedAction = null;
            }
        }
    }
}
pub fn selectedEntityAttack(game: *Game.Game, entity: *Entity.Entity) !void {
    try game.gamestate.highlightAttack(entity);

    if (c.IsKeyPressed(c.KEY_A)) {
        if (game.gamestate.cursor) |cur| {
            //try game.shaderManager.spawnSlash(entity.pos, cur);
            //try game.shaderManager.spawnExplosion(entity.pos);
            //try game.shaderManager.spawnImpact(cur);
            if (game.gamestate.isinAttackable(cur)) {
                const attackedEntity = getEntityByPos(game.entities.*, cur);

                try game.shaderManager.spawnSlash(entity.pos, cur);
                try game.shaderManager.spawnImpact(cur);

                attack(game, entity, attackedEntity);
                game.gamestate.resetAttackHighlight();
                game.gamestate.removeCursor();
                entity.hasAttacked = true;
            }
        }
    }
}
pub fn attack(game: *Game.Game, entity: *Entity.Entity, attackedEntity: ?*Entity.Entity) void {
    _ = game;
    if (attackedEntity) |attacked_entity| {
        attacked_entity.health -= entity.attack;
        std.debug.print("DMG: {}\n", .{entity.attack});
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

pub fn puppetSelection(game: *Game.Game) !void {
    if (game.gamestate.selectedPupId == null) {
        game.gamestate.showMenu = .puppet_select;

        if (game.uiCommand.getMenuSelect()) |menu_item| {
            switch (menu_item) {
                .puppet_id => |pid| {
                    game.gamestate.selectedPupId = pid;
                },
                .action => {
                    std.debug.print("menu_item is .action instead of .puppet_id", .{});
                },
            }
        }
    }
}

pub fn puppetDeployment(game: *Game.Game) !void {
    if (game.gamestate.selectedPupId) |selected_pup| {
        game.gamestate.showMenu = .none;
        game.gamestate.makeUpdateCursor(game.player.pos);

        //TODO: put deploycells / highlight  into function
        if (game.gamestate.deployableCells == null) {
            const neighbours = neighboursAll(game.player.pos);
            game.gamestate.deployableCells = neighbours;
        }
        if (game.gamestate.deployableCells) |cells| {
            if (!game.gamestate.deployHighlighted) {
                for (cells) |value| {
                    if (value) |val| {
                        try highlightTile(game.gamestate, val);
                        game.gamestate.deployHighlighted = true;
                    }
                }
            }
        }
        if (game.uiCommand.getConfirm()) {
            if (canDeploy(game.player, game.gamestate, game.grid.*, game.entities)) {
                try deployPuppet(game, selected_pup);
            }
        }
    }
}

pub fn staircaseTransition(game: *Game.Game, newPos: Types.Vector2Int) Types.Vector2Int {
    if (!isStaircase(newPos)) {
        return newPos;
    }

    if (getStaircaseDestination(newPos)) |lvllocation| {
        switchLevel(game.world, lvllocation.level);
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
    if (game.gamestate.currentTurn != .player) {
        return;
    }
    try updateEntityMovement(puppet, game);
}

pub fn updateEnemy(enemy: *Entity.Entity, game: *Game.Game) !void {
    if (game.gamestate.currentTurn != .enemy) {
        return;
    }
    std.debug.print("updating_enemy\n", .{});

    if (enemy.inCombat) {
        //TODO:
    } else {
        std.debug.print("non_combat\n", .{});
        if (enemy.aiBehaviourWalking == null) {
            return error.value_missing;
        }
        try enemy.aiBehaviourWalking.?(enemy, game);
        //enemyWanderBehaviour(enemy, game);
    }
    try updateEntityMovement(enemy, game);
}

pub fn updateEntityMovement(entity: *Entity.Entity, game: *Game.Game) !void {
    if (entity.path == null and entity.goal != null) {
        entity.path = try game.pathfinder.findPath(game.grid.*, entity.pos, entity.goal.?, game.entities.*);
    }
    if (entity.path) |path| {
        if (path.nodes.items.len < 2) {
            return;
        }

        //TODO: gonna have to make some animation state, wait for animation to finish
        // entity.movementCooldown += game.delta;
        // if (entity.movementCooldown < Config.movement_animation_duration) {
        //     return;
        // }

        entity.movementCooldown = 0;
        entity.path.?.currIndex += 1;
        const new_pos = entity.path.?.nodes.items[entity.path.?.currIndex];
        const new_pos_entity = getEntityByPos(game.entities.*, new_pos);

        if (new_pos_entity) |_| {
            // position has entity, recalculate
            if (entity.goal) |goal| {
                entity.path = try game.pathfinder.findPath(game.grid.*, entity.pos, goal, game.entities.*);
            }
        } else {
            entity.move(new_pos, game.grid);
        }

        if (entity.path) |path_| {
            if (path_.currIndex >= entity.path.?.nodes.items.len - 1) {
                entity.path = null;
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
            if (getEntityByPos(game.entities.*, target) == null) {
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
