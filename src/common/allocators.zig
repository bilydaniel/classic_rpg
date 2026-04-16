const std = @import("std");

pub var gpa: std.heap.GeneralPurposeAllocator(.{}) = .{};
pub var persistent: std.mem.Allocator = undefined;

pub var page = std.heap.page_allocator;

pub var frameArena: std.heap.ArenaAllocator = undefined;
pub var frame: std.mem.Allocator = undefined;

pub var scratchArena: std.heap.ArenaAllocator = undefined;
pub var scratch: std.mem.Allocator = undefined;

//TODO: make some sort of array of arenas?
pub var scratchArena2: std.heap.ArenaAllocator = undefined;
pub var scratch2: std.mem.Allocator = undefined;

pub fn init() void {
    persistent = gpa.allocator();

    //TODO: remove after debug
    page = persistent;

    frameArena = std.heap.ArenaAllocator.init(page);
    frame = frameArena.allocator();

    scratchArena = std.heap.ArenaAllocator.init(page);
    scratch = scratchArena.allocator();

    scratchArena2 = std.heap.ArenaAllocator.init(page);
    scratch2 = scratchArena2.allocator();
}

pub fn deinit() void {
    frameArena.deinit();
    scratchArena.deinit();
    scratchArena2.deinit();
    _ = gpa.deinit();
}

pub fn resetScratchArena() void {
    _ = scratchArena.reset(.retain_capacity);
}
