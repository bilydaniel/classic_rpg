const std = @import("std");
const World = @import("world.zig");
const TilesetManager = @import("tilesetManager.zig");
const Config = @import("../common/config.zig");
const Utils = @import("../common/utils.zig");
const Pathfinder = @import("../game/pathfinder.zig");
const Types = @import("../common/types.zig");
const Systems = @import("Systems.zig");
const Level = @import("level.zig");
const Game = @import("game.zig");
const EntityManager = @import("entityManager.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

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

pub const Entity = struct {
    id: u32,
    name: []const u8 = "",
    health: i32,
    mana: i32,
    tp: i32,
    attack: i32,
    pos: Types.Vector2Int,
    levelID: u32,
    goal: ?Types.Vector2Int = null,
    path: ?Pathfinder.Path,
    speed: f32,
    movementCooldown: f32, //TODO: probably do a different way
    movementDistance: u32,
    movedDistance: u32 = 0,
    attackDistance: u32,
    textureID: ?i32,
    sourceRect: ?c.Rectangle,
    color: c.Color,
    backgroundColor: c.Color,
    tempBackground: ?c.Color,
    visible: bool,
    targetable: bool,
    turnTaken: bool,
    hasMoved: bool,
    hasAttacked: bool,
    inCombat: bool,
    aiBehaviourWalking: ?*const fn (*Entity, *Game.Game) anyerror!void = aiBehaviourWander,
    aiBehaviourCombat: ?*const fn (*Entity, *Game.Game) anyerror!void = aiBehaviourAggresiveMellee,

    data: EntityData,

    pub fn init(
        allocator: std.mem.Allocator,
        pos: Types.Vector2Int,
        levelID: u32,
        speed: f32,
        entityData: anytype,
        asciiChar: []const u8,
    ) !Entity {
        //const entity = try allocator.create(Entity);
        _ = allocator;
        var ascii_array: [4]u8 = .{ 0, 0, 0, 0 };
        const len = @min(asciiChar.len, 3);
        for (0..len) |i| {
            ascii_array[i] = asciiChar[i];
        }
        const entity = Entity{
            .id = entity_id,
            .health = 10,
            .mana = 10,
            .tp = 0,
            .attack = 3,
            .pos = pos,
            .levelID = levelID,
            .textureID = null,
            .sourceRect = null,
            .movementCooldown = 0,
            .movementDistance = 2,
            .attackDistance = 1,
            .speed = speed,
            .path = null,
            .color = c.WHITE,
            .backgroundColor = c.BLACK,
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
                c.DrawRectangleLines(goal.x * Config.tile_width, goal.y * Config.tile_height, Config.tile_width, Config.tile_height, c.YELLOW);
            }

            if (this.sourceRect) |source_rect| {
                const x: f32 = @floatFromInt(this.pos.x * Config.tile_width);
                const y: f32 = @floatFromInt(this.pos.y * Config.tile_height);
                const pos = c.Vector2{ .x = x, .y = y };

                var color = c.WHITE;
                if (this.data == .enemy) {
                    color = c.RED;
                }
                c.DrawTextureRec(TilesetManager.tileset, source_rect, pos, color);
            }
        }
    }

    pub fn endCombat(this: *Entity) void {
        if (this.data == .player) {
            this.data.player.state = .walking;
            this.data.player.inCombatWith.clearRetainingCapacity();
            this.returnPuppets();
        }
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

    pub fn setTextureID(this: *Entity, id: i32) void {
        this.textureID = id;
        this.sourceRect = Utils.makeSourceRect(id);
    }

    pub fn update(this: *Entity, ctx: *Game.Game) !void {
        switch (this.data) {
            //TODO: see if it needs to be separated or not, change later
            .player => try Systems.updatePlayer(this, ctx),
            .puppet => try Systems.updatePuppet(this, ctx),
            .enemy => try Systems.updateEnemy(this, ctx),
            .item => {}, //TODO: later
        }
    }

    pub fn move(this: *Entity, pos: Types.Vector2Int) void {
        this.pos = pos;
        Systems.calculateFOV(pos, 8);
    }

    pub fn wander(this: *Entity, pos: Types.Vector2Int, ctx: *Game.Context) void {
        const index = Systems.posToIndex(pos);
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
            path = null;
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
};

pub const playerStateEnum = enum {
    walking,
    deploying_puppets,
    in_combat,
};

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
    state: playerStateEnum,
    puppets: std.ArrayList(u32), //TODO: you can actually loose a puppet

    pub fn init(allocator: std.mem.Allocator) !PlayerData {
        const inCombatWith = std.ArrayList(u32).init(allocator);
        const puppets = std.ArrayList(u32).init(allocator);

        return PlayerData{
            .state = .walking,
            .inCombatWith = inCombatWith,
            .puppets = puppets,
        };
    }

    pub fn allPupsDeployed(this: *PlayerData) bool {
        for (this.puppets.items) |pupID| {
            const puppet = EntityManager.getEntityID(pupID);
            if (puppet) |pup| {
                if (!pup.data.puppet.deployed) {
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
    pathRecalculated: i32 = 0,

    // lastSeenPlayerPos: ?Types.Vector2Int,
    // aggressionRange: u32, //do i want this or should you just always fight everyone?
};

pub const ItemData = struct {};

pub const PuppetData = struct {
    deployed: bool,
};

//TODO: maybe put into another file?
pub fn aiBehaviourAggresiveMellee(entity: *Entity, game: *Game.Game) anyerror!void {
    std.debug.print("combat\n", .{});
    if (entity.goal == null) {
        const position = game.player.pos;
        entity.goal = position;
    }

    try Systems.updateEntityMovement(entity, game);

    entity.turnTaken = true;
}

pub fn aiBehaviourWander(entity: *Entity, game: *Game.Game) anyerror!void {
    if (entity.goal == null) {
        const position = Systems.getRandomValidPosition(World.currentLevel.grid);
        entity.goal = position;
    }

    try Systems.updateEntityMovement(entity, game);

    entity.turnTaken = true;
}
