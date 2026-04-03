const std = @import("std");
const Game = @import("../game/game.zig");
const AssetManager = @import("assetManager.zig");
const Entity = @import("../game/entity.zig");
const Window = @import("../game/window.zig");
const Types = @import("../common/types.zig");
const Utils = @import("../common/utils.zig");
const Gamestate = @import("gamestate.zig");
const World = @import("world.zig");
const Systems = @import("Systems.zig");
const CameraManager = @import("cameraManager.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

var allocator: std.mem.Allocator = undefined;

pub const Entities = std.SegmentedList(Slot, 2);
pub var entities: Entities = undefined; //TODO: bigger preallocate, testing for now

pub var freeList: std.ArrayList(usize) = undefined;

pub var playerHandle: Handle = undefined;

pub var spawnQueue: std.ArrayList(Entity.Entity) = undefined;
pub var despawnQueue: std.ArrayList(Handle) = undefined;

const Slot = struct {
    entity: Entity.Entity,
    generation: u32,
    occupied: bool,

    pub fn init(entity: Entity.Entity, generation: u32, occupied: bool) Slot {
        return Slot{
            .entity = entity,
            .generation = generation,
            .occupied = occupied,
        };
    }
};

pub const Handle = struct {
    index: usize,
    generation: u32,

    pub fn init(index: usize, generation: u32) Handle {
        return Handle{
            .index = index,
            .generation = generation,
        };
    }

    pub fn initFirst(index: usize) Handle {
        return Handle{
            .index = index,
            .generation = 1,
        };
    }

    pub fn valid(this: *Handle) bool {
        return (this.generation != 0);
    }
};

pub fn init(alloc: std.mem.Allocator) void {
    allocator = alloc;

    entities = std.SegmentedList(Slot, 2){};
    freeList = std.ArrayList(usize).empty;

    spawnQueue = std.ArrayList(Entity.Entity).empty;
    despawnQueue = std.ArrayList(Handle).empty;
    //TODO: uncomment, testing for now if dangling pointers happen
}

pub fn deinit() void {
    entities.deinit(allocator);
    freeList.deinit(allocator);
    spawnQueue.deinit(allocator);
    despawnQueue.deinit(allocator);
}

//TODO: @finish @continue
pub fn spawnEntities() !void {}
// pub fn despawnEntities() !void {
//     for (despawnQueue.items) |id| {
//         if (id != playerID) {
//             try removeEntityID(id);
//         }
//     }
//
//     despawnQueue.clearRetainingCapacity();
// }

// just a helper funciton, returns the player so it can be used to fill into context
pub fn fillEntities() !void {
    //
    //PLAYER
    //
    const playerData = try Entity.PlayerData.init(allocator);
    var player = try Entity.Entity.init(allocator, Types.Vector2Int{ .x = 3, .y = 2 }, 1, Entity.EntityData{ .player = playerData });
    player.name = "Pepega";
    player.setTextureID(AssetManager.TileNames.player);
    playerHandle = Handle.initFirst(player.index);

    //
    //PUPPET_1
    //
    const pup_pos = Types.Vector2Int{ .x = 1, .y = 1 };
    var puppet = try Entity.Entity.init(allocator, pup_pos, 1.0, Entity.EntityData{ .puppet = .{ .deployed = false } });
    puppet.visible = false;
    puppet.name = "Pamama";
    puppet.setTextureID(AssetManager.TileNames.puppet_1);
    const pupHandle = Handle.initFirst(puppet.index);
    try player.data.player.puppets.append(pupHandle);

    //
    //PUPPET_2
    //
    // const pup_pos_2 = Types.Vector2Int{ .x = 2, .y = 1 };
    // var puppet2 = try Entity.Entity.init(entity_allocator, pup_pos_2, 1.0, Entity.EntityData{ .puppet = .{ .deployed = false } });
    // puppet2.visible = false;
    // puppet2.name = "igor";
    // puppet2.setTextureID(AssetManager.TileNames.puppet_1);
    // try player.data.player.puppets.append(puppet2.id);

    try addActiveEntity(player);
    try addInactiveEntity(puppet);
    //try addInactiveEntity(puppet2);

    //
    //ENEMIES
    //
    const pos = Types.Vector2Int{ .x = 5, .y = 15 };
    const enemy_tile = AssetManager.TileNames.robot_1;
    const enemy_goal_world = Types.Vector3Int.init(0, 0, 0);
    const enemy_goal_pos = Types.Vector2Int.init(2, 2);
    const enemy_goal = Types.Location.init(enemy_goal_world, enemy_goal_pos);

    var entity = try Entity.Entity.init(allocator, pos, 1.0, Entity.EntityData{ .enemy = .{ .asd = true } });
    entity.goal = enemy_goal;

    entity.setTextureID(enemy_tile);

    const pos2 = Types.Vector2Int{ .x = 6, .y = 16 };
    var entity2 = try Entity.Entity.init(allocator, pos2, 1.0, Entity.EntityData{ .enemy = .{ .asd = true } });
    entity2.setTextureID(enemy_tile);

    const pos3 = Types.Vector2Int{ .x = 7, .y = 17 };
    var entity3 = try Entity.Entity.init(allocator, pos3, 1.0, Entity.EntityData{ .enemy = .{ .asd = true } });
    entity3.setTextureID(enemy_tile);

    try addActiveEntity(entity);
    try addActiveEntity(entity2);
    try addActiveEntity(entity3);

    //try addRandomEnemies(100);
}

fn addRandomEnemies(number: usize) !void {
    const enemy_tile = AssetManager.TileNames.robot_1;
    var entity: Entity.Entity = undefined;
    const grid = World.getCurrentLevel().grid;
    for (0..number) |_| {
        const pos = Systems.getRandomMovablePosition(grid);
        entity = try Entity.Entity.init(allocator, pos, 1.0, Entity.EntityData{ .enemy = .{ .asd = true } });
        entity.setTextureID(enemy_tile);
        try addActiveEntity(entity);
    }
}

//TODO: maybe send entity as pointer? entity is kinda big
pub fn addActiveEntity(ent: Entity.Entity) !void {
    var entity = ent;
    if (freeList.items.len > 0) {
        //get the free slot
        const index = freeList.pop() orelse unreachable;

        const oldSlot = entities.at(index);
        //TODO: check, no idea if it works this way

        oldSlot.*.occupied = true;
        oldSlot.*.generation += 1;
        oldSlot.*.entity = entity;
        return; //TODO: maybe return handle?
    }

    entity.active = true;
    const slot = Slot.init(entity, 1, true);
    try entities.append(allocator, slot);

    return; //TODO: maybe return handle?
}

pub fn addInactiveEntity(ent: Entity.Entity) !void {
    var entity = ent;
    if (freeList.items.len > 0) {
        //get the free slot
        const index = freeList.pop() orelse unreachable;

        const oldSlot = entities.at(index);
        //TODO: check, no idea if it works this way

        oldSlot.*.occupied = true;
        oldSlot.*.generation += 1;
        oldSlot.*.entity = entity;
        return; //TODO: maybe return handle?
    }

    entity.active = false;
    const slot = Slot.init(entity, 1, true);
    try entities.append(allocator, slot);

    return; //TODO: maybe return handle?
}

pub fn activateEntity(handle: Handle) !void {
    const entity = getEntityHandle(handle);
    if (entity) |e| {
        e.active = true;
    }
}

pub fn deactivateEntity(handle: Handle) !void {
    const entity = getEntityHandle(handle);
    if (entity) |e| {
        e.active = false;
    }
}

// pub fn removeEntityID(id: u32) !void {
//     const entityIndex = idHash.get(id) orelse return;
//
//     const entity = entities.swapRemove(entityIndex);
//     _ = idHash.remove(entity.id);
//
//     // if we swapremoved any elemnt other than the last
//     if (entityIndex < entities.items.len) {
//         const swappedEntity = entities.items[entityIndex];
//         try idHash.put(swappedEntity.id, entityIndex);
//     }
// }

pub fn draw() void {
    for (entities.items) |*e| {
        if (Types.vector3IntCompare(e.worldPos, World.currentLevel)) {
            e.draw();
        }
    }
}

pub fn allPlayerUnitsTurnTaken() bool {
    const player = getPlayer();
    if (player.inCombat) {
        return player.turnTaken and player.allPupsTurnTaken();
    } else {
        return player.turnTaken;
    }
}

pub fn allEnemiesTurnTaken() bool {
    var turnTaken = true;
    for (entities.items) |entity| {
        if (entity.data == .enemy and !entity.turnTaken) {
            turnTaken = false;
        }
    }
    return turnTaken;
}

pub fn getPlayer() *Entity.Entity {
    const player = getEntityHandle(playerHandle);
    if (player) |p| {
        return p;
    } else {
        unreachable;
    }
}

pub fn getEnemies() []*Entity.Entity {}

pub fn getPuppets() []*Entity.Entity {
    //return &entities.items[PLAYER_INDEX];
}

pub fn getEntityHandle(handle: Handle) ?*Entity.Entity {
    //TODO: do i need to check this?, when should i check it?

    const slot = entities.at(handle.index);
    if (!slot.occupied) {
        return null;
    }
    if (slot.generation != handle.generation) {
        return null;
    }

    return &slot.entity;
}

// pub fn getEntityByPos(pos: Types.Vector2Int, worldPos: Types.Vector3Int) ?*Entity.Entity {
//     //TODO: check if correct
//     const location = Types.Location.init(worldPos, pos);
//     return &entities.items[index];
// }

pub fn filterEntityByPos(entities_: std.ArrayList(Entity.Entity), pos: Types.Vector2Int, worldPos: Types.Vector3Int) ?*Entity.Entity {
    for (entities_.items) |*e| {
        if (Types.vector2IntCompare(e.pos, pos) and Types.vector3IntCompare(e.worldPos, worldPos)) {
            return e;
        }
    }
    return null;
}

pub fn resetTurnFlags() void {
    var iterator = entities.iterator(0);
    while (iterator.next()) |slot| {
        slot.entity.hasMoved = false;
        slot.entity.hasAttacked = false;
        slot.entity.turnTaken = false;
        slot.entity.movedDistance = 0;
    }
}

pub fn deactivatePuppets() !void {
    //TODO: @contitnue @finish, change the puppets in playert from id to handle
    const player = getPlayer();
    for (player.data.player.puppets.items) |id| {
        try deactivateEntity(id);
    }
}

pub fn getEntityIndex(index: usize) ?*Entity.Entity {
    if (index >= entities.items.len) {
        return null;
    }

    return &entities.items[index];
}

pub fn getPlayerEntities() !Types.StaticArray(*Entity.Entity, 16) {
    var playerEntities = Types.StaticArray(*Entity.Entity, 16){};

    const player = getPlayer();
    const pups = try player.getPuppets();

    try playerEntities.append(player);
    for (pups.items[0..pups.len]) |pup| {
        try playerEntities.append(pup);
    }

    return playerEntities;
}

pub fn getPlayerEntitiesIDs() []u32 {
    const playerEntities = Types.StaticArray(u32, 16);

    const player = getPlayer();
    const pups = player.getPuppetsIds();

    playerEntities.append(player.id);
    for (pups.items) |pup| {
        playerEntities.append(pup);
    }
}
