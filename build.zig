const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    //const raylib_dep = b.dependency("raylib", .{
    //   .target = target,
    //    .optimize = optimize,
    //});

    const game = b.addExecutable(.{
        .name = "rpg-game",
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const editor = b.addExecutable(.{
        .name = "editor",
        .root_source_file = .{ .cwd_relative = "src/editor.zig" },
        .target = target,
        .optimize = optimize,
    });

    game.linkLibC();
    editor.linkLibC();

    game.linkSystemLibrary("raylib");
    editor.linkSystemLibrary("raylib");
    //exe.linkSystemLibrary("GL");
    //exe.linkSystemLibrary("m");
    //exe.linkSystemLibrary("pthread");
    //exe.linkSystemLibrary("dl");
    //exe.linkSystemLibrary("rt");
    //exe.linkSystemLibrary("X11");

    b.installArtifact(game);
    b.installArtifact(editor);

    const run_game = b.addRunArtifact(game);
    const run_editor = b.addRunArtifact(editor);

    b.step("run-game", "Run the game").dependOn(&run_game.step);
    b.step("run-editor", "Run the editor").dependOn(&run_editor.step);
    //b.default_step = b.step("run-game", "Run the game by default");
    //run_cmd.step.dependOn(b.getInstallStep());
    //const run_step = b.step("run", "Run the game");
    //run_step.dependOn(&run_cmd.step);
}
