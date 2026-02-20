const std = @import("std");
const World = @import("world.zig");
const TilesetManager = @import("assetManager.zig");
const Config = @import("../common/config.zig");
const Utils = @import("../common/utils.zig");
const Pathfinder = @import("../game/pathfinder.zig");
const Types = @import("../common/types.zig");
const Systems = @import("Systems.zig");
const Level = @import("level.zig");
const Game = @import("game.zig");
const AssetManager = @import("assetManager.zig");
const Movement = @import("movement.zig");
const EntityManager = @import("entityManager.zig");
const TurnManager = @import("../game/turnManager.zig");
const rl = @import("raylib");

pub const EntityType = enum {
    player, // there could be an enemy puppet master
    puppet, // there could be an enemy puppet, would be cool loot(parts for the puppets, may be the way to optain head, torso)
    enemy,
    item,
};

pub var entity_id: u32 = 0;

pub const EntityData = union(EntityType) {
    player: PlayerData,
    puppet: PuppetData,
    enemy: EnemyData,
    item: ItemData,
};

//TODO: lets not add rpg stats,
//too complicated for balancing
//would be alot more work
// make the game without progression / balance first
pub const Entity = struct {
    id: u32,
    name: [:0]const u8 = "",
    health: i32,
    mana: i32,
    tp: i32,
    attack: i32,
    pos: Types.Vector2Int,
    worldPos: Types.Vector3Int = Types.Vector3Int.init(0, 0, 0),
    goal: ?Types.Vector2Int = null,
    path: ?Pathfinder.Path,
    speed: f32,
    movementCooldown: f32, //TODO: probably do a different way
    movementDistance: u32,
    movedDistance: u32 = 0,
    attackDistance: u32,
    textureID: ?i32,
    sourceRect: ?rl.Rectangle,
    color: rl.Color,
    backgroundColor: rl.Color,
    tempBackground: ?rl.Color,
    visible: bool,
    targetable: bool,
    turnTaken: bool,
    hasMoved: bool,
    hasAttacked: bool,
    inCombat: bool,
    stuck: u32 = 0,
    aiBehaviourWalking: ?*const fn (*Entity, *Game.Game) anyerror!void = aiBehaviourWander,
    aiBehaviourCombat: ?*const fn (*Entity, *Game.Game) anyerror!void = aiBehaviourAggresiveMellee,

    data: EntityData,

    pub fn init(
        allocator: std.mem.Allocator,
        pos: Types.Vector2Int,
        speed: f32,
        entityData: anytype,
    ) !Entity {
        //const entity = try allocator.create(Entity);
        _ = allocator;
        const entity = Entity{
            .id = entity_id,
            .health = 10,
            .mana = 10,
            .tp = 0,
            .attack = 3,
            .pos = pos,
            .textureID = null,
            .sourceRect = null,
            .movementCooldown = 0,
            .movementDistance = 2,
            .attackDistance = 1,
            .speed = speed,
            .path = null,
            .color = rl.Color.white,
            .backgroundColor = rl.Color.black,
            .tempBackground = null,
            .visible = true,
            .targetable = true, //TODO: add to the needed places
            .turnTaken = false,
            .hasMoved = false,
            .hasAttacked = false,
            .inCombat = false,
            .data = entityData,
        };
        entity_id += 1;
        return entity;
    }

    pub fn draw(this: *Entity) void {
        if (this.visible) {
            if (this.path) |path| {
                Pathfinder.drawPath(path);
            }
            if (this.goal) |goal| {
                rl.drawRectangleLines(goal.x * Config.tile_width, goal.y * Config.tile_height, Config.tile_width, Config.tile_height, rl.Color.yellow);
            }

            if (this.sourceRect) |source_rect| {
                const x: f32 = @floatFromInt(this.pos.x * Config.tile_width);
                const y: f32 = @floatFromInt(this.pos.y * Config.tile_height);
                const pos = rl.Vector2{ .x = x, .y = y };

                var color = rl.Color.white;
                if (this.data == .enemy) {
                    color = rl.Color.red;
                }
                rl.drawTextureRec(TilesetManager.tileset, source_rect, pos, color);
            }
        }
    }

    pub fn endCombat(this: *Entity) void {
        if (this.data == .player) {
            this.data.player.inCombatWith.clearRetainingCapacity();
            this.returnPuppets();
        }

        this.inCombat = false;
    }

    pub fn returnPuppets(this: *Entity) void {
        for (this.data.player.puppets.items) |pupID| {
            const puppet = EntityManager.getEntityID(pupID);
            if (puppet) |pup| {
                pup.visible = false;
                pup.targetable = false;
                pup.data.puppet.deployed = false;

                //TODO: hack, probably should add an extra variable like targetable or something
                pup.pos.x = -1;
                pup.pos.y = -1;
            }
        }
    }

    pub fn allPupsTurnTaken(this: *Entity) bool {
        if (this.data == .player) {
            for (this.data.player.puppets.items) |pupID| {
                const puppet = EntityManager.getEntityID(pupID);
                if (puppet) |pup| {
                    if (pup.turnTaken == false) {
                        return false;
                    }
                }
            }
        }
        return true;
    }

    pub fn setAllPupsTurnTaken(this: *Entity) void {
        if (this.data == .player) {
            for (this.data.player.puppets.items) |pupID| {
                const puppet = EntityManager.getEntityID(pupID);
                if (puppet) |pup| {
                    pup.turnTaken = true;
                }
            }
        }
    }

    pub fn setTextureID(this: *Entity, asset: AssetManager.TileNames) void {
        const id = @intFromEnum(asset);
        this.textureID = id;
        this.sourceRect = Utils.makeSourceRect(id);
    }

    pub fn update(this: *Entity, game: *Game.Game) !void {
        switch (this.data) {
            //TODO: see if it needs to be separated or not, change later
            .player => try updatePlayer(game.player, game),
            .puppet => try updatePuppet(this, game),
            .enemy => try updateEnemy(this, game),
            .item => {}, //TODO: later
        }
    }

    pub fn move(this: *Entity, pos: Types.Vector2Int) !void {
        //TODO: add if targetable
        if (this.data == .player or this.data == .puppet) {
            Systems.calculateFOV(pos, 8);
        }

        try EntityManager.moveEntityHash(this.pos, pos);
        this.pos = pos;
    }

    pub fn wander(this: *Entity, pos: Types.Vector2Int, ctx: *Game.Context) void {
        const index = Utils.posToIndex(pos);
        if (index) |idx| {
            const tile = ctx.grid.*[idx];
            if (!tile.solid) {
                const entity = Systems.getEntityByPos(ctx.entities.*, pos);
                if (entity == null) {
                    this.pos = pos;
                }
            }
        }
    }

    pub fn resetPathing(this: *Entity) void {
        if (this.data == .enemy) {
            this.goal = null;
        }
        this.path = null;
    }

    pub fn resetTurnTakens(this: *Entity) void {
        if (this.data == .player) {
            this.hasMoved = false;
            this.hasAttacked = false;
            this.turnTaken = false;

            for (this.data.player.puppets.items) |pupID| {
                const puppet = EntityManager.getEntityID(pupID);
                if (puppet) |pup| {
                    pup.hasMoved = false;
                    pup.hasAttacked = false;
                    pup.turnTaken = false;
                }
            }
        }
    }

    pub fn canAttack(this: *Entity) bool {
        _ = this;
        //TODO: @finish
        return false;
    }

    pub fn removePath(this: *Entity) void {
        if (this.path) |*path| {
            path.deinit();
            this.path = null;
        }
    }

    pub fn setNewPath(this: *Entity, newPath: Pathfinder.Path) void {
        if (this.path) |*path| {
            path.deinit();
        }
        this.path = newPath;
    }

    pub fn removePathGoal(this: *Entity) void {
        if (this.path) |*path| {
            path.deinit();
            this.path = null;
        }
        this.goal = null;
    }

    pub fn finishMovement(this: *Entity) void {
        this.hasMoved = true;
        this.movedDistance = 0;
    }
};

