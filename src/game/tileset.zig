const std = @import("std");
const Config = @import("../common/config.zig");
const fs = std.fs;
const c = @cImport({
    @cInclude("raylib.h");
});

pub const Tileset = struct {
    allocator: std.mem.Allocator,
    source: ?*c.Texture2D = null,
    sourceRects: std.ArrayList(*c.Rectangle),

    pub fn init(allocator: std.mem.Allocator) @This() {
        return Tileset{
            .allocator = allocator,
            .sourceRects = std.ArrayList(*c.Rectangle).init(allocator),
        };
    }

    pub fn loadTileset(this: *Tileset, path: []const u8) !void {
        const pathTerminated = try std.fmt.allocPrint(this.allocator, "{s}\x00", .{path});
        const source = try this.allocator.create(c.Texture2D);
        source.* = c.LoadTexture(@ptrCast(pathTerminated));
        this.source = source;

        var i: i32 = 0;
        var j: i32 = 0;
        while (i < this.source.height) : (i += 16) {
            while (j < this.source.width) : (j += 16) {
                const rect = try this.allocator.create(c.Rectangle);
                rect.* = c.Rectangle{ .x = @floatFromInt(j), .y = @floatFromInt(i), .height = Config.tile_height, .width = Config.tile_width };
                try this.sourceRects.append(rect);
            }
        }

        std.debug.print("SOURCE_LOAD: {}", .{this.source});
    }
};
