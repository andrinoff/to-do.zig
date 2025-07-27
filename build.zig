const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target options allowing for cross-compilation.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options (Debug, ReleaseSafe, ReleaseFast, ReleaseSmall).
    const optimize = b.standardOptimizeOption(.{});

    // Create the executable for our to-do application.
    const exe = b.addExecutable(.{
        .name = "todo",
        // The root source file is main.zig.
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // This adds the executable to the build's installation step.
    // Running 'zig build' will create it in 'zig-out/bin/todo'.
    b.installArtifact(exe);

    // --- Convenience Run Step ---
    // This creates a 'run' step so you can use 'zig build run'.
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows you to pass arguments to your program with 'zig build run -- arg1 arg2'.
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the application");
    run_step.dependOn(&run_cmd.step);
}
