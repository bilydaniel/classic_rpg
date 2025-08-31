// Define a context struct to hold all the dependencies
const PlayerUpdateContext = struct {
    gamestate: *Gamestate.gameState,
    player: *Entity.Entity,
    delta: f32,
    world: *World.World,
    cameraManager: *CameraManager.CamManager,
    pathfinder: *Pathfinder.Pathfinder,
    entities: *std.ArrayList(*Entity.Entity),
};

// Input handling for cursor movement
fn handleCursorMovement(gamestate: *Gamestate.gameState) void {
    if (gamestate.cursor == null) return;

    if (c.IsKeyPressed(c.KEY_H)) {
        if (gamestate.cursor.?.x > 0) {
            gamestate.cursor.?.x -= 1;
        }
    } else if (c.IsKeyPressed(c.KEY_L)) {
        if (gamestate.cursor.?.x < Config.level_width) {
            gamestate.cursor.?.x += 1;
        }
    } else if (c.IsKeyPressed(c.KEY_J)) {
        if (gamestate.cursor.?.y < Config.level_height) {
            gamestate.cursor.?.y += 1;
        }
    } else if (c.IsKeyPressed(c.KEY_K)) {
        if (gamestate.cursor.?.y > 0) {
            gamestate.cursor.?.y -= 1;
        }
    }
}

// Mouse input handling for walking state
fn handleMouseInput(ctx: *const PlayerUpdateContext) !void {
    const grid = ctx.world.currentLevel.grid;

    // Handle hover highlighting
    const hover_win = c.GetMousePosition();
    const hover_texture = Utils.screenToRenderTextureCoords(hover_win);
    const hover_world = c.GetScreenToWorld2D(hover_texture, ctx.cameraManager.camera.*);
    const hover_pos = Types.vector2ConvertWithPixels(hover_world);
    highlightTile(grid, hover_pos, c.GREEN);

    // Handle right click for pathfinding
    if (c.IsMouseButtonPressed(c.MOUSE_BUTTON_RIGHT)) {
        const destination = c.GetMousePosition();
        const renderDestination = Utils.screenToRenderTextureCoords(destination);
        const world_pos = c.GetScreenToWorld2D(renderDestination, ctx.cameraManager.camera.*);
        const player_dest = Utils.pixelToTile(world_pos);

        ctx.player.path = ctx.pathfinder.findPath(grid, ctx.player.pos, player_dest) catch null;
    }
}

// Handle path following
fn handlePathFollowing(player: *Entity.Entity, delta: f32) void {
    if (player.path) |path| {
        if (path.currIndex < path.nodes.items.len) {
            if (player.movementCooldown > Config.turn_speed) {
                player.pos = path.nodes.items[path.currIndex];
                player.path.?.currIndex += 1;
                player.movementCooldown = 0;
            }
        } else {
            player.path.?.deinit();
            player.path = null;
        }
        player.movementCooldown += delta;
    }
}

// Keyboard movement for walking state
fn handleKeyboardMovement(ctx: *const PlayerUpdateContext) !void {
    if (ctx.player.movementCooldown <= 0.1) return;

    var new_pos = ctx.player.pos;
    var moved = false;

    if (c.IsKeyDown(c.KEY_H)) {
        new_pos.x -= 1;
        moved = true;
    } else if (c.IsKeyDown(c.KEY_L)) {
        new_pos.x += 1;
        moved = true;
    } else if (c.IsKeyDown(c.KEY_J)) {
        new_pos.y += 1;
        moved = true;
    } else if (c.IsKeyDown(c.KEY_K)) {
        new_pos.y -= 1;
        moved = true;
    }

    // Combat initiation
    if (c.IsKeyPressed(c.KEY_F)) {
        try ctx.player.startCombatSetup(ctx.entities, ctx.world.currentLevel.grid);
    }

    // Handle movement validation and effects
    if (moved and canMove(ctx.world.currentLevel.grid, new_pos)) {
        if (isStaircase(ctx.world, new_pos)) {
            const levelLocation = getStaircaseDestination(ctx.world, new_pos);
            if (levelLocation) |lvllocation| {
                switchLevel(ctx.world, lvllocation.level);
                new_pos = lvllocation.pos;
            }
        }

        ctx.player.pos = new_pos;
        ctx.player.movementCooldown = 0;
        calculateFOV(&ctx.world.currentLevel.grid, new_pos, 8);

        // Check for combat
        const combat = checkCombatStart(ctx.player, ctx.entities);
        if (combat and ctx.player.data.player.state != .in_combat) {
            try ctx.player.startCombatSetup(ctx.entities, ctx.world.currentLevel.grid);
        }
    }

    ctx.player.movementCooldown += ctx.delta;
}

