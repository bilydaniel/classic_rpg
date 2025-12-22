const std = @import("std");
const TilesetManager = @import("tilesetManager.zig");
const Config = @import("../common/config.zig");
const Utils = @import("../common/utils.zig");
const Pathfinder = @import("../game/pathfinder.zig");
const Types = @import("../common/types.zig");
const Systems = @import("Systems.zig");
const Level = @import("level.zig");
const Game = @import("game.zig");
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
    attackDistance: u32,
    isAscii: bool,
    ascii: ?[4]u8,
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
    movementAnimationCooldown: f32,
    inCombat: bool,
    aiBehaviourWalking: ?*const fn (*Entity, *Game.Context) anyerror!void = aiBehaviourWander,
    aiBehaviourCombat: ?*const fn (*Entity, *Game.Context) anyerror!void = aiBehaviourWander,
    data: EntityData,

    pub fn init(
        allocator: std.mem.Allocator,
        pos: Types.Vector2Int,
        levelID: u32,
        speed: f32,
        entityData: anytype,
        asciiChar: []const u8,
    ) !*Entity {
        const entity = try allocator.create(Entity);
        var ascii_array: [4]u8 = .{ 0, 0, 0, 0 };
        const len = @min(asciiChar.len, 3);
        for (0..len) |i| {
            ascii_array[i] = asciiChar[i];
        }
        entity.* = .{
            .id = entity_id,
            .health = 10,
            .mana = 10,
            .tp = 0,
            .attack = 3,
            .pos = pos,
            .levelID = levelID,
            .isAscii = Config.ascii_mode,
            .ascii = ascii_array,
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
            .movementAnimationCooldown = 0,
            .inCombat = false,
            .data = entityData,
        };
        entity_id += 1;
        return entity;
    }

    pub fn Draw(this: *Entity, tilesetManager: *TilesetManager.TilesetManager) void {
        if (this.visible) {
            if (this.isAscii) {
                if (this.ascii) |ascii| {
                    var background_color = this.backgroundColor;
                    if (this.tempBackground) |temp_color| {
                        background_color = temp_color;
                    }

                    const font_size = 16;
                    const text_width = c.MeasureText(&ascii[0], font_size);
                    const text_height = font_size; // Approximate height

                    const x = (this.pos.x * Config.tile_width + @divFloor((Config.tile_width - text_width), 2));
                    const y = (this.pos.y * Config.tile_height + @divFloor((Config.tile_height - text_height), 2));

                    c.DrawRectangle(@intCast(this.pos.x * Config.tile_width), @intCast(this.pos.y * Config.tile_height), Config.tile_width, Config.tile_height, background_color);

                    if (this.data == .enemy) {
                        //TODO: figure out colors for everything
                        //this.color = c.RED;
                    }

                    c.DrawText(&ascii[0], @intCast(x), @intCast(y), 16, this.color);
                }
            } else {
                if (this.sourceRect) |source_rect| {
                    const x: f32 = @floatFromInt(this.pos.x * Config.tile_width);
                    const y: f32 = @floatFromInt(this.pos.y * Config.tile_height);
                    const pos = c.Vector2{ .x = x, .y = y };

                    var color = c.WHITE;
                    if (this.data == .enemy) {
                        color = c.RED;
                    }
                    c.DrawTextureRec(tilesetManager.tileset, source_rect, pos, color);
                }
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
        for (this.data.player.puppets.items) |pup| {
            pup.visible = false;
            pup.targetable = false;
            pup.data.puppet.deployed = false;

            //TODO: hack, probably should add an extra variable like targetable or something
            pup.pos.x = -1;
            pup.pos.y = -1;
        }
    }

    pub fn allPupsTurnTaken(this: *Entity) bool {
        if (this.data == .player) {
            for (this.data.player.puppets.items) |pup| {
                if (pup.turnTaken == false) {
                    return false;
                }
            }
        }
        return true;
    }

    pub fn setTextureID(this: *Entity, id: i32) void {
        this.textureID = id;
        this.sourceRect = Utils.makeSourceRect(id);
    }

    pub fn update(this: *Entity, ctx: *Game.Context) !void {
        switch (this.data) {
            //TODO: see if it needs to be separated or not, change later
            .player => try Systems.updatePlayerEntity(this, ctx),
            .puppet => try Systems.updatePuppetEntity(this, ctx),
            .enemy => try Systems.updateEnemyEntity(this, ctx),
            .item => {}, //TODO: later
        }
    }

    pub fn move(this: *Entity, pos: Types.Vector2Int, grid: *[]Level.Tile) void {
        this.pos = pos;
        Systems.calculateFOV(grid, pos, 8);
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

            for (this.data.player.puppets.items) |pup| {
                pup.hasMoved = false;
                pup.hasAttacked = false;
                pup.turnTaken = false;
            }
        }
    }

    pub fn canAttack(this: *Entity, ctx: *Game.Context) bool {
        _ = this;
        _ = ctx;
        //TODO: @finish
        return false;
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

    inCombatWith: std.ArrayList(*Entity),
    state: playerStateEnum,
    puppets: std.ArrayList(*Entity), //TODO: you can actually loose a puppet

    pub fn init(allocator: std.mem.Allocator) !PlayerData {
        const inCombatWith = std.ArrayList(*Entity).init(allocator);
        var puppets = std.ArrayList(*Entity).init(allocator);

        const pup_pos = Types.Vector2Int{ .x = -1, .y = -1 };
        var puppet = try Entity.init(allocator, pup_pos, 0, 1.0, EntityData{ .puppet = .{ .deployed = false } }, "&");
        puppet.visible = false;
        puppet.name = "Pamama";
        puppet.setTextureID(50);
        try puppets.append(puppet);

        // var puppet2 = try Entity.init(allocator, pup_pos, 0, 1.0, EntityData{ .puppet = .{ .deployed = false } }, "%");
        // puppet2.visible = false;
        // puppet2.name = "Igor";
        // puppet2.setTextureID(51);
        // try puppets.append(puppet2);
        //
        // var puppet3 = try Entity.init(allocator, pup_pos, 0, 1.0, EntityData{ .puppet = .{ .deployed = false } }, "%");
        // puppet3.visible = false;
        // puppet3.name = "R2D2";
        // puppet3.setTextureID(51);
        // try puppets.append(puppet3);

        return PlayerData{
            .state = .walking,
            .inCombatWith = inCombatWith,
            .puppets = puppets,
        };
    }

    pub fn allPupsDeployed(this: *PlayerData) bool {
        for (this.puppets.items) |pup| {
            if (!pup.data.puppet.deployed) {
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
pub fn aiBehaviourAggresiveMellee(entity: *Entity, ctx: *Game.Context) anyerror!void {
    _ = entity;
    _ = ctx;
}

pub fn aiBehaviourWander(entity: *Entity, ctx: *Game.Context) anyerror!void {
    if (entity.goal == null) {
        const position = Systems.getRandomValidPosition(ctx.grid.*);
        entity.goal = position;
    }
}
