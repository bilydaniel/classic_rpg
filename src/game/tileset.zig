const std = @import("std");
const fs = std.fs;
const c = @cImport({
    @cInclude("raylib.h");
});

pub const Tileset = struct {
    allocator: std.mem.Allocator,
    source: c.Texture = null,
    sourceRects: std.ArrayList(c.Rectangle),

    pub fn init(allocator: std.mem.Allocator) @This() {
        return Tileset{
            .allocator = allocator,
            .sourceRects = std.ArrayList(c.Rectangle).init(allocator),
        };
    }

    pub fn loadTileset(this: *Tileset, path: []const u8) !void {
        this.source = c.LoadTexture(path.ptr);
    }
};
