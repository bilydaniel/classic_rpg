const Button = @import("button.zig");
const AssetList = @import("../editor/asset_list.zig");
const std = @import("std");

pub const Menu = struct {
    buttons: []Button.Button,

    pub fn initAssetMenu(assetList: AssetList.AssetList) Menu {
        const buttons: []Button.Button = undefined;
        std.debug.print("{d}\n", .{assetList.list.items.len});
        return Menu{
            .buttons = buttons,
        };
    }
};
