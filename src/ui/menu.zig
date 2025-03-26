const Button = @import("button.zig");
const AssetTree = @import("../editor/asset_tree.zig");
const std = @import("std");

pub const Menu = struct {
    buttons: []Button.Button,

    pub fn initAssetMenu(assetTree: AssetTree.AssetTree) Menu {
        const buttons: []Button.Button = undefined;
        std.debug.print("{}\n", .{assetTree});
        return Menu{
            .buttons = buttons,
        };
    }
};
