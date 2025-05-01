const std = @import("std");
const Utils = @import("../common/utils.zig");
const fs = std.fs;
const c = @cImport({
    @cInclude("raylib.h");
});
//TODO: make a better system, dumb as fuck
pub const Assets = struct {
    playerTexture: c.Texture2D,
    baseTile: c.Texture2D,
    enemy: c.Texture2D,
    allocator: std.mem.Allocator,
    list: std.ArrayList(*Node),

    pub fn init(allocator: std.mem.Allocator) @This() {
        //TODO: try what happens if load fails
        const player_texture = c.LoadTexture("assets/random_character.png");
        const tile_texture = c.LoadTexture("assets/base_tile.png");
        const enemy_texture = c.LoadTexture("assets/enemy.png");
        return Assets{
            .playerTexture = player_texture,
            .baseTile = tile_texture,
            .enemy = enemy_texture,
            .allocator = allocator,
            .list = std.ArrayList(*Node).init(allocator),
        };
    }

    pub fn printList(assetList: Assets) void {
        for (assetList.list.items) |value| {
            std.debug.print("📄 {s} \n", .{value.path});
        }
    }

    pub fn loadFromDir(this: *Assets, path: []const u8) !void {
        var dir = try fs.cwd().openDir(path, .{ .iterate = true });
        defer dir.close();

        var walker = try dir.walk(this.allocator);
        defer walker.deinit();

        while (try walker.next()) |item| {
            if (badType(item)) {
                continue;
            }
            const assetpath = try std.fmt.allocPrint(this.allocator, "assets/{s}", .{item.path});
            //const newPathTerminated = try std.fmt.allocPrint(this.allocator, "{s}\x00", .{newPath});
            const newPath = try Utils.toNullTerminated(this.allocator, assetpath);
            //defer this.allocator.free(newPath);
            const newNode = try Node.init(this.allocator, newPath);
            try this.list.append(newNode);
        }
    }

    fn badType(item: std.fs.Dir.Walker.Entry) bool {
        if (item.kind == .directory) {
            return true;
        }
        if (std.mem.endsWith(u8, item.path, ":Zone.Identifier")) {
            return true;
        }
        return false;
    }

    pub fn deinit(this: @This()) void {
        c.UnloadTexture(this.playerTexture);
        c.UnloadTexture(this.baseTile);
        c.UnloadTexture(this.enemy);
    }
};

pub const Node = struct {
    path: []const u8,
    texture: *c.Texture2D,

    pub fn init(allocator: std.mem.Allocator, path: []const u8) !*Node {
        const texture = try allocator.create(c.Texture2D);
        texture.* = c.LoadTexture(@ptrCast(path));

        const node = try allocator.create(Node);
        node.* = .{
            .path = path,
            .texture = texture,
        };
        return node;
    }
};
