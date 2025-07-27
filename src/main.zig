const std = @import("std");

// Import our own modules.
const storage = @import("storage.zig");
const Task = @import("task.zig").Task;

pub fn main() !void {
    // We need an allocator for dynamic memory management.
    // GeneralPurposeAllocator is a good default. It checks for memory leaks in debug builds.
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit(); // Ensure we check for leaks on exit.
    const allocator = gpa.allocator();

    // `argsAlloc` allocates memory for the command-line arguments.
    // We use `try` to propagate any errors.
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    // Load existing tasks from the file.
    var tasks = try storage.loadTasks(allocator);
    // Ensure we free all task memory when the program exits
    defer {
        // Free all task descriptions before deinitializing the list
        for (tasks.items) |task| {
            allocator.free(task.description);
        }
        tasks.deinit();
    }

    // `defer` ensures `saveTasks` is called right before the function exits,
    // whether it exits normally or due to an error. This is a powerful feature.
    defer storage.saveTasks(tasks) catch |err| {
        std.log.err("FATAL: Could not save tasks: {s}", .{@errorName(err)});
    };

    const stdout_writer = std.io.getStdOut().writer();

    // The first argument (index 0) is the program name.
    // We check if a command was provided.
    if (args.len < 2) {
        try printHelp(stdout_writer);
        return;
    }

    const command = args[1];

    // --- Command Handling ---
    if (std.mem.eql(u8, command, "list")) {
        try listTasks(tasks, stdout_writer);
    } else if (std.mem.eql(u8, command, "add")) {
        if (args.len < 3) {
            try stdout_writer.writeAll("Error: 'add' command requires a description.\n");
            return;
        }
        // Join all arguments after 'add' to form the task description.
        const description = try std.mem.join(allocator, " ", args[2..]);
        defer allocator.free(description);
        try addTask(&tasks, description, allocator);
        try stdout_writer.writeAll("Added new task.\n");
    } else if (std.mem.eql(u8, command, "done")) {
        if (args.len < 3) {
            try stdout_writer.writeAll("Error: 'done' command requires a task ID.\n");
            return;
        }
        const id_str = args[2];
        const id = try std.fmt.parseInt(u32, id_str, 10);
        if (try markTaskDone(&tasks, id)) {
            try stdout_writer.print("Marked task {d} as done.\n", .{id});
        } else {
            try stdout_writer.print("Error: Task with ID {d} not found.\n", .{id});
        }
    } else {
        try printHelp(stdout_writer);
    }
}

fn printHelp(writer: anytype) !void {
    try writer.writeAll(
        \\Usage: todo [command]
        \\
        \\Commands:
        \\  list          List all current tasks
        \\  add [desc]    Add a new task with a description
        \\  done [id]     Mark a task as completed
        \\
    );
}

fn listTasks(tasks: std.ArrayList(Task), writer: anytype) !void {
    if (tasks.items.len == 0) {
        try writer.writeAll("No tasks yet! Add one with 'todo add ...'\n");
        return;
    }
    for (tasks.items) |task| {
        try task.format(writer);
    }
}

fn addTask(tasks: *std.ArrayList(Task), description: []const u8, allocator: std.mem.Allocator) !void {
    // Find the highest existing ID to determine the next ID.
    var next_id: u32 = 0;
    for (tasks.items) |task| {
        if (task.id > next_id) {
            next_id = task.id;
        }
    }
    next_id += 1;

    const new_task = Task{
        .id = next_id,
        .description = try allocator.dupe(u8, description),
        .completed = false,
    };

    try tasks.append(new_task);
}

fn markTaskDone(tasks: *std.ArrayList(Task), id: u32) !bool {
    for (tasks.items) |*task| {
        if (task.id == id) {
            task.completed = true;
            return true;
        }
    }
    return false;
}
