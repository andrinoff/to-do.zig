const std = @import("std");
const Task = @import("task.zig").Task;

const data_file_name = ".zig_todo.json";

/// Gets the full path to the data file, placing it in the user's home directory.
fn getStoragePath(allocator: std.mem.Allocator) ![]u8 {
    const home_dir = std.posix.getenv("HOME") orelse {
        std.log.err("HOME environment variable not set", .{});
        return error.HomeNotFound;
    };
    return std.fs.path.join(allocator, &.{ home_dir, data_file_name });
}

/// Loads the list of tasks from the JSON file.
/// It returns an ArrayList of Tasks. If the file doesn't exist, it returns
/// an empty list.
pub fn loadTasks(allocator: std.mem.Allocator) !std.ArrayList(Task) {
    const file_path = getStoragePath(allocator) catch |err| {
        // If we can't get home dir, we can't proceed.
        std.log.err("Could not determine home directory: {s}", .{@errorName(err)});
        return err;
    };
    defer allocator.free(file_path);

    // Open the file. If it doesn't exist, that's okay, we'll just return
    // an empty list of tasks.
    const file = std.fs.openFileAbsolute(file_path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            return std.ArrayList(Task).init(allocator);
        }
        return err;
    };
    defer file.close();

    // Read the entire file content into memory.
    const file_content = file.readToEndAlloc(allocator, 1_000_000) catch |err| {
        std.log.err("Failed to read task file: {s}", .{@errorName(err)});
        return err;
    };
    defer allocator.free(file_content);

    // If the file is empty, return a new empty list.
    if (file_content.len == 0) {
        return std.ArrayList(Task).init(allocator);
    }

    // Parse the JSON content into our Task structs.
    const parsed = std.json.parseFromSlice([]Task, allocator, file_content, .{}) catch |err| {
        std.log.err("Failed to parse task file (is it corrupt?): {s}", .{@errorName(err)});
        return err;
    };
    defer parsed.deinit();

    // Convert the parsed slice to an ArrayList
    var tasks = std.ArrayList(Task).init(allocator);
    for (parsed.value) |task| {
        try tasks.append(task);
    }

    return tasks;
}

/// Saves the list of tasks to the JSON file.
pub fn saveTasks(tasks: std.ArrayList(Task)) !void {
    const allocator = tasks.allocator;
    const file_path = try getStoragePath(allocator);
    defer allocator.free(file_path);

    const file = try std.fs.createFileAbsolute(file_path, .{});
    defer file.close();

    // Serialize the task list to JSON and write it to the file.
    try std.json.stringify(tasks.items, .{ .whitespace = .indent_4 }, file.writer());
}
