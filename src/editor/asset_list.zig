const std = @import("std");
const fs = std.fs;
const c = @cImport({
    @cInclude("raylib.h");
});

pub const AssetList = struct {
    allocator: std.mem.Allocator,
    list: std.ArrayList(*Node),

    pub fn init(allocator: std.mem.Allocator) !AssetList {
        return AssetList{
            .allocator = allocator,
            .list = std.ArrayList(*Node).init(allocator),
        };
    }

    pub fn loadFromDir(this: *AssetList, path: []const u8) !void {
        var dir = try fs.cwd().openDir(path, .{ .iterate = true });
        defer dir.close();

        var walker = try dir.walk(this.allocator);
        defer walker.deinit();

        while (try walker.next()) |item| {
            std.debug.print("{s}\n", .{item.path});
            if (badType(item)) {
                continue;
            }
            //const newPath = try std.fs.path.join(this.allocator, &[_][]const u8{ "assets", item.path });
            const newPath = try std.fmt.allocPrint(this.allocator, "assets/{s}\x00", .{item.path});
            const newPathTerminated = try std.fmt.allocPrint(this.allocator, "{s}\x00", .{newPath});
            defer this.allocator.free(newPath);
            defer this.allocator.free(newPathTerminated);
            const newNode = try Node.init(this.allocator, newPath, newPathTerminated);
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
};

pub fn printList(assetList: AssetList) void {
    for (assetList.list.items) |value| {
        std.debug.print("📄 {s} \n", .{value.path});
    }
}

const Node = struct {
    path: []const u8,
    texture: c.Texture2D,

    pub fn init(allocator: std.mem.Allocator, path: []const u8, pathTerminated: []const u8) !*Node {
        const node = try allocator.create(Node);
        //const path_z = try std.cstr.addNullByte(allocator, path);
        //defer allocator.free(path_z);
        node.* = .{
            .path = path,
            //.texture = c.LoadTexture(path.ptr),
            .texture = c.LoadTexture(@ptrCast(pathTerminated)),
            //.texture = c.LoadTexture(path_z.ptr),
        };
        std.debug.print("NODE: {s}", .{node.path}); //TODO: asi chyba tady, nejspis blbe zaalokovany string??

        return node;
    }
};
