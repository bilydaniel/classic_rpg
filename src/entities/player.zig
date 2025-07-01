const std = @import("std");
const Assets = @import("../game/assets.zig");
const Pathfinder = @import("../game/pathfinder.zig");
const Config = @import("../common/config.zig");
const Types = @import("../common/types.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const Player = struct {
    //TODO: player is gonna be a puppetmaster, with his puppets as an army
    //the player himself doesent fight, can swap into a combat mode
    //where puppets enter the level,
    //puppetmaster will get a penalty for moving(puppets cant move this turn)
    //finding new pieces of puppets, crafting gear for them etc.
    //butchering monsters + gathering resources from stuff like chairs, crafting parts for the
    //puppets, maybe in the style of cogmind?

    pos: Types.Vector2Int,
    dest: ?Types.Vector2Int,
    path: ?Pathfinder.Path,
    speed: i32,
    isAscii: bool,
    ascii: ?[2]u8,
    movementCooldown: f32,
    keyWasPressed: bool,

    pub fn init(allocator: std.mem.Allocator) !*Player {
        const player = try allocator.create(Player);
        player.* = .{
            .pos = Types.Vector2Int.init(3, 2),
            .dest = null,
            .speed = 1,
            .isAscii = true,
            .ascii = .{ '@', 0 },
            .movementCooldown = 0,
            .keyWasPressed = false,
            .path = null,
        };
        return player;
    }

    pub fn Draw(this: *Player, assets: *const Assets.Assets) void {
        //c.DrawTexture(assets.playerTexture, @as(c_int, @intCast(this.x * Config.tile_width)), @as(c_int, @intCast(this.y * Config.tile_height)), c.WHITE);
        _ = assets;
        if (this.isAscii) {
            if (this.ascii) |ascii| {
                c.DrawRectangle(@intCast(this.pos.x * Config.tile_width), @intCast(this.pos.y * Config.tile_height), Config.tile_width, Config.tile_height, c.BLACK);

                //TODO: fix centering of player
                c.DrawText(&ascii[0], @intCast(this.pos.x * Config.tile_width), @intCast(this.pos.y * Config.tile_height), 16, c.WHITE);
            }
        }
    }
};