// Walking state handler
fn handleWalkingState(ctx: *const PlayerUpdateContext) !void {
    if (Config.mouse_mode) {
        try handleMouseInput(ctx);
        handlePathFollowing(ctx.player, ctx.delta);
    } else {
        try handleKeyboardMovement(ctx);
    }
}

// Initialize deployment phase
fn initializeDeployment(ctx: *const PlayerUpdateContext) !void {
    if (ctx.gamestate.deployableCells == null) {
        const neighbours = neighboursAll(ctx.player.pos);
        ctx.gamestate.deployableCells = neighbours;
    }

    if (ctx.gamestate.deployableCells) |cells| {
        if (!ctx.gamestate.deployHighlighted) {
            for (cells) |value| {
                if (value) |val| {
                    try highlightTile2(ctx.gamestate, val);
                }
            }
            ctx.gamestate.deployHighlighted = true;
            if (ctx.gamestate.cursor == null) {
                ctx.gamestate.cursor = ctx.player.pos;
            }
        }
    }
}

// Handle deployment input
fn handleDeploymentInput(ctx: *const PlayerUpdateContext) !void {
    if (ctx.gamestate.cursor) |cursor| {
        const grid = ctx.world.currentLevel.grid;
        highlightTile(grid, cursor, c.YELLOW);

        handleCursorMovement(ctx.gamestate);

        // Deploy puppet
        if (c.IsKeyPressed(c.KEY_D)) {
            if (canDeploy(ctx.player, ctx.gamestate, grid, ctx.entities)) {
                try deployPuppet(ctx.player, ctx.gamestate, ctx.entities);
            }
        }
    }
}

// Deployment state handler
fn handleDeployingPuppetsState(ctx: *const PlayerUpdateContext) !void {
    try initializeDeployment(ctx);
    try handleDeploymentInput(ctx);

    // Check for state transitions
    if (ctx.player.data.player.allPupsDeployed()) {
        ctx.gamestate.reset();
        ctx.player.data.player.state = .in_combat;
    }

    if (c.IsKeyPressed(c.KEY_F)) {
        if (canEndCombat(ctx.player, ctx.entities)) {
            ctx.gamestate.reset();
            ctx.player.endCombat(ctx.entities);
        }
    }
}

// Entity selection in combat
fn handleEntitySelection(ctx: *const PlayerUpdateContext) void {
    if (c.IsKeyPressed(c.KEY_ONE)) {
        ctx.gamestate.selectedEntity = ctx.player;
    } else if (c.IsKeyPressed(c.KEY_TWO) and ctx.player.data.player.puppets.items.len > 0) {
        ctx.gamestate.selectedEntity = ctx.player.data.player.puppets.items[0];
        ctx.cameraManager.targetEntity = ctx.player.data.player.puppets.items[0];
    } else if (c.IsKeyPressed(c.KEY_THREE) and ctx.player.data.player.puppets.items.len > 1) {
        ctx.gamestate.selectedEntity = ctx.player.data.player.puppets.items[1];
        ctx.cameraManager.targetEntity = ctx.player.data.player.puppets.items[1];
    } else if (c.IsKeyPressed(c.KEY_FOUR) and ctx.player.data.player.puppets.items.len > 2) {
        ctx.gamestate.selectedEntity = ctx.player.data.player.puppets.items[2];
        ctx.cameraManager.targetEntity = ctx.player.data.player.puppets.items[2];
    } else if (c.IsKeyPressed(c.KEY_FIVE) and ctx.player.data.player.puppets.items.len > 3) {
        ctx.gamestate.selectedEntity = ctx.player.data.player.puppets.items[3];
        ctx.cameraManager.targetEntity = ctx.player.data.player.puppets.items[3];
    }
}

