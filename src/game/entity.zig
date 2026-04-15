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
const Combat = @import("../game/combat.zig");
const rl = @import("raylib");
const Allocators = @import("../common/allocators.zig");

pub const EntityType = enum {
    player, // there could be an enemy puppet master
    puppet, // there could be an enemy puppet, would be cool loot(parts for the puppets, may be the way to optain head, torso)
    enemy,
    item,
};

pub var entity_id: u32 = 1;

pub const EntityData = union(EntityType) {
    player: PlayerData,
    //TODO: @continue make my own array type, comptime size?
    puppet: PuppetData,
    enemy: EnemyData,
    item: ItemData,
};

//TODO: lets not add rpg stats,
//too complicated for balancing
//would be alot more work
// make the game without progression / balance first
pub const Entity = struct {
    index: usize,
    name: [:0]const u8 = "",
    active: bool = true,
    alive: bool = true,
    health: i32,
    mana: i32,
    tp: i32,
    attack: i32,
    pos: Types.Vector2Int,
    worldPos: Types.Vector3Int = Types.Vector3Int.init(0, 0, 0),
    goal: ?Types.Location = null, //TODO: @continue
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
        pos: Types.Vector2Int,
        speed: f32,
        entityData: anytype,
    ) !Entity {
        const entity = Entity{
            //TODO: entity id is index, get it from manager
            .index = 0,
            .health = 10,
            .mana = 10,
            .tp = 0,
            .attack = 10,
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

    pub fn deinit(this: *Entity) void {
        if (this.path) |*path| {
            path.deinit();
        }

        if (this.data == .player) {
            this.data.player.inCombatWith.deinit(Allocators.persistent);
        }
    }

    pub fn draw(this: *Entity) void {
        if (this.visible) {
            if (this.path) |path| {
                Pathfinder.drawPath(path);
            }
            if (this.goal) |goal| {
                rl.drawRectangleLines(goal.pos.x * Config.tile_width, goal.pos.y * Config.tile_height, Config.tile_width, Config.tile_height, rl.Color.yellow);
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
        var puppets = this.data.player.puppets;
        for (puppets.items[0..puppets.len]) |pupHandle| {
            const puppet = EntityManager.getEntityHandle(pupHandle);
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
            const puppets = this.data.player.puppets;
            for (puppets.items[0..puppets.len]) |pupHandle| {
                const puppet = EntityManager.getEntityHandle(pupHandle);
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

    pub fn move(this: *Entity, level: *Level.Level, moveTo: Types.Vector2Int) !void {
        //TODO: should i add canmove check?

        const fromPos = this.pos;

        this.pos = moveTo;

        level.moveEntity(fromPos, moveTo);

        if (this.active) {
            if (this.data == .player or this.data == .puppet) {
                Systems.calculateFOV(this.pos, 8);
            }
        }
    }

    pub fn forceMove(this: *Entity, moveTo: Types.Vector2Int) !void {
        this.pos = moveTo;
    }

    pub fn moveLevel(this: *Entity, to: Types.Location) !void {
        const from = Types.Location.init(this.worldPos, this.pos);

        const fromIndex = Utils.posToIndex(from.pos) orelse return;
        const toIndex = Utils.posToIndex(to.pos) orelse return;

        const levelFrom = World.getLevelAt(from.worldPos) orelse return;
        const levelTo = World.getLevelAt(to.worldPos) orelse return;

        levelTo.grid[toIndex].entity = levelFrom.grid[fromIndex].entity;
        levelFrom.grid[fromIndex].entity = null;

        this.worldPos = to.worldPos;
        this.pos = to.pos;

        if (this.active) {
            if (this.data == .player or this.data == .puppet) {
                Systems.calculateFOV(this.pos, 8);
            }
        }
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

    pub fn damage(this: *Entity, ammount: i32) !void {
        this.health -= ammount;
        if (this.health <= 0) {
            this.alive = false;
            //TODO: do i want to have dead bodies?
            const slot = EntityManager.entities.at(this.index);
            const handle = EntityManager.Handle.init(this.index, slot.generation);
            try EntityManager.despawnQueue.append(Allocators.persistent, handle);
        }
    }

    pub fn getPuppetsIds(this: *Entity) []u32 {
        const result = []u32;
        if (this.data == .player) {
            result = this.data.player.puppets;
        }

        return result;
    }

    pub fn getPuppets(this: *Entity) !Types.StaticArray(*Entity, 8) {
        var result = Types.StaticArray(*Entity, 8){};
        if (this.data == .player) {
            const pups = this.data.player.puppets;
            for (pups.items[0..pups.len]) |handle| {
                const entity = EntityManager.getEntityHandle(handle);
                if (entity) |e| {
                    try result.append(e);
                }
            }
        }

        return result;
    }
};

pub fn updatePlayer(entity: *Entity, game: *Game.Game) !void {
    // everything else is handled in the playerController
    if (TurnManager.turn != .player or !entity.inCombat) {
        return;
    }
    const level = World.getCurrentLevel();

    try Movement.updateEntity(game.player, game, level);

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

    const level = World.getCurrentLevel();

    try Movement.updateEntity(entity, game, level);

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

    deployDistance: u32 = 1,
    inCombatWith: std.ArrayList(EntityManager.Handle),
    //TODO: how does this arraylist work in memory?, how is it laid out?
    puppets: Types.StaticArray(EntityManager.Handle, 8),

    pub fn init() !PlayerData {
        //TODO: @memory deallocate
        //testing what happens if i dont
        const inCombatWith: std.ArrayList(EntityManager.Handle) = .empty;
        var puppets = Types.StaticArray(EntityManager.Handle, 8){};
        puppets.zero();

        return PlayerData{
            .inCombatWith = inCombatWith,
            .puppets = puppets,
        };
    }

    pub fn allPupsDeployed(this: *PlayerData) bool {
        var puppets = this.puppets;
        if (puppets.len == 0) {
            return true;
        }

        for (puppets.items[0..puppets.len]) |pupHandle| {
            const puppet = EntityManager.getEntityHandle(pupHandle);
            std.debug.assert(puppet != null);
            if (puppet) |pup| {
                if (!pup.active) {
                    return false;
                }
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
//TODO: combat only on one level, no transitions
pub fn aiBehaviourAggresiveMellee(entity: *Entity, game: *Game.Game) anyerror!void {
    const level = World.getLevelAt(entity.worldPos) orelse return;

    var playerEntities = try EntityManager.getPlayerEntities();
    //TODO: add vision
    const closestEntity = Combat.closestEntity(entity.pos, playerEntities.slice());
    if (closestEntity) |closestentity| {
        if (entity.goal == null or entity.stuck >= 2) {
            const location = Types.Location.init(closestentity.worldPos, closestentity.pos);
            const attackPosition = try Movement.getClosestAttackPositionAround(Allocators.scratch, entity, location, level.grid);

            if (attackPosition) |ap| {
                const attackLocation = Types.Location.init(level.worldPos, ap);
                entity.goal = attackLocation;
            }
        }
    }

    //TODO: change this
    if (entity.stuck > 2) {
        entity.stuck = 0;
        entity.turnTaken = true;
    }

    try Movement.updateEntity(entity, game, level);
    if (entity.hasMoved) {
        //TODO: priorities

        //TODO: @continue, @finish

        var canAttack = false;

        if (closestEntity) |closestEntity_| {
            if (Combat.canAttack(entity, closestEntity_)) {
                canAttack = true;
                //TODO
                try Combat.attack(entity, closestEntity_);
                entity.hasAttacked = true;
            }
        }

        // cant attack, skip
        if (!canAttack) {
            entity.hasAttacked = true;
        }
    }
    if (entity.hasMoved and entity.hasAttacked) {
        //TODO: make more complex
        entity.turnTaken = true;
    }
}

pub fn aiBehaviourWander(entity: *Entity, game: *Game.Game) anyerror!void {
    const level = World.getLevelAt(entity.worldPos) orelse return;

    if (entity.goal == null or entity.stuck >= 2) {
        const position = Systems.getRandomValidPosition(World.getLevelAt(entity.worldPos).?.grid);
        const location = Types.Location.init(entity.worldPos, position);
        entity.goal = location;
    }

    try Movement.updateEntity(entity, game, level);

    if (entity.hasMoved) {
        entity.turnTaken = true;
    }
}
