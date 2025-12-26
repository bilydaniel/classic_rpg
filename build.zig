const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ----- Build options -----
    const fast_debug = b.option(bool, "fast-debug", "Fast iteration build (reduced debug info)") orelse true;
    const build_editor = b.option(bool, "editor", "Build editor") orelse false;
    const build_example = b.option(bool, "example", "Build example") orelse false;

    const actual_optimize =
        if (fast_debug) .ReleaseFast else optimize;

    // =========================
    // Game executable
    // =========================
    const game = b.addExecutable(.{
        .name = "classic_rpg",
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = actual_optimize,
    });

    game.linkLibC();
    game.linkSystemLibrary("raylib");

    // Faster iteration settings
    if (fast_debug) {
        game.root_module.strip = true; // no debug symbols
        game.root_module.omit_frame_pointer = true;
        game.root_module.sanitize_c = false;
        game.root_module.sanitize_thread = false;
    }

    // Only install for non-fast builds
    if (!fast_debug) {
        b.installArtifact(game);
    }

    const run_game = b.addRunArtifact(game);
    b.step("run-game", "Run the game").dependOn(&run_game.step);

    // =========================
    // Editor (optional)
    // =========================
    if (build_editor) {
        const editor = b.addExecutable(.{
            .name = "editor",
            .root_source_file = .{ .cwd_relative = "src/editor.zig" },
            .target = target,
            .optimize = actual_optimize,
        });

        editor.linkLibC();
        editor.linkSystemLibrary("raylib");

        if (!fast_debug) {
            b.installArtifact(editor);
        }

        const run_editor = b.addRunArtifact(editor);
        b.step("run-editor", "Run the editor").dependOn(&run_editor.step);
    }

    // =========================
    // Example (optional)
    // =========================
    if (build_example) {
        const example = b.addExecutable(.{
            .name = "example",
            .root_source_file = .{ .cwd_relative = "examples/slashing_animation.zig" },
            .target = target,
            .optimize = actual_optimize,
        });

        example.linkLibC();
        example.linkSystemLibrary("raylib");

        if (!fast_debug) {
            b.installArtifact(example);
        }

        const run_example = b.addRunArtifact(example);
        b.step("run-example", "Run the example").dependOn(&run_example.step);
    }

    // =========================
    // Full debug build (slow but debuggable)
    // =========================
    const game_debug = b.addExecutable(.{
        .name = "classic_rpg_debug",
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = .Debug,
        .single_threaded = true,
    });

    game_debug.root_module.omit_frame_pointer = false;
    game_debug.root_module.strip = false;
    game_debug.root_module.red_zone = false;

    game_debug.linkLibC();
    game_debug.linkSystemLibrary("raylib");

    b.installArtifact(game_debug);

    const install_debug = b.step("install-debug", "Install debug build");
    install_debug.dependOn(&b.addInstallArtifact(game_debug, .{}).step);

    const run_game_debug = b.addRunArtifact(game_debug);
    b.step("run-game-debug", "Run debug build of game").dependOn(&run_game_debug.step);
}
