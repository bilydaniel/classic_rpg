const std = @import("std");
const Entity = @import("entity.zig");
const Gamestate = @import("gamestate.zig");
const Level = @import("level.zig");
const Types = @import("../common/types.zig");
const Config = @import("../common/config.zig");
const InputManager = @import("inputManager.zig");

// Forward declare Context to avoid circular dependency
pub const Context = struct {
    player: *Entity.Entity,
    entities: *std.ArrayList(*Entity.Entity),
    gamestate: *Gamestate.gameState,
    world: *World.World,
    grid: *[]Level.Tile,
    input: *InputManager.InputManager,
    delta: f32,
    allocator: std.mem.Allocator,
    // ... other fields
};

// ============================================================================
// State Transition Results
// ============================================================================

pub const StateTransition = union(enum) {
    none,
    walking,
    deploying_puppets,
    in_combat,

    pub fn toState(self: StateTransition, allocator: std.mem.Allocator) !?PlayerState {
        return switch (self) {
            .none => null,
            .walking => PlayerState{ .walking = try WalkingState.init(allocator) },
            .deploying_puppets => PlayerState{ .deploying_puppets = try DeployingState.init(allocator) },
            .in_combat => PlayerState{ .in_combat = try CombatState.init(allocator) },
        };
    }
};

// ============================================================================
// Base State Interface (using tagged union)
// ============================================================================

pub const PlayerState = union(enum) {
    walking: WalkingState,
    deploying_puppets: DeployingState,
    in_combat: CombatState,

    pub fn enter(self: *PlayerState, ctx: *Context) !void {
        switch (self.*) {
            inline else => |*state| try state.enter(ctx),
        }
    }

    pub fn exit(self: *PlayerState, ctx: *Context) void {
        switch (self.*) {
            inline else => |*state| state.exit(ctx),
        }
    }

    pub fn update(self: *PlayerState, ctx: *Context) !StateTransition {
        return switch (self.*) {
            inline else => |*state| try state.update(ctx),
        };
    }

    pub fn deinit(self: *PlayerState) void {
        switch (self.*) {
            inline else => |*state| state.deinit(),
        }
    }
};

// ============================================================================
// Walking State
// ============================================================================

pub const WalkingState = struct {
    movement_cooldown: f32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !WalkingState {
        return WalkingState{
            .movement_cooldown = 0,
            .allocator = allocator,
        };
    }

    pub fn enter(self: *WalkingState, ctx: *Context) !void {
        _ = ctx;
        self.movement_cooldown = 0;
        std.debug.print("Entered Walking State\n", .{});
    }

    pub fn exit(self: *WalkingState, ctx: *Context) void {
        _ = ctx;
        std.debug.print("Exited Walking State\n", .{});
    }

    pub fn update(self: *WalkingState, ctx: *Context) !StateTransition {
        self.movement_cooldown += ctx.delta;

        if (self.movement_cooldown < Config.movement_animation_duration) {
            return .none;
        }

        // Check for combat toggle
        if (ctx.input.isActionPressed(.toggle_combat)) {
            return try self.handleCombatToggle(ctx);
        }

        // Handle movement
        if (ctx.input.getMovementInput()) |direction| {
            return try self.handleMovement(ctx, direction);
        }

        return .none;
    }

    fn handleMovement(self: *WalkingState, ctx: *Context, direction: Types.Vector2Int) !StateTransition {
        const new_pos = Types.vector2IntAdd(ctx.player.pos, direction);

        if (!canMove(ctx.grid.*, new_pos, ctx.entities.*)) {
            return .none;
        }

        // Check for staircase
        if (isStaircase(ctx.world, new_pos)) {
            if (getStaircaseDestination(ctx.world, new_pos)) |destination| {
                switchLevel(ctx.world, destination.level);
                ctx.player.move(destination.pos, ctx.grid);
                self.movement_cooldown = 0;
                return .none;
            }
        }

        // Move player
        ctx.player.move(new_pos, ctx.grid);
        self.movement_cooldown = 0;

        // Check if combat should start
        if (checkCombatStart(ctx.player, ctx.entities)) {
            return .deploying_puppets;
        }

        // Enemy turn
        ctx.gamestate.currentTurn = .enemy;
        return .none;
    }

    fn handleCombatToggle(self: *WalkingState, ctx: *Context) !StateTransition {
        _ = self;
        try ctx.player.startCombatSetup(ctx.entities, ctx.grid.*);
        return .deploying_puppets;
    }

    pub fn deinit(self: *WalkingState) void {
        _ = self;
    }
};

