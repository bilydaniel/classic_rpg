const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    // Get standard optimize options from command line (still works as before)
    const optimize = b.standardOptimizeOption(.{});

    // Add an additional option for "fast debug" builds
    const fast_debug = b.option(bool, "fast-debug", "Enable fast debug build") orelse false;

    // Determine optimization level based on fast-debug flag
    const actual_optimize = if (fast_debug) std.builtin.OptimizeMode.ReleaseFast else optimize;

    const game = b.addExecutable(.{
        .name = "classic_rpg",
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = actual_optimize,
    });

    const editor = b.addExecutable(.{
        .name = "editor",
        .root_source_file = .{ .cwd_relative = "src/editor.zig" },
        .target = target,
        .optimize = actual_optimize,
    });

    const example = b.addExecutable(.{
        .name = "example",
        //change to what is needed
        .root_source_file = .{ .cwd_relative = "examples/slashing_animation.zig" },
        .target = target,
        .optimize = actual_optimize,
    });

    // Rest of your build script...
    game.linkLibC();
    editor.linkLibC();
    example.linkLibC();

    game.linkSystemLibrary("raylib");
    editor.linkSystemLibrary("raylib");
    example.linkSystemLibrary("raylib");

    b.installArtifact(game);
    b.installArtifact(editor);
    b.installArtifact(example);

    const run_game = b.addRunArtifact(game);
    const run_editor = b.addRunArtifact(editor);
    const run_example = b.addRunArtifact(example);

    // Standard run steps
    b.step("run-game", "Run the game").dependOn(&run_game.step);
    b.step("run-editor", "Run the editor").dependOn(&run_editor.step);
    b.step("run-example", "Run the example").dependOn(&run_example.step);

    // Add fast-debug specific run steps
    const run_game_fast = b.addRunArtifact(game);
    const run_editor_fast = b.addRunArtifact(editor);
    b.step("run-game-fast", "Run the game with fast debug").dependOn(&run_game_fast.step);
    b.step("run-editor-fast", "Run the editor with fast debug").dependOn(&run_editor_fast.step);

    //debug build
    const game_debug = b.addExecutable(.{
        .name = "classic_rpg",
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = std.builtin.OptimizeMode.Debug,
    });
    game_debug.root_module.strip = false;
    game_debug.linkLibC();
    game_debug.linkSystemLibrary("raylib");
    b.installArtifact(game_debug);

    const run_game_debug = b.addRunArtifact(game_debug);
    b.step("run-game-debug", "Run debug build of game").dependOn(&run_game_debug.step);
}
