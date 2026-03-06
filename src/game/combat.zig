const std = @import("std");
const Entity = @import("entity.zig");
const Types = @import("../common/types.zig");

pub fn checkCombatStart(player: *Entity.Entity, entities: std.ArrayList(Entity.Entity)) bool {
    for (entities.items) |e| {
        if (e.data == .enemy) {
            //TODO: remove prints
            // std.debug.print("player: {}\n", .{player.worldPos});
            // std.debug.print("e: {}\n", .{e.worldPos});
            // std.debug.print("***************\n", .{});
            if (Types.vector3IntCompare(player.worldPos, e.worldPos)) {
                const distance = Types.vector2Distance(player.pos, e.pos);
                if (distance < 3) {
                    return true;
                }
            }
        }
    }
    return false;
}
