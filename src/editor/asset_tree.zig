const std = @import("std");
const fs = std.fs;

pub const AssetTree = struct {
    head: *Node,
    current: *Node,
    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) !AssetTree {
        const head = try Node.init(allocator, "", true);

        std.debug.print("TEST: {}\n", .{head});
        return AssetTree{
            .allocator = allocator,
            .head = head,
            .current = head,
        };
    }

    //pub fn addNode

    pub fn loadFromDir(this: *AssetTree, dirPath: []const u8) !void {
        var dir = try fs.cwd().openDir(dirPath, .{ .iterate = true });
        defer dir.close();

        var walker = try dir.walk(this.allocator);
        defer walker.deinit();

        while (try walker.next()) |item| {
            if (item.kind == .directory) {} else {}
            std.debug.print("{s}\n", .{item.path});
        }
    }
};

const Node = struct {
    path: []const u8,
    isDir: bool,
    children: []Node,

    pub fn init(allocator: std.mem.Allocator, path: []const u8, isDir: bool) !*Node {
        const node = try allocator.create(Node);
        node.* = .{
            .path = path,
            .isDir = isDir,
            .children = std.ArrayList(*Node).init(allocator),
        };
        return node;
    }
};