// ============================================================================
// Deploying Puppets State
// ============================================================================

pub const DeployingState = struct {
    deployable_cells: ?[8]?Types.Vector2Int,
    highlighted: bool,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !DeployingState {
        return DeployingState{
            .deployable_cells = null,
            .highlighted = false,
            .allocator = allocator,
        };
    }

    pub fn enter(self: *DeployingState, ctx: *Context) !void {
        self.deployable_cells = neighboursAll(ctx.player.pos);
        self.highlighted = false;

        // Setup cursor
        ctx.gamestate.makeCursor(ctx.player.pos);

        std.debug.print("Entered Deploying State\n", .{});
    }

    pub fn exit(self: *DeployingState, ctx: *Context) void {
        ctx.gamestate.reset();
        std.debug.print("Exited Deploying State\n", .{});
    }

    pub fn update(self: *DeployingState, ctx: *Context) !StateTransition {
        // Highlight deployable cells once
        if (!self.highlighted) {
            try self.highlightDeployableCells(ctx);
            self.highlighted = true;
        }

        // Update cursor
        ctx.gamestate.updateCursor();

        // Deploy puppet
        if (ctx.input.isActionPressed(.deploy_puppet)) {
            if (self.canDeployAtCursor(ctx)) {
                try self.deployPuppet(ctx);
            }
        }

        // Check if all puppets deployed
        if (ctx.player.data.player.allPupsDeployed()) {
            return .in_combat;
        }

        // Cancel/end combat
        if (ctx.input.isActionPressed(.toggle_combat)) {
            if (canEndCombat(ctx.player, ctx.entities)) {
                ctx.player.endCombat();
                return .walking;
            }
        }

        return .none;
    }

    fn highlightDeployableCells(self: *DeployingState, ctx: *Context) !void {
        if (self.deployable_cells) |cells| {
            for (cells) |maybe_cell| {
                if (maybe_cell) |cell| {
                    try ctx.gamestate.highlightedTiles.append(.{
                        .pos = cell,
                        .type = .pup_deploy,
                    });
                }
            }
        }
    }

    fn canDeployAtCursor(self: *DeployingState, ctx: *Context) bool {
        const cursor_pos = ctx.gamestate.cursor orelse return false;

        // Can't deploy on player
        if (Types.vector2IntCompare(ctx.player.pos, cursor_pos)) {
            return false;
        }

        // Can't deploy on entity
        if (getEntityByPos(ctx.entities.*, cursor_pos) != null) {
            return false;
        }

        // Check tile properties
        const index = posToIndex(cursor_pos) orelse return false;
        const tile = ctx.grid.*[index];

        if (tile.solid or !tile.walkable) {
            return false;
        }

        // Check if in deployable cells
        if (self.deployable_cells) |cells| {
            for (cells) |maybe_cell| {
                if (maybe_cell) |cell| {
                    if (Types.vector2IntCompare(cursor_pos, cell)) {
                        return true;
                    }
                }
            }
        }

        return false;
    }

    fn deployPuppet(self: *DeployingState, ctx: *Context) !void {
        _ = self;
        const cursor_pos = ctx.gamestate.cursor orelse return;

        for (ctx.player.data.player.puppets.items) |puppet| {
            if (!puppet.data.puppet.deployed) {
                puppet.pos = cursor_pos;
                puppet.data.puppet.deployed = true;
                puppet.visible = true;
                return;
            }
        }
    }

    pub fn deinit(self: *DeployingState) void {
        _ = self;
    }
};

// ============================================================================
// Combat State
// ============================================================================

