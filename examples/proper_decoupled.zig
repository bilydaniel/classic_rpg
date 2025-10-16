const std = @import("std");
const Types = @import("../common/types.zig");

// ============================================================================
// 1. EVENT SYSTEM - Decouple components through messaging
// ============================================================================

pub const EventType = enum {
    // Movement events
    entity_moved,
    entity_move_blocked,

    // Combat events
    combat_started,
    combat_ended,
    entity_attacked,
    entity_damaged,
    entity_died,

    // Level events
    level_changed,
    staircase_used,

    // UI events
    entity_selected,
    entity_deselected,
    cursor_moved,

    // State events
    state_changed,
};

pub const Event = union(EventType) {
    entity_moved: EntityMovedEvent,
    entity_move_blocked: EntityMoveBlockedEvent,
    combat_started: CombatStartedEvent,
    combat_ended: CombatEndedEvent,
    entity_attacked: EntityAttackedEvent,
    entity_damaged: EntityDamagedEvent,
    entity_died: EntityDiedEvent,
    level_changed: LevelChangedEvent,
    staircase_used: StaircaseUsedEvent,
    entity_selected: EntitySelectedEvent,
    entity_deselected: EntityDeselectedEvent,
    cursor_moved: CursorMovedEvent,
    state_changed: StateChangedEvent,
};

// Event data structures
pub const EntityMovedEvent = struct {
    entity_id: u32,
    from: Types.Vector2Int,
    to: Types.Vector2Int,
};

pub const EntityMoveBlockedEvent = struct {
    entity_id: u32,
    attempted_pos: Types.Vector2Int,
    reason: BlockReason,

    pub const BlockReason = enum {
        solid_tile,
        entity_blocking,
        out_of_bounds,
    };
};

pub const CombatStartedEvent = struct {
    player_id: u32,
    enemy_ids: []const u32,
};

pub const CombatEndedEvent = struct {
    player_id: u32,
    victory: bool,
};

pub const EntityAttackedEvent = struct {
    attacker_id: u32,
    target_id: u32,
    damage: i32,
};

pub const EntityDamagedEvent = struct {
    entity_id: u32,
    damage: i32,
    remaining_health: i32,
};

pub const EntityDiedEvent = struct {
    entity_id: u32,
};

pub const LevelChangedEvent = struct {
    from_level: u32,
    to_level: u32,
};

pub const StaircaseUsedEvent = struct {
    entity_id: u32,
    from_pos: Types.Vector2Int,
    to_pos: Types.Vector2Int,
};

pub const EntitySelectedEvent = struct {
    entity_id: u32,
};

pub const EntityDeselectedEvent = struct {
    entity_id: u32,
};

pub const CursorMovedEvent = struct {
    from: Types.Vector2Int,
    to: Types.Vector2Int,
};

pub const StateChangedEvent = struct {
    from_state: []const u8,
    to_state: []const u8,
};

// Event handler function signature
pub const EventHandler = *const fn (event: Event, userdata: ?*anyopaque) void;

pub const EventBus = struct {
    handlers: std.AutoHashMap(EventType, std.ArrayList(HandlerData)),
    allocator: std.mem.Allocator,

    const HandlerData = struct {
        handler: EventHandler,
        userdata: ?*anyopaque,
    };

    pub fn init(allocator: std.mem.Allocator) EventBus {
        return EventBus{
            .handlers = std.AutoHashMap(EventType, std.ArrayList(HandlerData)).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *EventBus) void {
        var iter = self.handlers.iterator();
        while (iter.next()) |entry| {
            entry.value_ptr.deinit();
        }
        self.handlers.deinit();
    }

    pub fn subscribe(self: *EventBus, event_type: EventType, handler: EventHandler, userdata: ?*anyopaque) !void {
        const result = try self.handlers.getOrPut(event_type);
        if (!result.found_existing) {
            result.value_ptr.* = std.ArrayList(HandlerData).init(self.allocator);
        }

        try result.value_ptr.append(HandlerData{
            .handler = handler,
            .userdata = userdata,
        });
    }

    pub fn unsubscribe(self: *EventBus, event_type: EventType, handler: EventHandler) void {
        if (self.handlers.getPtr(event_type)) |handlers| {
            var i: usize = 0;
            while (i < handlers.items.len) {
                if (handlers.items[i].handler == handler) {
                    _ = handlers.swapRemove(i);
                } else {
                    i += 1;
                }
            }
        }
    }

    pub fn emit(self: *EventBus, event: Event) void {
        const event_type = std.meta.activeTag(event);
        if (self.handlers.get(event_type)) |handlers| {
            for (handlers.items) |handler_data| {
                handler_data.handler(event, handler_data.userdata);
            }
        }
    }
};

// ============================================================================
// 2. INTERFACES - Define what things can do, not what they are
// ============================================================================

// Movement interface
pub const IMovable = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        canMoveTo: *const fn (ptr: *anyopaque, pos: Types.Vector2Int) bool,
        moveTo: *const fn (ptr: *anyopaque, pos: Types.Vector2Int) void,
        getPosition: *const fn (ptr: *anyopaque) Types.Vector2Int,
    };

    pub fn canMoveTo(self: IMovable, pos: Types.Vector2Int) bool {
        return self.vtable.canMoveTo(self.ptr, pos);
    }

    pub fn moveTo(self: IMovable, pos: Types.Vector2Int) void {
        self.vtable.moveTo(self.ptr, pos);
    }

    pub fn getPosition(self: IMovable) Types.Vector2Int {
        return self.vtable.getPosition(self.ptr);
    }
};

