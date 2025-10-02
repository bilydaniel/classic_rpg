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
    health: i32,
    mana: i32,
    tp: i32,
    pos: Types.Vector2Int,
    levelID: u32,
    path: ?Pathfinder.Path,
    speed: f32,
    movementCooldown: f32, //TODO: probably do a different way
    movementDistance: u32,
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
            .pos = pos,
            .levelID = levelID,
            .isAscii = Config.ascii_mode,
            .ascii = ascii_array,
            .textureID = null,
            .sourceRect = null,
            .movementCooldown = 0,
            .movementDistance = 2,
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

    pub fn startCombatSetup(this: *Entity, entities: *std.ArrayList(*Entity), grid: []Level.Tile) !void {
        if (this.data == .player) {
            //TODO: filter out entities that are supposed to be in the combat
            // could be some mechanic around attention/stealth
            // smarter entities shout at other to help etc...

            this.data.player.state = .deploying_puppets;
            this.inCombat = true;

            for (entities.items) |entity| {
                try this.data.player.inCombatWith.append(entity);
                entity.resetPathing();
                entity.inCombat = true;
            }
            _ = grid;
            //try Systems.deployPuppets(&this.data.player.puppets, entities, grid);
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

    pub fn updateEnemy(this: *Entity, ctx: *Game.Context) !void {
        if (ctx.gamestate.currentTurn != .enemy) {
            return;
        }

        switch (this.inCombat) {
            true => {
                const left = Types.Vector2Int.init(-1, 0);
                this.wander(Types.vector2IntAdd(this.pos, left), ctx);
            },
            false => {},
        }

        if (this.data == .enemy and ctx.gamestate.currentTurn == .enemy) {
            if (this.data.enemy.goal) |goal| {
                if (this.path == null) {
                    //TODO: @continue fix pathing, take moving entities into account, thing about how to do it
                    this.path = try ctx.pathfinder.findPath(ctx.grid.*, this.pos, goal, ctx.entities.*);
                }
            }
        }
    }

    pub fn update(this: *Entity, ctx: *Game.Context) !void {
        if (this.data == .enemy) {
            try this.updateEnemy(ctx);
        }
        if (this.data == .player and ctx.gamestate.currentTurn != .player) {
            return;
        }

        if (this.path) |path| {
            if (path.nodes.items.len < 2) {
                return;
            }

            this.movementAnimationCooldown += ctx.delta;
            this.movementAnimationCooldown = 0;
            this.path.?.currIndex += 1;
            const new_pos = this.path.?.nodes.items[this.path.?.currIndex];
            const new_pos_entity = Systems.getEntityByPos(ctx.entities.*, new_pos);

            if (new_pos_entity) |_| {
                // position has entity, recalculate
                if (this.data.enemy.goal) |goal| {
                    this.path = try ctx.pathfinder.findPath(ctx.grid.*, this.pos, goal, ctx.entities.*);
                }
            } else {
                this.move(new_pos, ctx.grid);
            }

            if (this.path) |path_| {
                if (path_.currIndex >= this.path.?.nodes.items.len - 1) {
                    this.path = null;
                }
            }
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
        this.pos = pos;
    }

    pub fn resetPathing(this: *Entity) void {
        if (this.data == .enemy) {
            this.data.enemy.goal = null;
        }
        this.path = null;
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
        var puppet2 = try Entity.init(allocator, pup_pos, 0, 1.0, EntityData{ .puppet = .{ .deployed = false } }, "%");
        puppet2.visible = false;

        puppet.setTextureID(50);
        puppet2.setTextureID(51);

        try puppets.append(puppet);
        try puppets.append(puppet2);
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
    goal: ?Types.Vector2Int,
};
pub const ItemData = struct {};
pub const PuppetData = struct {
    deployed: bool,
};