pub fn updatePlayer(entity: *Entity, game: *Game.Game) !void {
    // everything else is handled in the playerController
    if (TurnManager.turn != .player or !entity.inCombat) {
        return;
    }
    const grid = World.getCurrentLevel().grid;
    const entitiesPosHash = &EntityManager.positionHash;

    try Movement.updateEntity(game.player, game, grid, entitiesPosHash);

    if (entity.hasAttacked) {
        entity.turnTaken = true;
    }
}
pub fn updatePuppet(entity: *Entity, game: *Game.Game) !void {
    if (TurnManager.turn != .player) {
        return;
    }

    if (!entity.inCombat) {
        return;
    }

    const grid = World.getCurrentLevel().grid;
    const entitiesPosHash = &EntityManager.positionHash;

    try Movement.updateEntity(entity, game, grid, entitiesPosHash);

    if (entity.hasAttacked) {
        entity.turnTaken = true;
    }
}
pub fn updateEnemy(entity: *Entity, game: *Game.Game) !void {
    //TODO: figure out where to put this,
    //good for now, might need some updating
    //later even if its not mu turn
    if (TurnManager.turn != .enemy) {
        return;
    }

    if (entity.inCombat) {
        if (entity.aiBehaviourCombat == null) {
            return error.value_missing;
        }
        try entity.aiBehaviourCombat.?(entity, game);
    } else {
        if (entity.aiBehaviourWalking == null) {
            return error.value_missing;
        }
        try entity.aiBehaviourWalking.?(entity, game);
    }
}