// Combat interface
pub const ICombatant = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        attack: *const fn (ptr: *anyopaque, target: ICombatant) void,
        takeDamage: *const fn (ptr: *anyopaque, damage: i32) void,
        isAlive: *const fn (ptr: *anyopaque) bool,
        getHealth: *const fn (ptr: *anyopaque) i32,
        getAttackRange: *const fn (ptr: *anyopaque) i32,
    };

    pub fn attack(self: ICombatant, target: ICombatant) void {
        self.vtable.attack(self.ptr, target);
    }

    pub fn takeDamage(self: ICombatant, damage: i32) void {
        self.vtable.takeDamage(self.ptr, damage);
    }

    pub fn isAlive(self: ICombatant) bool {
        return self.vtable.isAlive(self.ptr);
    }

    pub fn getHealth(self: ICombatant) i32 {
        return self.vtable.getHealth(self.ptr);
    }

    pub fn getAttackRange(self: ICombatant) i32 {
        return self.vtable.getAttackRange(self.ptr);
    }
};

// Spatial query interface - for checking world state
pub const ISpatialQuery = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        isPositionWalkable: *const fn (ptr: *anyopaque, pos: Types.Vector2Int) bool,
        isPositionSolid: *const fn (ptr: *anyopaque, pos: Types.Vector2Int) bool,
        getEntityAt: *const fn (ptr: *anyopaque, pos: Types.Vector2Int) ?u32,
        getEntitiesInRange: *const fn (ptr: *anyopaque, pos: Types.Vector2Int, range: i32, allocator: std.mem.Allocator) []u32,
    };

    pub fn isPositionWalkable(self: ISpatialQuery, pos: Types.Vector2Int) bool {
        return self.vtable.isPositionWalkable(self.ptr, pos);
    }

    pub fn isPositionSolid(self: ISpatialQuery, pos: Types.Vector2Int) bool {
        return self.vtable.isPositionSolid(self.ptr, pos);
    }

    pub fn getEntityAt(self: ISpatialQuery, pos: Types.Vector2Int) ?u32 {
        return self.vtable.getEntityAt(self.ptr, pos);
    }

    pub fn getEntitiesInRange(self: ISpatialQuery, pos: Types.Vector2Int, range: i32, allocator: std.mem.Allocator) []u32 {
        return self.vtable.getEntitiesInRange(self.ptr, pos, range, allocator);
    }
};

// ============================================================================
// 3. SERVICES - Centralized systems with clear responsibilities
// ============================================================================

// Movement Service - handles all movement logic
pub const MovementService = struct {
    spatial_query: ISpatialQuery,
    event_bus: *EventBus,

    pub fn init(spatial_query: ISpatialQuery, event_bus: *EventBus) MovementService {
        return MovementService{
            .spatial_query = spatial_query,
            .event_bus = event_bus,
        };
    }

    pub fn requestMove(self: *MovementService, entity_id: u32, movable: IMovable, to: Types.Vector2Int) bool {
        const from = movable.getPosition();

        // Check if move is valid
        if (!self.canMoveTo(to)) {
            self.event_bus.emit(Event{
                .entity_move_blocked = .{
                    .entity_id = entity_id,
                    .attempted_pos = to,
                    .reason = self.getBlockReason(to),
                },
            });
            return false;
        }

        // Perform move
        movable.moveTo(to);

        // Emit event
        self.event_bus.emit(Event{
            .entity_moved = .{
                .entity_id = entity_id,
                .from = from,
                .to = to,
            },
        });

        return true;
    }

    fn canMoveTo(self: *MovementService, pos: Types.Vector2Int) bool {
        if (self.spatial_query.isPositionSolid(pos)) {
            return false;
        }

        if (!self.spatial_query.isPositionWalkable(pos)) {
            return false;
        }

        if (self.spatial_query.getEntityAt(pos) != null) {
            return false;
        }

        return true;
    }

    fn getBlockReason(self: *MovementService, pos: Types.Vector2Int) EntityMoveBlockedEvent.BlockReason {
        if (self.spatial_query.isPositionSolid(pos)) {
            return .solid_tile;
        }

        if (self.spatial_query.getEntityAt(pos) != null) {
            return .entity_blocking;
        }

        return .out_of_bounds;
    }
};

// Combat Service - handles all combat logic
pub const CombatService = struct {
    spatial_query: ISpatialQuery,
    event_bus: *EventBus,
    allocator: std.mem.Allocator,

    pub fn init(spatial_query: ISpatialQuery, event_bus: *EventBus, allocator: std.mem.Allocator) CombatService {
        return CombatService{
            .spatial_query = spatial_query,
            .event_bus = event_bus,
            .allocator = allocator,
        };
    }

    pub fn checkCombatTrigger(self: *CombatService, player_id: u32, player_pos: Types.Vector2Int, trigger_range: i32) bool {
        const nearby_entities = self.spatial_query.getEntitiesInRange(player_pos, trigger_range, self.allocator);
        defer self.allocator.free(nearby_entities);

        if (nearby_entities.len > 0) {
            self.event_bus.emit(Event{
                .combat_started = .{
                    .player_id = player_id,
                    .enemy_ids = nearby_entities,
                },
            });
            return true;
        }

        return false;
    }

    pub fn performAttack(self: *CombatService, attacker_id: u32, attacker: ICombatant, target_id: u32, target: ICombatant) void {
        const damage = 10; // TODO: Calculate from stats

        target.takeDamage(damage);

        self.event_bus.emit(Event{
            .entity_attacked = .{
                .attacker_id = attacker_id,
                .target_id = target_id,
                .damage = damage,
            },
        });

        self.event_bus.emit(Event{
            .entity_damaged = .{
                .entity_id = target_id,
                .damage = damage,
                .remaining_health = target.getHealth(),
            },
        });

        if (!target.isAlive()) {
            self.event_bus.emit(Event{
                .entity_died = .{
                    .entity_id = target_id,
                },
            });
        }

        _ = attacker;
    }

    pub fn canAttack(self: *CombatService, attacker_pos: Types.Vector2Int, attacker_range: i32, target_pos: Types.Vector2Int) bool {
        _ = self;
        const distance = Types.vector2Distance(attacker_pos, target_pos);
        return distance <= attacker_range;
    }
};

