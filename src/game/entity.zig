const std = @import("std");
const Config = @import("../common/config.zig");
const Pathfinder = @import("../game/pathfinder.zig");
const Types = @import("../common/types.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

const EntityType = enum {
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
    pos: Types.Vector2Int,
    path: ?Pathfinder.Path,
    speed: f32,
    movementCooldown: f32, //TODO: probably do a different way
    isAscii: bool,
    ascii: ?[4]u8,
    color: c.Color,
    backgroundColor: c.Color,
    data: EntityData,

    pub fn init(
        allocator: std.mem.Allocator,
        pos: Types.Vector2Int,
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
            .pos = pos,
            .isAscii = true, //TODO: finish later, figure out tile versio
            .ascii = ascii_array,
            .movementCooldown = 0,
            .speed = speed,
            .path = null,
            .color = c.WHITE,
            .backgroundColor = c.BLACK,
            .data = entityData,
        };
        entity_id += 1;
        return entity;
    }

    pub fn Draw(this: *Entity) void {
        if (this.isAscii) {
            if (this.ascii) |ascii| {
                c.DrawRectangle(@intCast(this.pos.x * Config.tile_width), @intCast(this.pos.y * Config.tile_height), Config.tile_width, Config.tile_height, this.backgroundColor);

                const font_size = 16;
                const text_width = c.MeasureText(&ascii[0], font_size);
                const text_height = font_size; // Approximate height

                const x = (this.pos.x * Config.tile_width + @divFloor((Config.tile_width - text_width), 2));
                const y = (this.pos.y * Config.tile_height + @divFloor((Config.tile_height - text_height), 2));

                //TODO: fix centering
                c.DrawText(&ascii[0], @intCast(x), @intCast(y), 16, this.color);
            }
        }
    }
};

pub const PlayerData = struct {
    //TODO: player is gonna be a puppetmaster, with his puppets as an army
    //the player himself doesent fight, can swap into a combat mode
    //where puppets enter the level,
    //puppetmaster will get a penalty for moving(puppets cant move this turn)
    //finding new pieces of puppets, crafting gear for them etc.
    //butchering monsters + gathering resources from stuff like chairs, crafting parts for the
    //puppets, maybe in the style of cogmind?

    asd: bool,
};
pub const EnemyData = struct {
    qwe: bool,
};
pub const ItemData = struct {};
pub const PuppetData = struct {};
