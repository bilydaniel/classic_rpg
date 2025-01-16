const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    //const raylib_dep = b.dependency("raylib", .{
    //   .target = target,
    //    .optimize = optimize,
    //});

    const exe = b.addExecutable(.{
        .name = "rpg-game",
        .root_source_file = .{ .cwd_relative = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    //exe.root_module.addImport("raylib", raylib_dep.module("raylib"));
    //
    // Link with raylib
    //exe.addIncludePath(.{ .cwd_relative = "/home/daniel/raylib/raylib/src" });
    exe.linkLibC();
    //exe.addIncludePath(.{ .std_file = "/usr/include" });
    //exe.addLibraryPath(.{ .std_file = "/usr/lib/x86_64-linux-gnu" });
    exe.linkSystemLibrary("raylib");

    // Add additional required system libraries
    exe.linkSystemLibrary("GL");
    exe.linkSystemLibrary("m");
    exe.linkSystemLibrary("pthread");
    exe.linkSystemLibrary("dl");
    exe.linkSystemLibrary("rt");
    exe.linkSystemLibrary("X11");
    //exe.addIncludePath(.{ .cwd_relative = "/home/daniel/raylib/src" });
    //exe.addClangArg("-L/home/daniel/raylib/src");
    // Install the executable
    b.installArtifact(exe);

    // Create a run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the game");
    run_step.dependOn(&run_cmd.step);
}
