const Button = @import("button.zig");
const AssetList = @import("../editor/asset_list.zig");
const Assets = @import("../game/assets.zig");
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
            button.initValues(pos, button_label, Menu.assetMenuButtonCallback, asset);
            try buttons.append(button);
            std.debug.print("asset: {any}", .{asset});
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

    pub fn Draw(this: @This()) !void {
        if (this.isOpen) {
            c.DrawRectangle(0, 0, Config.game_width, Config.game_height, c.GRAY);
            for (this.buttons.items) |button| {
                try button.Draw();
            }
        }
    }

    pub fn Update(this: *Menu) void {
        if (this.isOpen) {
            if (this.isScrollable) {
                this.scroll -= c.GetMouseWheelMove() * 20.0;
            }
            for (this.buttons.items) |button| {
                //TODO: check if a button was pressed(value in the button) if it was, return its assets
                button.Update(this.scroll);
                //TODO: button will return anyopaque, if button returns something => return it from this menu, work with the data after they are returned from the menu, depending on what kind of menu it is => do something(asset menu returns assets etc)
            }
        }
    }
    pub fn assetMenuButtonCallback(this: *Menu, data: ?*anyopaque) void {
        this.selectedData = data;
    }
};