// Handle movement mode in combat
fn handleMovementMode(ctx: *const PlayerUpdateContext, entity: *Entity.Entity) !void {
    // Initialize movable tiles if needed
    if (ctx.gamestate.movableTiles.items.len == 0) {
        try neighboursDistance(entity.pos, 2, &ctx.gamestate.movableTiles);
    }

    // Highlight movable tiles
    if (ctx.gamestate.movableTiles.items.len > 0 and !ctx.gamestate.movementHighlighted) {
        for (ctx.gamestate.movableTiles.items) |item| {
            try highlightTile2(ctx.gamestate, item);
        }
        ctx.gamestate.cursor = ctx.player.pos;
        ctx.gamestate.movementHighlighted = true;
        std.debug.print("highlighted {}\n", .{ctx.gamestate.highlightedTiles.items.len});
    }

    // Handle movement execution
    if (c.IsKeyPressed(c.KEY_A)) {
        if (ctx.gamestate.cursor) |cur| {
            ctx.player.path = try ctx.pathfinder.findPath(ctx.world.currentLevel.grid, ctx.player.pos, cur);
        }
    }

    ctx.player.makeCombatStep(ctx.delta, ctx.entities);
}

// Handle selected entity actions
fn handleSelectedEntity(ctx: *const PlayerUpdateContext, entity: *Entity.Entity) !void {
    highlightEntity(ctx.gamestate, entity.pos);

    // Mode selection
    if (c.IsKeyPressed(c.KEY_Q)) {
        ctx.gamestate.selectedEntityMode = .moving;
    } else if (c.IsKeyPressed(c.KEY_W)) {
        ctx.gamestate.selectedEntityMode = .attacking;
    }

    // Handle different modes
    switch (ctx.gamestate.selectedEntityMode) {
        .moving => try handleMovementMode(ctx, entity),
        .attacking => {
            std.debug.print("attacking...\n", .{});
            // TODO: Implement attacking logic
        },
        else => {},
    }
}

// Player turn handler
fn handlePlayerTurn(ctx: *const PlayerUpdateContext) !void {
    handleEntitySelection(ctx);

    if (ctx.gamestate.selectedEntity) |entity| {
        try handleSelectedEntity(ctx, entity);
    }

    handleCursorMovement(ctx.gamestate);

    // Force end combat (for testing)
    if (c.IsKeyPressed(c.KEY_F)) {
        ctx.player.endCombat(ctx.entities);
        ctx.player.data.player.state = .walking;
        std.debug.print("F\n", .{});
        return;
    }

    // Check for turn/combat end conditions
    if (ctx.player.data.player.inCombatWith.items.len == 0) {
        ctx.gamestate.currentTurn = .none;
        ctx.player.data.player.state = .walking;
    } else if (ctx.player.turnTaken or ctx.player.allPupsTurnTaken()) {
        ctx.gamestate.currentTurn = .enemy;
        std.debug.print("turn_done\n", .{});
    }
}

// Combat state handler
fn handleInCombatState(ctx: *const PlayerUpdateContext) !void {
    switch (ctx.gamestate.currentTurn) {
        .none => {
            ctx.gamestate.currentTurn = .player;
        },
        .player => {
            try handlePlayerTurn(ctx);
        },
        .enemy => {
            // TODO: Implement enemy AI
        },
    }
}

// Main update function - much cleaner now
pub fn updatePlayer(gamestate: *Gamestate.gameState, player: *Entity.Entity, delta: f32, world: *World.World, cameraManager: *CameraManager.CamManager, pathfinder: *Pathfinder.Pathfinder, entities: *std.ArrayList(*Entity.Entity)) !void {
    const ctx = PlayerUpdateContext{
        .gamestate = gamestate,
        .player = player,
        .delta = delta,
        .world = world,
        .cameraManager = cameraManager,
        .pathfinder = pathfinder,
        .entities = entities,
    };

    switch (player.data.player.state) {
        .walking => try handleWalkingState(&ctx),
        .deploying_puppets => try handleDeployingPuppetsState(&ctx),
        .in_combat => try handleInCombatState(&ctx),
    }
}