pub const CombatState = struct {
    selected_entity: ?*Entity.Entity,
    selected_mode: SelectedMode,
    allocator: std.mem.Allocator,

    pub const SelectedMode = enum {
        none,
        moving,
        attacking,
    };

    pub fn init(allocator: std.mem.Allocator) !CombatState {
        return CombatState{
            .selected_entity = null,
            .selected_mode = .none,
            .allocator = allocator,
        };
    }

    pub fn enter(self: *CombatState, ctx: *Context) !void {
        _ = self;
        ctx.gamestate.currentTurn = .player;
        std.debug.print("Entered Combat State\n", .{});
    }

    pub fn exit(self: *CombatState, ctx: *Context) void {
        _ = self;
        ctx.gamestate.reset();
        std.debug.print("Exited Combat State\n", .{});
    }

    pub fn update(self: *CombatState, ctx: *Context) !StateTransition {
        switch (ctx.gamestate.currentTurn) {
            .player => return try self.updatePlayerTurn(ctx),
            .enemy => return try self.updateEnemyTurn(ctx),
        }
    }

    fn updatePlayerTurn(self: *CombatState, ctx: *Context) !StateTransition {
        // Force end combat (for testing - remove later)
        if (ctx.input.isActionPressed(.toggle_combat)) {
            ctx.player.endCombat();
            return .walking;
        }

        // Handle entity selection
        try self.handleEntitySelection(ctx);

        // Handle selected entity actions
        if (self.selected_entity) |entity| {
            try self.handleSelectedEntityActions(ctx, entity);

            // Check if turn is complete
            if (entity.hasMoved and entity.hasAttacked) {
                entity.turnTaken = true;
            }
        }

        // Check if all entities have moved
        if (ctx.player.turnTaken or ctx.player.allPupsTurnTaken()) {
            ctx.gamestate.currentTurn = .enemy;
            ctx.player.resetTurnTakens();
        }

        // Check if combat is over
        if (ctx.player.data.player.inCombatWith.items.len == 0) {
            ctx.player.endCombat();
            return .walking;
        }

        return .none;
    }

    fn updateEnemyTurn(self: *CombatState, ctx: *Context) !StateTransition {
        _ = self;
        // TODO: Implement enemy AI
        ctx.gamestate.currentTurn = .player;
        return .none;
    }

    fn handleEntitySelection(self: *CombatState, ctx: *Context) !void {
        var selected_now = false;

        if (ctx.input.isActionPressed(.select_entity_1)) {
            self.selected_entity = ctx.player;
            selected_now = true;
        } else if (ctx.input.isActionPressed(.select_entity_2)) {
            if (ctx.player.data.player.puppets.items.len > 0) {
                self.selected_entity = ctx.player.data.player.puppets.items[0];
                selected_now = true;
            }
        } else if (ctx.input.isActionPressed(.select_entity_3)) {
            if (ctx.player.data.player.puppets.items.len > 1) {
                self.selected_entity = ctx.player.data.player.puppets.items[1];
                selected_now = true;
            }
        } else if (ctx.input.isActionPressed(.select_entity_4)) {
            if (ctx.player.data.player.puppets.items.len > 2) {
                self.selected_entity = ctx.player.data.player.puppets.items[2];
                selected_now = true;
            }
        } else if (ctx.input.isActionPressed(.select_entity_5)) {
            if (ctx.player.data.player.puppets.items.len > 3) {
                self.selected_entity = ctx.player.data.player.puppets.items[3];
                selected_now = true;
            }
        }

        if (selected_now) {
            if (self.selected_entity) |entity| {
                ctx.cameraManager.targetEntity = entity;
                ctx.gamestate.removeCursor();
                self.selected_mode = .none;
                ctx.gamestate.resetMovementHighlight();
            }
        }

        // Highlight selected entity
        if (self.selected_entity) |entity| {
            highlightEntity(ctx.gamestate, entity.pos);
        }
    }

    fn handleSelectedEntityActions(self: *CombatState, ctx: *Context, entity: *Entity.Entity) !void {
        switch (self.selected_mode) {
            .none => {
                // Enter move mode
                if (!entity.hasMoved and ctx.input.isActionPressed(.select_move_mode)) {
                    self.selected_mode = .moving;
                    ctx.gamestate.makeCursor(entity.pos);
                }
                // Enter attack mode
                else if (ctx.input.isActionPressed(.select_attack_mode)) {
                    self.selected_mode = .attacking;
                    ctx.gamestate.makeCursor(entity.pos);
                }
            },
            .moving => {
                ctx.gamestate.updateCursor();
                try self.handleMoving(ctx, entity);

                // Cancel move mode
                if (ctx.input.isActionPressed(.select_move_mode)) {
                    self.selected_mode = .none;
                    ctx.gamestate.removeCursor();
                    ctx.gamestate.resetMovementHighlight();
                }

                // Skip movement
                if (ctx.input.isActionPressed(.skip_action)) {
                    entity.hasMoved = true;
                    self.selected_mode = .none;
                    ctx.gamestate.resetMovementHighlight();
                    ctx.gamestate.removeCursor();
                }
            },
            .attacking => {
                ctx.gamestate.updateCursor();
                try self.handleAttacking(ctx, entity);

                // Cancel attack mode
                if (ctx.input.isActionPressed(.select_attack_mode)) {
                    self.selected_mode = .none;
                    ctx.gamestate.removeCursor();
                    ctx.gamestate.resetAttackHighlight();
                }

                // Skip attack
                if (ctx.input.isActionPressed(.skip_action)) {
                    entity.hasAttacked = true;
                    self.selected_mode = .none;
                    ctx.gamestate.resetAttackHighlight();
                    ctx.gamestate.removeCursor();
                }
            },
        }
    }

    fn handleMoving(self: *CombatState, ctx: *Context, entity: *Entity.Entity) !void {
        _ = self;
        try ctx.gamestate.highlightMovement(entity);

        if (ctx.input.isActionPressed(.confirm)) {
            if (ctx.gamestate.cursor) |cursor_pos| {
                if (ctx.gamestate.isinMovable(cursor_pos)) {
                    entity.path = try ctx.pathfinder.findPath(ctx.grid.*, entity.pos, cursor_pos, ctx.entities.*);
                    entity.hasMoved = true;
                    self.selected_mode = .none;
                    ctx.gamestate.resetMovementHighlight();
                    ctx.gamestate.removeCursor();
                }
            }
        }
    }

    fn handleAttacking(self: *CombatState, ctx: *Context, entity: *Entity.Entity) !void {
        _ = self;
        try ctx.gamestate.highlightAttack(entity);

        if (ctx.input.isActionPressed(.confirm)) {
            if (ctx.gamestate.cursor) |cursor_pos| {
                if (ctx.gamestate.isinAttackable(cursor_pos)) {
                    // Spawn visual effects
                    try ctx.shaderManager.spawnExplosion(entity.pos);

                    // Perform attack
                    const target = getEntityByPos(ctx.entities.*, cursor_pos);
                    if (target) |attacked_entity| {
                        try performAttack(ctx, entity, attacked_entity);
                    }

                    entity.hasAttacked = true;
                    self.selected_mode = .none;
                    ctx.gamestate.resetAttackHighlight();
                    ctx.gamestate.removeCursor();
                }
            }
        }
    }

    pub fn deinit(self: *CombatState) void {
        _ = self;
    }
};

