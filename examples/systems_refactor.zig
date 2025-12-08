pub fn handlePlayerDeploying(ctx: *Game.Context) !void {
    // Handle puppet selection from menu
    if (ctx.gamestate.selectedPupId == null) {
        try handlePuppetSelection(ctx);
        return;
    }

    // Handle deployment with selected puppet
    try handlePuppetDeployment(ctx);

    // Check for state transitions
    try checkDeploymentTransitions(ctx);
}

fn handlePuppetSelection(ctx: *Game.Context) !void {
    ctx.gamestate.showPupDeployMenu = true;

    if (ctx.uiCommand.menuSelect) |menu_item| {
        switch (menu_item) {
            .puppet_id => |pid| {
                ctx.gamestate.selectedPupId = pid;
            },
            .action => {
                std.debug.print("Unexpected menu_item type: .action (expected .puppet_id)\n", .{});
            },
        }
    }
}

fn handlePuppetDeployment(ctx: *Game.Context) !void {
    const selected_pup = ctx.gamestate.selectedPupId orelse return;

    ctx.gamestate.showPupDeployMenu = false;
    ctx.gamestate.makeUpdateCursor(ctx.player.pos);

    // Initialize deployable cells if needed
    if (ctx.gamestate.deployableCells == null) {
        ctx.gamestate.deployableCells = neighboursAll(ctx.player.pos);
    }

    // Highlight deployable cells (one-time operation)
    if (!ctx.gamestate.deployHighlighted) {
        try highlightDeployableCells(ctx.gamestate);
    }

    // Handle deployment confirmation
    if (ctx.uiCommand.confirm) {
        if (canDeploy(ctx.player, ctx.gamestate, ctx.grid.*, ctx.entities)) {
            try deployPuppet(ctx, selected_pup);
        }
    }
}

fn highlightDeployableCells(gamestate: *GameState) !void {
    const cells = gamestate.deployableCells orelse return;

    for (cells) |cell_opt| {
        if (cell_opt) |cell| {
            try highlightTile(gamestate, cell);
        }
    }
    gamestate.deployHighlighted = true;
}

fn checkDeploymentTransitions(ctx: *Game.Context) !void {
    // Transition to combat when all puppets deployed
    if (ctx.player.data.player.allPupsDeployed()) {
        try transitionToCombat(ctx);
        return;
    }

    // Manual combat transition (DEBUG: F key)
    if (c.IsKeyPressed(c.KEY_F)) {
        if (canEndCombat(ctx.player, ctx.entities)) {
            try transitionToCombat(ctx);
        }
    }
}

fn transitionToCombat(ctx: *Game.Context) !void {
    ctx.gamestate.reset();
    ctx.player.data.player.state = .in_combat;
    ctx.uiManager.hideDeployMenu();
}
