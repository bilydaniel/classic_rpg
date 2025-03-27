const std = @import("std");
const fs = std.fs;
const c = @cImport({
    @cInclude("raylib.h");
});

pub const AssetTree = struct {
    head: *Node,
    current: *Node,
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !AssetTree {
        const head = try Node.init(allocator, "", true);

        return AssetTree{
            .allocator = allocator,
            .head = head,
            .current = head,
        };
    }

    //pub fn addNode

    pub fn loadFromDir(this: *AssetTree, parentPath: []const u8, parentNode: *Node) !void {
        var dir = try fs.cwd().openDir(parentPath, .{ .iterate = true });
        defer dir.close();

        var walker = dir.iterate();

        while (try walker.next()) |item| {
            if (badType(item)) {
                continue;
            }
            const isDir = item.kind == .directory;
            const newPath = try fs.path.join(this.allocator, &[_][]const u8{ parentPath, item.name });
            const newNode = try Node.init(this.allocator, newPath, isDir);
            try parentNode.children.append(newNode);

            if (isDir) {
                try loadFromDir(this, newPath, newNode);
            }
        }
    }

    fn badType(item: std.fs.Dir.Entry) bool {
        if (std.mem.endsWith(u8, item.name, ":Zone.Identifier")) {
            return true;
        }
        return false;
    }
};

pub fn printTree(node: *const Node, depth: usize) void {
    // Print indentation
    for (0..depth) |_| {
        std.debug.print("  ", .{});
    }

    // Print node info
    if (!node.isDir) {
        std.debug.print("📄 {s} \n", .{node.path});
    } else {
        std.debug.print("📁 {s}/\n", .{node.path});
    }

    // Print children
    for (node.children.items) |child| {
        printTree(child, depth + 1);
    }
}

const Node = struct {
    path: []const u8,
    isDir: bool,
    children: std.ArrayList(*Node),
    texture: c.Texture2D,

    pub fn init(allocator: std.mem.Allocator, path: []const u8, isDir: bool) !*Node {
        const node = try allocator.create(Node);
        std.debug.print("TEST: {s}\n", .{path});
        node.* = .{
            .path = path,
            .isDir = isDir,
            .children = std.ArrayList(*Node).init(allocator),
            //.texture = c.LoadTexture(path.ptr),
            .texture = c.LoadTexture(@ptrCast(path)),

            //const path_z = try std.cstr.addNullByte(allocator, path);
            //defer allocator.free(path_z);
            //.texture = c.LoadTexture(path_z.ptr),
        };

        return node;
    }
};
