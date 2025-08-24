            if (Config.mouse_mode) {
                //HOVER:
                const hover_win = c.GetMousePosition();
                const hover_texture = Utils.screenToRenderTextureCoords(hover_win);
                //TODO: no idea if I still need screenToRenderTextureCoords, i dont use the render texture
                //anymore
                const hover_world = c.GetScreenToWorld2D(hover_texture, cameraManager.camera.*);
                const hover_pos = Types.vector2ConvertWithPixels(hover_world);
                highlightTile(grid, hover_pos, c.GREEN);

                if (c.IsMouseButtonPressed(c.MOUSE_BUTTON_RIGHT)) {
                    const destination = c.GetMousePosition();
                    const renderDestination = Utils.screenToRenderTextureCoords(destination);
                    const world_pos = c.GetScreenToWorld2D(renderDestination, cameraManager.camera.*);

                    const player_dest = Utils.pixelToTile(world_pos);
                    //player.dest = player_dest;
                    //TODO: check for wron player_dest
                    player.path = pathfinder.findPath(grid, player.pos, player_dest) catch null;
                }

                if (player.path) |path| {
                    if (path.currIndex < path.nodes.items.len) {
                        //TODO: add player movement speed
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
            } else {}
