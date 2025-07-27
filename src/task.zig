const std = @import("std");

/// Represents a single to-do item.
/// `comptime` ensures these fields are available at compile-time, which is useful
/// for reflection, especially with JSON serialization.
pub const Task = struct {
    id: u32,
    description: []const u8,
    completed: bool,

    // This is a method on the Task struct. It formats a task for printing.
    pub fn format(
        self: Task,
        writer: anytype, // Can be a file, stdout, or any writer
    ) !void {
        const status = if (self.completed) "[x]" else "[ ]";
        try writer.print("{d}. {s} {s}\n", .{ self.id, status, self.description });
    }
};
