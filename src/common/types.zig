const std = @import("std");
const Config = @import("../common/config.zig");
const Level = @import("../game/level.zig");
const EntityManager = @import("../game/entityManager.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const Grid = []Level.Tile;
pub const PositionHash = std.AutoHashMap(Vector2Int, usize);
pub const IdHash = std.AutoHashMap(u32, usize);

const ErrorSet = error{
    value_missing,
};

pub const Vector2Int = struct {
    x: i32,
    y: i32,

    pub fn init(x: i32, y: i32) Vector2Int {
        return Vector2Int{
            .x = x,
            .y = y,
        };
    }
};

pub const Vector3Int = struct {
    x: i32,
    y: i32,
    z: i32,

    pub fn init(x: i32, y: i32, z: i32) Vector3Int {
        return Vector3Int{
            .x = x,
            .y = y,
            .z = z,
        };
    }
};

pub const Location = struct {
    worldPos: Vector3Int,
    pos: Vector2Int,

    pub fn init(worldPos: Vector3Int, pos: Vector2Int) Location {
        return Location{
            .worldPos = worldPos,
            .pos = pos,
        };
    }
};

pub fn vector2IntCompare(a: Vector2Int, b: Vector2Int) bool {
    return a.x == b.x and a.y == b.y;
}

pub fn vector2IntAdd(a: Vector2Int, b: Vector2Int) Vector2Int {
    return Vector2Int{
        .x = a.x + b.x,
        .y = a.y + b.y,
    };
}

pub fn vector2IntSub(a: Vector2Int, b: Vector2Int) Vector2Int {
    return Vector2Int{
        .x = a.x - b.x,
        .y = a.y - b.y,
    };
}

pub fn vector2IntConvert(a: Vector2Int) c.Vector2 {
    return c.Vector2{
        .x = @floatFromInt(a.x),
        .y = @floatFromInt(a.y),
    };
}

pub fn vector2Distance(a: Vector2Int, b: Vector2Int) u32 {
    const dx = @as(f32, @floatFromInt(a.x - b.x));
    const dy = @as(f32, @floatFromInt(a.y - b.y));
    return @as(u32, @intFromFloat(@floor(@sqrt(dx * dx + dy * dy))));
}
pub fn vector2Convert(a: c.Vector2) Vector2Int {
    return Vector2Int{
        .x = @intFromFloat(a.x),
        .y = @intFromFloat(a.y),
    };
}

pub fn vector2ConvertWithPixels(a: c.Vector2) Vector2Int {
    return Vector2Int{
        .x = @intFromFloat(a.x / Config.tile_width),
        .y = @intFromFloat(a.y / Config.tile_height),
    };
}

pub fn vector2IntToPixels(a: Vector2Int) Vector2Int {
    return Vector2Int{
        .x = a.x * Config.tile_width,
        .y = a.y * Config.tile_height,
    };
}

pub fn vector3IntCompare(a: Vector3Int, b: Vector3Int) bool {
    if (a.x == b.x and a.y == b.y and a.z == b.z) {
        return true;
    }
    return false;
}

pub fn vector3IntAdd(a: Vector3Int, b: Vector3Int) Vector3Int {
    return Vector3Int{
        .x = a.x + b.x,
        .y = a.y + b.y,
        .z = a.z + b.z,
    };
}
