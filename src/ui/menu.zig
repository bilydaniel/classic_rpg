const Button = @import("button.zig");
const AssetList = @import("../editor/asset_list.zig");
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

    pub fn initAssetMenu(allocator: std.mem.Allocator, assetList: AssetList.AssetList) !Menu {
        var buttons: std.ArrayList(*Button.Button) = std.ArrayList(*Button.Button).init(allocator);
        var pos: Types.Vector2Int = Types.Vector2Int{ .x = 0, .y = 0 };
        for (assetList.list.items) |asset| {
            var button = try allocator.create(Button.Button);
            const button_label = std.fs.path.basename(asset.path);
            button.initValues(pos, button_label);
            try buttons.append(button);
            std.debug.print("asset: {any}", .{asset});
            //TODO: add asset into the button
            pos.y += 16;
        }
        return Menu{
            .buttons = buttons,
            .allocator = allocator,
            .scroll = 0,
        };
    }

    pub fn Draw(this: @This()) void {
        c.DrawRectangle(0, 0, Config.game_width, Config.game_height, c.GRAY);
        for (this.buttons.items) |button| {
            button.Draw(this.scroll);
        }
    }

    pub fn Update(this: *Menu) void {
        if (c.IsMouseButtonPressed(c.MOUSE_BUTTON_LEFT)) {
            for (this.buttons.items) |button| {
                button.Update();
            }
        }
        this.scroll -= c.GetMouseWheelMove() * 20.0;
    }
};
