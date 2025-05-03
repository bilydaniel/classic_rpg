const std = @import("std");
const Config = @import("../common/config.zig");
const fs = std.fs;
const c = @cImport({
    @cInclude("raylib.h");
});

pub const Tileset = struct {
    allocator: std.mem.Allocator,
    source: ?*c.Texture2D = null,
    nodes: std.ArrayList(*TileNode),

    pub fn init(allocator: std.mem.Allocator) @This() {
        return Tileset{
            .allocator = allocator,
            .sourceRects = std.ArrayList(*TileNode).init(allocator),
        };
    }

    pub fn loadTileset(this: *Tileset, path: []const u8) !void {
        const pathTerminated = try std.fmt.allocPrint(this.allocator, "{s}\x00", .{path});
        const source = try this.allocator.create(c.Texture2D);
        source.* = c.LoadTexture(@ptrCast(pathTerminated));
        this.source = source;

        var i: i32 = 0;
        var j: i32 = 0;
        if (this.source) |tilesource| {
            while (i < tilesource.height) : (i += 16) {
                while (j < tilesource.width) : (j += 16) {
                    const tileNode = try this.allocator.create(TileNode);
                    tileNode.*.rect = c.Rectangle{ .x = @floatFromInt(j), .y = @floatFromInt(i), .height = Config.tile_height, .width = Config.tile_width };
                    tileNode.*.id = @intCast(this.nodes.items.len);

                    try this.nodes.append(tileNode);
                }
                j = 0;
            }
        }
    }
};

pub const TileNode = struct {
    id: i32,
    rect: c.Rectangle,
};