pub const PlayerData = struct {
    //TODO: player is gonna be a puppetmaster, with his puppets as an army
    //the player himself doesent fight, can swap into a combat mode
    //where puppets enter the level,
    //puppetmaster will get a penalty for moving(puppets cant move this turn)
    //finding new pieces of puppets, crafting gear for them etc.
    //butchering monsters + gathering resources from stuff like chairs, crafting parts for the
    //puppets, maybe in the style of cogmind?
    //
    //Puppetmaster is gonna be a combination of engineer and a necromancer
    //Butchering enemies, destroying stuff like chairs and crafting
    // dark magic like fear to protect the puppetmaster from enemies

    inCombatWith: std.ArrayList(u32),
    puppets: std.ArrayList(u32), //TODO: you can actually loose a puppet
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !PlayerData {
        const inCombatWith: std.ArrayList(u32) = .empty;
        const puppets: std.ArrayList(u32) = .empty;

        return PlayerData{
            .inCombatWith = inCombatWith,
            .puppets = puppets,
            .allocator = allocator,
        };
    }

    pub fn allPupsDeployed(this: *PlayerData) bool {
        if (this.puppets.items.len == 0) {
            return true;
        }

        for (this.puppets.items) |pupID| {
            const puppet = EntityManager.getInactiveEntityID(pupID);
            if (puppet != null) {
                return false;
            }
        }
        return true;
    }
};

pub const EnemyData = struct {
    //TODO: add a callback for enemy ai, call from the main update function in entity i think ??

    //TODO: move goal to base entity
    //goal: ?Types.Vector2Int,
    asd: bool,

    // lastSeenPlayerPos: ?Types.Vector2Int,
    // aggressionRange: u32, //do i want this or should you just always fight everyone?
};

pub const ItemData = struct {};

pub const PuppetData = struct {
    deployed: bool,
};

//TODO: maybe put into another file?
pub fn aiBehaviourAggresiveMellee(entity: *Entity, game: *Game.Game) anyerror!void {
    const grid = World.getCurrentLevel().grid;
    const entitiesPosHash = &EntityManager.positionHash;
    if (entity.goal == null or entity.stuck >= 2) {
        const position = game.player.pos;
        const availablePosition = Movement.getAvailableTileAround(position, grid, entitiesPosHash);
        entity.goal = availablePosition;
    }

    //TODO: change this
    if (entity.stuck > 2) {
        entity.turnTaken = true;
    }

    try Movement.updateEntity(entity, game, grid, entitiesPosHash);
    if (entity.hasMoved) {
        //TODO: make more complex
        entity.turnTaken = true;
    }
}

pub fn aiBehaviourWander(entity: *Entity, game: *Game.Game) anyerror!void {
    const grid = World.getCurrentLevel().grid;
    const entitiesPosHash = &EntityManager.positionHash;

    if (entity.goal == null or entity.stuck >= 2) {
        const position = Systems.getRandomValidPosition(World.getCurrentLevel().grid);
        entity.goal = position;
    }

    try Movement.updateEntity(entity, game, grid, entitiesPosHash);

    if (entity.hasMoved) {
        entity.turnTaken = true;
    }
}