// ============================================================================
// State Manager
// ============================================================================

pub const StateManager = struct {
    current_state: PlayerState,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, initial_state: PlayerState) StateManager {
        return StateManager{
            .current_state = initial_state,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *StateManager) void {
        self.current_state.deinit();
    }

    pub fn update(self: *StateManager, ctx: *Context) !void {
        const transition = try self.current_state.update(ctx);

        if (transition != .none) {
            try self.changeState(ctx, transition);
        }
    }

    fn changeState(self: *StateManager, ctx: *Context, transition: StateTransition) !void {
        // Exit current state
        self.current_state.exit(ctx);
        self.current_state.deinit();

        // Create and enter new state
        if (try transition.toState(self.allocator)) |new_state| {
            self.current_state = new_state;
            try self.current_state.enter(ctx);
        }
    }
};

// ============================================================================
// Helper Functions (these should be in a separate utilities module)
// ============================================================================

fn canMove(grid: []Level.Tile, pos: Types.Vector2Int, entities: std.ArrayList(*Entity.Entity)) bool {
    const index = posToIndex(pos) orelse return false;
    if (index >= grid.len) return false;
    if (grid[index].solid) return false;

    return getEntityByPos(entities, pos) == null;
}

fn getEntityByPos(entities: std.ArrayList(*Entity.Entity), pos: Types.Vector2Int) ?*Entity.Entity {
    for (entities.items) |entity| {
        if (Types.vector2IntCompare(entity.pos, pos)) {
            return entity;
        }
    }
    return null;
}