// ============================================================================
// 4. ENTITY REGISTRY - Use IDs instead of pointers
// ============================================================================

pub const EntityId = u32;

pub const EntityRegistry = struct {
    next_id: EntityId,
    entities: std.AutoHashMap(EntityId, EntityData),
    positions: std.AutoHashMap(EntityId, Types.Vector2Int),
    allocator: std.mem.Allocator,

    pub const EntityData = struct {
        entity_type: EntityType,
        health: i32,
        max_health: i32,
        attack_power: i32,
        attack_range: i32,
        visible: bool,
    };

    pub const EntityType = enum {
        player,
        puppet,
        enemy,
    };

    pub fn init(allocator: std.mem.Allocator) EntityRegistry {
        return EntityRegistry{
            .next_id = 1,
            .entities = std.AutoHashMap(EntityId, EntityData).init(allocator),
            .positions = std.AutoHashMap(EntityId, Types.Vector2Int).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *EntityRegistry) void {
        self.entities.deinit();
        self.positions.deinit();
    }

    pub fn createEntity(self: *EntityRegistry, entity_type: EntityType, pos: Types.Vector2Int) !EntityId {
        const id = self.next_id;
        self.next_id += 1;

        try self.entities.put(id, EntityData{
            .entity_type = entity_type,
            .health = 100,
            .max_health = 100,
            .attack_power = 10,
            .attack_range = 1,
            .visible = true,
        });

        try self.positions.put(id, pos);

        return id;
    }

    pub fn removeEntity(self: *EntityRegistry, id: EntityId) void {
        _ = self.entities.remove(id);
        _ = self.positions.remove(id);
    }

    pub fn getEntity(self: *EntityRegistry, id: EntityId) ?*EntityData {
        return self.entities.getPtr(id);
    }

    pub fn getPosition(self: *EntityRegistry, id: EntityId) ?Types.Vector2Int {
        return self.positions.get(id);
    }

    pub fn setPosition(self: *EntityRegistry, id: EntityId, pos: Types.Vector2Int) !void {
        try self.positions.put(id, pos);
    }

    pub fn getEntityAt(self: *EntityRegistry, pos: Types.Vector2Int) ?EntityId {
        var iter = self.positions.iterator();
        while (iter.next()) |entry| {
            if (Types.vector2IntCompare(entry.value_ptr.*, pos)) {
                return entry.key_ptr.*;
            }
        }
        return null;
    }

    // Create IMovable interface for an entity
    pub fn asMovable(self: *EntityRegistry, id: EntityId) ?IMovable {
        if (self.getEntity(id) == null) return null;

        const MovableImpl = struct {
            registry: *EntityRegistry,
            entity_id: EntityId,

            fn canMoveToFn(ptr: *anyopaque, pos: Types.Vector2Int) bool {
                const impl: *@This() = @ptrCast(@alignCast(ptr));
                _ = pos;
                // Basic check - you'd add more logic
                return impl.registry.getEntity(impl.entity_id) != null;
            }

            fn moveToFn(ptr: *anyopaque, pos: Types.Vector2Int) void {
                const impl: *@This() = @ptrCast(@alignCast(ptr));
                impl.registry.setPosition(impl.entity_id, pos) catch {};
            }

            fn getPositionFn(ptr: *anyopaque) Types.Vector2Int {
                const impl: *@This() = @ptrCast(@alignCast(ptr));
                return impl.registry.getPosition(impl.entity_id) orelse Types.Vector2Int{ .x = 0, .y = 0 };
            }

            const vtable = IMovable.VTable{
                .canMoveTo = canMoveToFn,
                .moveTo = moveToFn,
                .getPosition = getPositionFn,
            };
        };

        // In real code, you'd need to store this somewhere permanent
        // This is just for illustration
        const impl = self.allocator.create(MovableImpl) catch return null;
        impl.* = .{
            .registry = self,
            .entity_id = id,
        };

        return IMovable{
            .ptr = impl,
            .vtable = &MovableImpl.vtable,
        };
    }
};

// ============================================================================
// 5. EXAMPLE: Refactored Walking State (NO TIGHT COUPLING)
// ============================================================================

pub const DecoupledWalkingState = struct {
    movement_cooldown: f32,
    allocator: std.mem.Allocator,

    // Dependencies are INJECTED through interfaces
    movement_service: *MovementService,
    combat_service: *CombatService,
    entity_registry: *EntityRegistry,
    event_bus: *EventBus,

    pub fn init(
        allocator: std.mem.Allocator,
        movement_service: *MovementService,
        combat_service: *CombatService,
        entity_registry: *EntityRegistry,
        event_bus: *EventBus,
    ) DecoupledWalkingState {
        return DecoupledWalkingState{
            .movement_cooldown = 0,
            .allocator = allocator,
            .movement_service = movement_service,
            .combat_service = combat_service,
            .entity_registry = entity_registry,
            .event_bus = event_bus,
        };
    }

    pub fn update(self: *DecoupledWalkingState, player_id: EntityId, input_direction: ?Types.Vector2Int, delta: f32) !void {
        self.movement_cooldown += delta;

        if (self.movement_cooldown < 0.2) { // Config constant
            return;
        }

        if (input_direction) |direction| {
            try self.handleMovement(player_id, direction);
        }
    }

    fn handleMovement(self: *DecoupledWalkingState, player_id: EntityId, direction: Types.Vector2Int) !void {
        const current_pos = self.entity_registry.getPosition(player_id) orelse return;
        const new_pos = Types.vector2IntAdd(current_pos, direction);

        // Get movable interface
        const movable = self.entity_registry.asMovable(player_id) orelse return;

        // Request movement through service
        if (self.movement_service.requestMove(player_id, movable, new_pos)) {
            self.movement_cooldown = 0;

            // Check for combat trigger through service
            _ = self.combat_service.checkCombatTrigger(player_id, new_pos, 3);
        }
    }
};

//how to use:

const std = @import("std");
const Arch = @import("architecture.zig");
const Types = @import("../common/types.zig");

// ============================================================================
// World Query Implementation - Implements ISpatialQuery
// ============================================================================

pub const WorldSpatialQuery = struct {
    grid: []Level.Tile,
    entity_registry: *Arch.EntityRegistry,
    level_width: i32,
    level_height: i32,

    pub fn init(grid: []Level.Tile, entity_registry: *Arch.EntityRegistry, level_width: i32, level_height: i32) WorldSpatialQuery {
        return WorldSpatialQuery{
            .grid = grid,
            .entity_registry = entity_registry,
            .level_width = level_width,
            .level_height = level_height,
        };
    }

    pub fn asInterface(self: *WorldSpatialQuery) Arch.ISpatialQuery {
        return Arch.ISpatialQuery{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    fn isPositionWalkableFn(ptr: *anyopaque, pos: Types.Vector2Int) bool {
        const self: *WorldSpatialQuery = @ptrCast(@alignCast(ptr));
        const index = self.posToIndex(pos) orelse return false;
        if (index >= self.grid.len) return false;
        return self.grid[index].walkable;
    }

    fn isPositionSolidFn(ptr: *anyopaque, pos: Types.Vector2Int) bool {
        const self: *WorldSpatialQuery = @ptrCast(@alignCast(ptr));
        const index = self.posToIndex(pos) orelse return false;
        if (index >= self.grid.len) return false;
        return self.grid[index].solid;
    }

    fn getEntityAtFn(ptr: *anyopaque, pos: Types.Vector2Int) ?u32 {
        const self: *WorldSpatialQuery = @ptrCast(@alignCast(ptr));
        return self.entity_registry.getEntityAt(pos);
    }

    fn getEntitiesInRangeFn(ptr: *anyopaque, pos: Types.Vector2Int, range: i32, allocator: std.mem.Allocator) []u32 {
        const self: *WorldSpatialQuery = @ptrCast(@alignCast(ptr));

        var result = std.ArrayList(u32).init(allocator);

        var iter = self.entity_registry.positions.iterator();
        while (iter.next()) |entry| {
            const distance = Types.vector2Distance(pos, entry.value_ptr.*);
            if (distance <= range and distance > 0) {
                result.append(entry.key_ptr.*) catch {};
            }
        }

        return result.toOwnedSlice() catch &[_]u32{};
    }

    fn posToIndex(self: *WorldSpatialQuery, pos: Types.Vector2Int) ?usize {
        if (pos.x < 0 or pos.y < 0 or pos.x >= self.level_width or pos.y >= self.level_height) {
            return null;
        }
        return @intCast(pos.y * self.level_width + pos.x);
    }

    const vtable = Arch.ISpatialQuery.VTable{
        .isPositionWalkable = isPositionWalkableFn,
        .isPositionSolid = isPositionSolidFn,
        .getEntityAt = getEntityAtFn,
        .getEntitiesInRange = getEntitiesInRangeFn,
    };
};

// ============================================================================
// Systems - React to events
// ============================================================================

pub const CameraSystem = struct {
    target_entity: ?Arch.EntityId,
    entity_registry: *Arch.EntityRegistry,
    camera: Camera2D,

    pub fn init(entity_registry: *Arch.EntityRegistry, event_bus: *Arch.EventBus) !CameraSystem {
        var system = CameraSystem{
            .target_entity = null,
            .entity_registry = entity_registry,
            .camera = undefined, // Initialize with actual camera
        };

        // Subscribe to events
        try event_bus.subscribe(.entity_selected, onEntitySelected, &system);
        try event_bus.subscribe(.entity_moved, onEntityMoved, &system);

        return system;
    }

    fn onEntitySelected(event: Arch.Event, userdata: ?*anyopaque) void {
        const self: *CameraSystem = @ptrCast(@alignCast(userdata.?));
        if (event == .entity_selected) {
            self.target_entity = event.entity_selected.entity_id;
        }
    }

    fn onEntityMoved(event: Arch.Event, userdata: ?*anyopaque) void {
        const self: *CameraSystem = @ptrCast(@alignCast(userdata.?));
        if (event == .entity_moved) {
            if (self.target_entity) |target| {
                if (target == event.entity_moved.entity_id) {
                    // Update camera position
                    // self.camera.target = ...
                }
            }
        }
    }

    pub fn update(self: *CameraSystem, delta: f32) void {
        _ = delta;
        if (self.target_entity) |entity_id| {
            if (self.entity_registry.getPosition(entity_id)) |pos| {
                // Smoothly move camera to entity position
                _ = pos;
                // self.camera.target = lerp(self.camera.target, pos, delta * 5.0);
            }
        }
    }
};

pub const VFXSystem = struct {
    effects: std.ArrayList(Effect),
    allocator: std.mem.Allocator,

    const Effect = struct {
        pos: Types.Vector2Int,
        effect_type: EffectType,
        duration: f32,
    };

    const EffectType = enum {
        explosion,
        impact,
        slash,
    };

    pub fn init(allocator: std.mem.Allocator, event_bus: *Arch.EventBus) !VFXSystem {
        var system = VFXSystem{
            .effects = std.ArrayList(Effect).init(allocator),
            .allocator = allocator,
        };

        // Subscribe to combat events
        try event_bus.subscribe(.entity_attacked, onEntityAttacked, &system);
        try event_bus.subscribe(.entity_died, onEntityDied, &system);

        return system;
    }

    pub fn deinit(self: *VFXSystem) void {
        self.effects.deinit();
    }

    fn onEntityAttacked(event: Arch.Event, userdata: ?*anyopaque) void {
        const self: *VFXSystem = @ptrCast(@alignCast(userdata.?));
        if (event == .entity_attacked) {
            // Spawn attack effect
            // const pos = get position from entity registry
            self.effects.append(Effect{
                .pos = Types.Vector2Int{ .x = 0, .y = 0 }, // actual position
                .effect_type = .slash,
                .duration = 0.3,
            }) catch {};
        }
    }

    fn onEntityDied(event: Arch.Event, userdata: ?*anyopaque) void {
        const self: *VFXSystem = @ptrCast(@alignCast(userdata.?));
        if (event == .entity_died) {
            // Spawn death effect
            _ = event;
            self.effects.append(Effect{
                .pos = Types.Vector2Int{ .x = 0, .y = 0 },
                .effect_type = .explosion,
                .duration = 0.5,
            }) catch {};
        }
    }

    pub fn update(self: *VFXSystem, delta: f32) void {
        var i: usize = 0;
        while (i < self.effects.items.len) {
            self.effects.items[i].duration -= delta;
            if (self.effects.items[i].duration <= 0) {
                _ = self.effects.swapRemove(i);
            } else {
                i += 1;
            }
        }
    }
};

// ============================================================================
// Main Game - Wire Everything Together
// ============================================================================

pub const Game = struct {
    allocator: std.mem.Allocator,

    // Core systems
    event_bus: Arch.EventBus,
    entity_registry: Arch.EntityRegistry,

    // Services
    movement_service: Arch.MovementService,
    combat_service: Arch.CombatService,

    // Systems
    camera_system: CameraSystem,
    vfx_system: VFXSystem,

    // World data
    world: World,
    spatial_query: WorldSpatialQuery,

    // Player
    player_id: Arch.EntityId,
    player_state: PlayerState,

    // Input
    input_manager: InputManager,

    pub fn init(allocator: std.mem.Allocator) !Game {
        var game = Game{
            .allocator = allocator,
            .event_bus = Arch.EventBus.init(allocator),
            .entity_registry = Arch.EntityRegistry.init(allocator),
            .world = try World.init(allocator),
            .input_manager = try InputManager.init(allocator),
            .spatial_query = undefined,
            .movement_service = undefined,
            .combat_service = undefined,
            .camera_system = undefined,
            .vfx_system = undefined,
            .player_id = 0,
            .player_state = undefined,
        };

        // Create spatial query
        game.spatial_query = WorldSpatialQuery.init(
            game.world.currentLevel.grid,
            &game.entity_registry,
            game.world.currentLevel.width,
            game.world.currentLevel.height,
        );

        // Initialize services with dependencies
        const spatial_interface = game.spatial_query.asInterface();
        game.movement_service = Arch.MovementService.init(spatial_interface, &game.event_bus);
        game.combat_service = Arch.CombatService.init(spatial_interface, &game.event_bus, allocator);

        // Initialize systems
        game.camera_system = try CameraSystem.init(&game.entity_registry, &game.event_bus);
        game.vfx_system = try VFXSystem.init(allocator, &game.event_bus);

        // Create player entity
        game.player_id = try game.entity_registry.createEntity(.player, Types.Vector2Int{ .x = 10, .y = 10 });

        // Initialize player state with injected dependencies
        game.player_state = try PlayerState.initWalking(
            allocator,
            &game.movement_service,
            &game.combat_service,
            &game.entity_registry,
            &game.event_bus,
        );

        // Subscribe to game events
        try game.setupEventHandlers();

        return game;
    }

    pub fn deinit(self: *Game) void {
        self.event_bus.deinit();
        self.entity_registry.deinit();
        self.world.deinit();
        self.vfx_system.deinit();
        self.player_state.deinit();
        self.input_manager.deinit();
    }

    fn setupEventHandlers(self: *Game) !void {
        // Log important events
        try self.event_bus.subscribe(.combat_started, onCombatStarted, self);
        try self.event_bus.subscribe(.entity_died, onEntityDied, self);
        try self.event_bus.subscribe(.level_changed, onLevelChanged, self);
    }

    fn onCombatStarted(event: Arch.Event, userdata: ?*anyopaque) void {
        _ = userdata;
        if (event == .combat_started) {
            std.debug.print("Combat started! Player vs {} enemies\n", .{event.combat_started.enemy_ids.len});
        }
    }

    fn onEntityDied(event: Arch.Event, userdata: ?*anyopaque) void {
        const self: *Game = @ptrCast(@alignCast(userdata.?));
        if (event == .entity_died) {
            std.debug.print("Entity {} died\n", .{event.entity_died.entity_id});
            self.entity_registry.removeEntity(event.entity_died.entity_id);
        }
    }

    fn onLevelChanged(event: Arch.Event, userdata: ?*anyopaque) void {
        const self: *Game = @ptrCast(@alignCast(userdata.?));
        if (event == .level_changed) {
            std.debug.print("Changed from level {} to {}\n", .{ event.level_changed.from_level, event.level_changed.to_level });
            // Update spatial query with new level
            self.spatial_query = WorldSpatialQuery.init(
                self.world.currentLevel.grid,
                &self.entity_registry,
                self.world.currentLevel.width,
                self.world.currentLevel.height,
            );
        }
    }

    pub fn update(self: *Game, delta: f32) !void {
        // Update input
        self.input_manager.update(self.camera_system.camera);

        // Update player state
        const input_direction = self.input_manager.getMovementInput();
        try self.player_state.update(self.player_id, input_direction, delta);

        // Update systems
        self.camera_system.update(delta);
        self.vfx_system.update(delta);

        // Other game updates...
    }

    pub fn render(self: *Game) void {
        // Render world
        self.world.render();

        // Render entities
        var iter = self.entity_registry.entities.iterator();
        while (iter.next()) |entry| {
            const entity_id = entry.key_ptr.*;
            const entity_data = entry.value_ptr.*;

            if (!entity_data.visible) continue;

            if (self.entity_registry.getPosition(entity_id)) |pos| {
                self.renderEntity(entity_data, pos);
            }
        }

        // Render VFX
        for (self.vfx_system.effects.items) |effect| {
            self.renderEffect(effect);
        }

        // Render UI
        self.renderUI();
    }

    fn renderEntity(self: *Game, entity: Arch.EntityRegistry.EntityData, pos: Types.Vector2Int) void {
        _ = self;
        _ = entity;
        _ = pos;
        // Actual rendering code
    }

    fn renderEffect(self: *Game, effect: VFXSystem.Effect) void {
        _ = self;
        _ = effect;
        // Render effect
    }

    fn renderUI(self: *Game) void {
        _ = self;
        // Render UI elements
    }
};

// ============================================================================
// Player State (using injected dependencies)
// ============================================================================

pub const PlayerState = union(enum) {
    walking: WalkingState,
    deploying: DeployingState,
    combat: CombatState,

    pub fn initWalking(
        allocator: std.mem.Allocator,
        movement_service: *Arch.MovementService,
        combat_service: *Arch.CombatService,
        entity_registry: *Arch.EntityRegistry,
        event_bus: *Arch.EventBus,
    ) !PlayerState {
        return PlayerState{
            .walking = WalkingState{
                .movement_cooldown = 0,
                .allocator = allocator,
                .movement_service = movement_service,
                .combat_service = combat_service,
                .entity_registry = entity_registry,
                .event_bus = event_bus,
            },
        };
    }

    pub fn update(self: *PlayerState, player_id: Arch.EntityId, input_direction: ?Types.Vector2Int, delta: f32) !void {
        switch (self.*) {
            .walking => |*state| try state.update(player_id, input_direction, delta),
            .deploying => |*state| try state.update(player_id, input_direction, delta),
            .combat => |*state| try state.update(player_id, input_direction, delta),
        }
    }

    pub fn deinit(self: *PlayerState) void {
        _ = self;
    }
};

pub const WalkingState = struct {
    movement_cooldown: f32,
    allocator: std.mem.Allocator,

    // Injected dependencies - NO DIRECT COUPLING
    movement_service: *Arch.MovementService,
    combat_service: *Arch.CombatService,
    entity_registry: *Arch.EntityRegistry,
    event_bus: *Arch.EventBus,

    pub fn update(self: *WalkingState, player_id: Arch.EntityId, input_direction: ?Types.Vector2Int, delta: f32) !void {
        self.movement_cooldown += delta;

        if (self.movement_cooldown < 0.2) return;

        if (input_direction) |direction| {
            const current_pos = self.entity_registry.getPosition(player_id) orelse return;
            const new_pos = Types.vector2IntAdd(current_pos, direction);

            // Get movable interface for this entity
            const movable = self.entity_registry.asMovable(player_id) orelse return;

            // Request movement through service (service handles all validation)
            if (self.movement_service.requestMove(player_id, movable, new_pos)) {
                self.movement_cooldown = 0;

                // Check for combat trigger (service emits events if combat starts)
                _ = self.combat_service.checkCombatTrigger(player_id, new_pos, 3);
            }
        }
    }
};

pub const DeployingState = struct {
    allocator: std.mem.Allocator,
    movement_service: *Arch.MovementService,
    combat_service: *Arch.CombatService,
    entity_registry: *Arch.EntityRegistry,
    event_bus: *Arch.EventBus,

    pub fn update(self: *DeployingState, player_id: Arch.EntityId, input_direction: ?Types.Vector2Int, delta: f32) !void {
        _ = self;
        _ = player_id;
        _ = input_direction;
        _ = delta;
        // Implementation...
    }
};

pub const CombatState = struct {
    allocator: std.mem.Allocator,
    movement_service: *Arch.MovementService,
    combat_service: *Arch.CombatService,
    entity_registry: *Arch.EntityRegistry,
    event_bus: *Arch.EventBus,

    pub fn update(self: *CombatState, player_id: Arch.EntityId, input_direction: ?Types.Vector2Int, delta: f32) !void {
        _ = self;
        _ = player_id;
        _ = input_direction;
        _ = delta;
        // Implementation...
    }
};

// ============================================================================
// Placeholder types (you'd import these from actual modules)
// ============================================================================

const Level = struct {
    const Tile = struct {
        solid: bool,
        walkable: bool,
        visible: bool,
        seen: bool,
    };
};

const World = struct {
    currentLevel: struct {
        grid: []Level.Tile,
        width: i32,
        height: i32,
    },

    pub fn init(allocator: std.mem.Allocator) !World {
        _ = allocator;
        return World{
            .currentLevel = .{
                .grid = &[_]Level.Tile{},
                .width = 50,
                .height = 50,
            },
        };
    }

    pub fn deinit(self: *World) void {
        _ = self;
    }

    pub fn render(self: *World) void {
        _ = self;
    }
};

const InputManager = struct {
    pub fn init(allocator: std.mem.Allocator) !InputManager {
        _ = allocator;
        return InputManager{};
    }

    pub fn deinit(self: *InputManager) void {
        _ = self;
    }

    pub fn update(self: *InputManager, camera: Camera2D) void {
        _ = self;
        _ = camera;
    }

    pub fn getMovementInput(self: *InputManager) ?Types.Vector2Int {
        _ = self;
        return null;
    }
};

const Camera2D = struct {
    target: Types.Vector2,
};

// ============================================================================
// BENEFITS OF THIS ARCHITECTURE:
// ============================================================================
//
// 1. TESTABILITY
//    - You can test WalkingState by providing mock services
//    - No need for the entire game context
//
// 2. FLEXIBILITY
//    - Want to change how movement works? Modify MovementService
//    - Want different spatial queries? Provide different ISpatialQuery implementation
//
// 3. CLARITY
//    - Each component has ONE responsibility
//    - Dependencies are explicit and injected
//
// 4. EVENTS DECOUPLE SYSTEMS
//    - Camera doesn't know about player state
//    - VFX doesn't know about combat logic
//    - They just react to events
//
// 5. NO POINTER SOUP
//    - Use IDs instead of raw pointers
//    - Registry manages lifetime
//
// 6. EASY TO EXTEND
//    - Want to add a new system? Subscribe to events
//    - Want to add new behavior? Create new service
//    - Want to add new state? Implement the interface
//
// ============================================================================






Migration Guide: From Tightly Coupled to Decoupled Architecture
Phase 1: Add Event System (Week 1)

Goal: Start communicating through events instead of direct calls.
Step 1: Implement EventBus
zig

// events.zig
pub const EventBus = struct { ... };

Step 2: Add EventBus to Game Context
zig

pub const Context = struct {
    // ... existing fields
    event_bus: *EventBus, // ADD THIS
};

Step 3: Replace One Direct Call with Event

Before:
zig

// In handlePlayerWalking
ctx.cameraManager.followEntity(ctx.player);

After:
zig

// In handlePlayerWalking
ctx.event_bus.emit(Event{
    .entity_moved = .{
        .entity_id = ctx.player.id,
        .from = old_pos,
        .to = new_pos,
    },
});

// In cameraManager.zig
pub fn init(event_bus: *EventBus) !CameraManager {
    var manager = CameraManager{ ... };
    try event_bus.subscribe(.entity_moved, onEntityMoved, &manager);
    return manager;
}

fn onEntityMoved(event: Event, userdata: ?*anyopaque) void {
    const self: *CameraManager = @ptrCast(@alignCast(userdata.?));
    if (event.entity_moved.entity_id == self.target_id) {
        // Update camera
    }
}

Step 4: Migrate More Direct Calls

Do this gradually for:

    Combat starting/ending
    Entity death
    Level changes
    UI updates

Progress Check: After this phase, systems communicate through events but still use the old Context structure.
Phase 2: Extract Services (Week 2)

Goal: Move logic out of helper functions into services.
Step 1: Create MovementService

Before:
zig

// In helpers.zig - scattered everywhere
pub fn canMove(...) bool { }
pub fn moveEntity(...) void { }

After:
zig

// movement_service.zig
pub const MovementService = struct {
    event_bus: *EventBus,
    
    pub fn requestMove(...) bool {
        // All movement logic here
        // Emit events
    }
};

// In game.zig
pub const Game = struct {
    movement_service: MovementService,
    
    pub fn init(...) !Game {
        var game = Game{
            .movement_service = MovementService.init(&game.event_bus),
        };
    }
};

Step 2: Update States to Use Service

Before:
zig

if (moved and canMove(ctx.world.currentLevel.grid, new_pos, ctx.entities.*)) {
    ctx.player.move(new_pos, ctx.grid);
}

After:
zig

if (moved) {
    _ = ctx.movement_service.requestMove(ctx.player.id, new_pos);
}

Step 3: Repeat for Other Services

    CombatService (attack logic, damage calculation)
    LevelService (level switching, staircase logic)
    DeploymentService (puppet deployment logic)

Progress Check: Logic is in services, but Context still has everything.
Phase 3: Introduce Entity Registry (Week 3)

Goal: Replace raw pointers with IDs.
Step 1: Create Entity Registry
zig

pub const EntityRegistry = struct {
    entities: HashMap(EntityId, EntityData),
    // ...
};

Step 2: Migrate One Entity Type

Before:
zig

pub const Entity = struct {
    pos: Vector2Int,
    health: i32,
    // ... tons of fields
};

After:
zig

// Create entity
const player_id = try registry.createEntity(.player, start_pos);

// Access entity
if (registry.getEntity(player_id)) |entity| {
    // Use entity
}

Step 3: Update Services to Use IDs

Before:
zig

pub fn requestMove(entity: *Entity, to: Vector2Int) bool

After:
zig

pub fn requestMove(entity_id: EntityId, to: Vector2Int) bool {
    const entity = self.registry.getEntity(entity_id) orelse return false;
    // ...
}

Progress Check: Entities are managed by registry, accessed by ID.
Phase 4: Add Interfaces (Week 4)

Goal: States depend on interfaces, not concrete types.
Step 1: Define Core Interfaces
zig

pub const ISpatialQuery = struct { ... };
pub const IMovable = struct { ... };
pub const ICombatant = struct { ... };

Step 2: Implement Interface for World
zig

pub const WorldSpatialQuery = struct {
    // ... implementation
    
    pub fn asInterface(self: *WorldSpatialQuery) ISpatialQuery {
        return ISpatialQuery{
            .ptr = self,
            .vtable = &vtable,
        };
    }
};

Step 3: Update Services to Use Interfaces

Before:
zig

pub const MovementService = struct {
    world: *World, // Concrete dependency!
};

After:
zig

pub const MovementService = struct {
    spatial_query: ISpatialQuery, // Interface!
};

Progress Check: Services depend on interfaces, can be tested with mocks.
Phase 5: Slim Down Context (Week 5)

Goal: Context only passes what's needed.
Step 1: Create Minimal State Context

Before:
zig

pub const Context = struct {
    player: *Entity,
    entities: *ArrayList(*Entity),
    gamestate: *Gamestate,
    world: *World,
    grid: *[]Level.Tile,
    input: *InputManager,
    delta: f32,
    allocator: Allocator,
    cameraManager: *CameraManager,
    pathfinder: *Pathfinder,
    shaderManager: *ShaderManager,
    // ... 50 more fields
};

After:
zig

// States only get what they need
pub const WalkingState = struct {
    // Dependencies injected at creation
    movement_service: *MovementService,
    combat_service: *CombatService,
    entity_registry: *EntityRegistry,
    event_bus: *EventBus,
    
    pub fn update(self: *WalkingState, player_id: EntityId, input: InputData, delta: f32) !void {
        // Only uses injected dependencies
    }
};

Step 2: Remove Context Entirely

States are created with their dependencies:
zig

const walking_state = WalkingState{
    .movement_service = &game.movement_service,
    .combat_service = &game.combat_service,
    .entity_registry = &game.entity_registry,
    .event_bus = &game.event_bus,
};

Progress Check: No more giant Context struct!
Phase 6: Polish and Test (Week 6)
Write Tests

Now you CAN test!
zig

test "player moves when valid" {
    var registry = EntityRegistry.init(testing.allocator);
    defer registry.deinit();
    
    var event_bus = EventBus.init(testing.allocator);
    defer event_bus.deinit();
    
    // Mock spatial query
    var mock_query = MockSpatialQuery{
        .walkable = true,
        .entity_at = null,
    };
    
    var movement_service = MovementService.init(mock_query.asInterface(), &event_bus);
    
    const player_id = try registry.createEntity(.player, .{.x = 0, .y = 0});
    
    const result = movement_service.requestMove(player_id, .{.x = 1, .y = 0});
    
    try testing.expect(result == true);
}

Common Pitfalls to Avoid
❌ DON'T: Try to do everything at once

You'll get lost and frustrated.
✅ DO: Migrate one system at a time

Events → Services → Registry → Interfaces → Cleanup
❌ DON'T: Keep adding to Context "temporarily"

It never becomes permanent.
✅ DO: Delete old code aggressively

Once migrated, delete the old version immediately.
❌ DON'T: Make events too granular

entity_pos_x_changed is too much.
✅ DO: Make events meaningful

entity_moved is better.
❌ DON'T: Create "god services"

If your service does everything, you've just moved the problem.
✅ DO: Keep services focused

One clear responsibility per service.
Quick Wins You Can Do TODAY

    Add EventBus (1 hour)
        Create events.zig
        Add to game struct
        Don't use it yet, just have it there
    Extract One Function to Service (2 hours)
        Pick canMove function
        Create movement_service.zig
        Move just that function
        Update call sites
    Replace One Pointer with ID (2 hours)
        Add id: u32 field to Entity
        Add HashMap<u32, Entity> to game
        Use ID in just ONE place
        Keep pointer version working
    Move One UI Update to Event (1 hour)
        Find where you directly call UI update
        Emit event instead
        Subscribe to event in UI code

Start small. Build momentum. Refactor iteratively.
Measuring Success

After full migration, you should be able to:

    ✅ Test any state in isolation
    ✅ Add new systems without touching existing code
    ✅ Change services without breaking states
    ✅ Find where any logic lives in < 10 seconds
    ✅ Understand what any function does by looking at its signature
    ✅ Add features without fear of breaking everything

Resources

    Zig Interfaces: Use tagged unions + vtables (see architecture.zig)
    Entity Component System: Consider this if you have many entity types
    Command Pattern: For undo/redo on moves
    Observer Pattern: What EventBus implements

Good luck! Start with Phase 1 and don't rush it.


