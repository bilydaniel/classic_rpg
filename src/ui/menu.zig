const Button = @import("button.zig");
const AssetList = @import("../editor/asset_list.zig");
const Assets = @import("../game/assets.zig");
const Tileset = @import("../game/tileset.zig");
const std = @import("std");
const Config = @import("../common/config.zig");
const Types = @import("../common/types.zig");
const c = @cImport({
    @cInclude("raylib.h");
});

pub const Menu = struct {
    buttons: std.ArrayList(*Button.Button),
    allocator: std.mem.Allocator,
    scroll: f32,
    isScrollable: bool,
    isOpen: bool,
    selectedData: ?*anyopaque = null,

    //TODO: each menu has its own init based on the parameters
    pub fn initAssetMenu(allocator: std.mem.Allocator, assets: Assets.Assets) !Menu {
        var buttons: std.ArrayList(*Button.Button) = std.ArrayList(*Button.Button).init(allocator);
        var pos: Types.Vector2Int = Types.Vector2Int{ .x = 0, .y = 0 };
        for (assets.list.items) |asset| {
            var button = try allocator.create(Button.Button);
            const button_label = std.fs.path.basename(asset.path);
            button.initValues(pos, button_label, asset);
            try buttons.append(button);
            //TODO: add asset into the button
            pos.x += 128;
            if (pos.x > 575) {
                pos.y += 64;
                pos.x = 0;
            }
        }
        return Menu{
            .buttons = buttons,
            .allocator = allocator,
            .scroll = 0,
            .isScrollable = true,
            .isOpen = false,
        };
    }

    pub fn initTilesetMenu(allocator: std.mem.Allocator, tileset: Tileset.Tileset) !Menu {
        var buttons: std.ArrayList(*Button.Button) = std.ArrayList(*Button.Button).init(allocator);
        var pos: Types.Vector2Int = Types.Vector2Int{ .x = 0, .y = 0 };
        for (tileset.sourceRects.items) |rect| {
            var button = try allocator.create(Button.Button);
            const button_label = "TODO";
            button.initValues(pos, button_label, rect);
            try buttons.append(button);
            pos.x += 128;
            if (pos.x > 575) {
                pos.y += 64;
                pos.x = 0;
            }
        }
        return Menu{
            .buttons = buttons,
            .allocator = allocator,
            .scroll = 0,
            .isScrollable = true,
            .isOpen = false,
        };
    }

    pub fn Draw(this: @This()) !void {
        if (this.isOpen) {
            c.DrawRectangle(0, 0, Config.game_width, Config.game_height, c.GRAY);
            for (this.buttons.items) |button| {
                try button.Draw();
            }
        }
    }

    pub fn Update(this: *Menu) ?*anyopaque {
        if (this.isOpen) {
            if (this.isScrollable) {
                this.scroll -= c.GetMouseWheelMove() * 20.0;
            }
            for (this.buttons.items) |button| {
                this.selectedData = button.Update(this.scroll);
                if (this.selectedData) |data| {
                    std.debug.print("SELECTED_DATA: {}", .{data});
                    return this.selectedData;
                }
            }
        }
        return null;
    }
    pub fn assetMenuButtonCallback(this: *Menu, data: ?*anyopaque) void {
        this.selectedData = data;
    }
};