fn posToIndex(pos: Types.Vector2Int) ?usize {
    if (pos.x < 0 or pos.y < 0) return null;
    const result: usize = @intCast(pos.y * Config.level_width + pos.x);
    if (result >= Config.level_width * Config.level_height) return null;
    return result;
}

fn neighboursAll(pos: Types.Vector2Int) [8]?Types.Vector2Int {
    var result: [8]?Types.Vector2Int = undefined;
    var count: usize = 0;
    const sides = [_]i32{ -1, 0, 1 };

    for (sides) |y_side| {
        for (sides) |x_side| {
            if (x_side == 0 and y_side == 0) continue;

            const new_pos = Types.Vector2Int{
                .x = pos.x + x_side,
                .y = pos.y + y_side,
            };

            if (new_pos.x >= 0 and new_pos.y >= 0 and
                new_pos.x < Config.level_width and new_pos.y < Config.level_height)
            {
                result[count] = new_pos;
            } else {
                result[count] = null;
            }
            count += 1;
        }
    }
    return result;
}

fn isStaircase(world: *World.World, pos: Types.Vector2Int) bool {
    for (world.levelLinks.items) |link| {
        if (link.from.level == world.currentLevel.id and
            Types.vector2IntCompare(link.from.pos, pos))
        {
            return true;
        }
    }
    return false;
}

fn getStaircaseDestination(world: *World.World, pos: Types.Vector2Int) ?Level.Location {
    for (world.levelLinks.items) |link| {
        if (link.from.level == world.currentLevel.id and
            Types.vector2IntCompare(link.from.pos, pos))
        {
            return link.to;
        }
    }
    return null;
}

fn switchLevel(world: *World.World, level_id: u32) void {
    for (world.levels.items) |level| {
        if (level.id == level_id) {
            world.currentLevel = level;
            return;
        }
    }
}

fn checkCombatStart(player: *Entity.Entity, entities: *std.ArrayList(*Entity.Entity)) bool {
    const combat_trigger_distance = 3;
    for (entities.items) |entity| {
        if (entity.data == .enemy) {
            const distance = Types.vector2Distance(player.pos, entity.pos);
            if (distance < combat_trigger_distance) {
                return true;
            }
        }
    }
    return false;
}

fn canEndCombat(player: *Entity.Entity, entities: *std.ArrayList(*Entity.Entity)) bool {
    _ = player;
    _ = entities;
    // TODO: Implement proper combat end conditions
    return true;
}

fn highlightEntity(gamestate: *Gamestate.gameState, pos: Types.Vector2Int) void {
    gamestate.highlightedEntity = Gamestate.highlight{
        .pos = pos,
        .type = .circle,
    };
}

fn performAttack(ctx: *Context, attacker: *Entity.Entity, target: *Entity.Entity) !void {
    _ = ctx;
    _ = attacker;
    _ = target;
    // TODO: Implement actual attack logic with damage calculation
}

// You'll need to import World somewhere or define it
const World = @import("world.zig");



//how to use:

const std = @import("std");
const PlayerStates = @import("playerStates.zig");
const InputManager = @import("inputManager.zig");
const Entity = @import("entity.zig");

// ============================================================================
// In your Player entity definition
// ============================================================================

