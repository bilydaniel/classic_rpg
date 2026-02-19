const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ----- Build options -----
    const fast_debug = b.option(bool, "fast-debug", "Fast iteration build (reduced debug info)") orelse false;
    const build_editor = b.option(bool, "editor", "Build editor") orelse false;
    const build_example = b.option(bool, "example", "Build example") orelse false;

    const actual_optimize = if (fast_debug) .ReleaseFast else optimize;

    // ----- Raylib Dependency -----
    // This looks for "raylib" in your build.zig.zon
    const raylib_dep = b.dependency("raylib_zig", .{
        .target = target,
        .optimize = actual_optimize,
    });
    const raylib_artifact = raylib_dep.artifact("raylib");

    // =========================
    // Game executable
    // =========================
    const game = b.addExecutable(.{
        .name = "classic_rpg",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = actual_optimize,
        }),
    });

    // Link the fetched Raylib instead of system library
    game.linkLibrary(raylib_artifact);
    game.linkLibC();
    game.root_module.addImport("raylib", raylib_dep.module("raylib"));

    // Faster iteration settings
    if (fast_debug) {
        game.root_module.strip = true;
        game.root_module.omit_frame_pointer = true;
        game.root_module.sanitize_c = .off; // Enum fix
        game.root_module.sanitize_thread = false;
    }

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
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/editor.zig"),
                .target = target,
                .optimize = actual_optimize,
            }),
        });

        editor.linkLibrary(raylib_artifact);
        editor.linkLibC();
        editor.root_module.addImport("raylib", raylib_dep.module("raylib"));

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
            .root_module = b.createModule(.{
                .root_source_file = b.path("examples/slashing_animation.zig"),
                .target = target,
                .optimize = actual_optimize,
            }),
        });

        example.linkLibrary(raylib_artifact);
        example.linkLibC();

        if (!fast_debug) {
            b.installArtifact(example);
        }

        const run_example = b.addRunArtifact(example);
        b.step("run-example", "Run the example").dependOn(&run_example.step);
    }

    // =========================
    // Full debug build
    // =========================
    const game_debug = b.addExecutable(.{
        .name = "classic_rpg_debug",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = .Debug,
            .single_threaded = true,
        }),
    });

    game_debug.root_module.omit_frame_pointer = false;
    game_debug.root_module.strip = false;
    game_debug.root_module.red_zone = false;

    // Use the dependency for debug build too
    game_debug.linkLibrary(raylib_artifact);
    game_debug.linkLibC();
    game_debug.root_module.addImport("raylib", raylib_dep.module("raylib"));

    b.installArtifact(game_debug);

    const install_debug = b.step("install-debug", "Install debug build");
    install_debug.dependOn(&b.addInstallArtifact(game_debug, .{}).step);

    const run_game_debug = b.addRunArtifact(game_debug);
    b.step("run-game-debug", "Run debug build of game").dependOn(&run_game_debug.step);
}