pub const Player = struct {
    entity: Entity.Entity,
    state_manager: PlayerStates.StateManager,
    puppets: std.ArrayList(*Entity.Entity),
    in_combat_with: std.ArrayList(*Entity.Entity),
    
    pub fn init(allocator: std.mem.Allocator, pos: Types.Vector2Int) !Player {
        // Create initial walking state
        const initial_state = PlayerStates.PlayerState{
            .walking = try PlayerStates.WalkingState.init(allocator),
        };
        
        var player = Player{
            .entity = try Entity.Entity.init(allocator, pos, .player),
            .state_manager = PlayerStates.StateManager.init(allocator, initial_state),
            .puppets = std.ArrayList(*Entity.Entity).init(allocator),
            .in_combat_with = std.ArrayList(*Entity.Entity).init(allocator),
        };
        
        // Initialize the state
        var ctx = ... // your context
        try player.state_manager.current_state.enter(&ctx);
        
        return player;
    }
    
    pub fn deinit(self: *Player) void {
        self.state_manager.deinit();
        self.puppets.deinit();
        self.in_combat_with.deinit();
        self.entity.deinit();
    }
    
    pub fn update(self: *Player, ctx: *PlayerStates.Context) !void {
        try self.state_manager.update(ctx);
        
        // Update entity movement/animation
        try self.entity.update(ctx);
        
        // Update puppets
        for (self.puppets.items) |puppet| {
            try puppet.update(ctx);
        }
    }
    
    pub fn getCurrentStateName(self: *Player) []const u8 {
        return switch (self.state_manager.current_state) {
            .walking => "Walking",
            .deploying_puppets => "Deploying Puppets",
            .in_combat => "In Combat",
        };
    }
    
    pub fn isInState(self: *Player, comptime state_tag: std.meta.Tag(PlayerStates.PlayerState)) bool {
        return self.state_manager.current_state == state_tag;
    }
};

// ============================================================================
// In your main game loop
// ============================================================================

pub const Game = struct {
    allocator: std.mem.Allocator,
    player: Player,
    entities: std.ArrayList(*Entity.Entity),
    world: World.World,
    gamestate: Gamestate.gameState,
    input: InputManager.InputManager,
    camera: CameraManager,
    // ... other fields
    
    pub fn init(allocator: std.mem.Allocator) !Game {
        var game = Game{
            .allocator = allocator,
            .player = try Player.init(allocator, Types.Vector2Int{ .x = 10, .y = 10 }),
            .entities = std.ArrayList(*Entity.Entity).init(allocator),
            .world = try World.World.init(allocator),
            .gamestate = try Gamestate.gameState.init(allocator),
            .input = try InputManager.InputManager.init(allocator),
            .camera = try CameraManager.init(),
        };
        
        return game;
    }
    
    pub fn update(self: *Game, delta: f32) !void {
        // Update input system first
        self.input.update(self.camera.camera);
        
        // Build context for state updates
        var ctx = PlayerStates.Context{
            .player = &self.player.entity,
            .entities = &self.entities,
            .gamestate = &self.gamestate,
            .world = &self.world,
            .grid = &self.world.currentLevel.grid,
            .input = &self.input,
            .delta = delta,
            .allocator = self.allocator,
            .cameraManager = &self.camera,
            .pathfinder = &self.pathfinder,
            .shaderManager = &self.shaderManager,
        };
        
        // Update player (which updates state machine)
        try self.player.update(&ctx);
        
        // Update other entities
        try self.updateEnemies(&ctx);
        
        // Update world systems
        try self.world.update(delta);
        try self.gamestate.update(delta);
    }
    
    pub fn render(self: *Game) void {
        // Render world
        self.world.render();
        
        // Render entities
        for (self.entities.items) |entity| {
            entity.render();
        }
        
        // Render player
        self.player.entity.render();
        
        // Render UI with current state
        self.renderUI();
    }
    
    fn renderUI(self: *Game) void {
        const state_name = self.player.getCurrentStateName();
        c.DrawText(
            state_name.ptr,
            10, 10, 20, c.WHITE
        );
        
        // Different UI based on state
        switch (self.player.state_manager.current_state) {
            .walking => {
                c.DrawText("WASD to move, F to enter combat", 10, 40, 16, c.GRAY);
            },
            .deploying_puppets => |*state| {
                _ = state;
                c.DrawText("D to deploy puppet, F to cancel", 10, 40, 16, c.GRAY);
            },
            .in_combat => |*state| {
                _ = state;
                c.DrawText("1-5: Select unit, Q: Move, W: Attack", 10, 40, 16, c.GRAY);
                
                if (state.selected_entity) |entity| {
                    const text = std.fmt.allocPrintZ(
                        self.allocator,
                        "Selected: {
