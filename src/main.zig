const std = @import("std");
const zul = @import("zul");

const fs = std.fs;
const eql = std.mem.eql;
const ArrayList = std.ArrayList;
const test_allocator = std.testing.allocator;

const LINE_FEED = 10;
const SPACE = 32;
const ASCII_NUMBER_OFFSET = 48;

const FileOpenError = error{
    ListsOutOfSync,
    FileNotFound,
};

pub fn read_data_file() !zul.fs.LineIterator {
    // create a buffer large enough to hold the longest valid line
    var line_buffer: [1024]u8 = undefined;

    // Parameters:
    // 1- an absolute or relative path to the file
    // 2- the line buffer
    // 3- options (here we're using the default)
    const it = try zul.fs.readLines("data.txt", &line_buffer, .{});
    return it;
}

fn is_numeric_char(char: u8) bool {
    return char >= ASCII_NUMBER_OFFSET and char <= 57;
}

pub fn parse_line(line: []const u8, allocator: std.mem.Allocator) ![]isize {
    var numbers = ArrayList(isize).init(allocator);
    defer numbers.deinit();

    var iter = std.mem.splitScalar(u8, line, ' ');
    while (iter.next()) |substring| {
        if (substring.len == 0) continue; // Skip empty parts

        const value = try std.fmt.parseInt(isize, substring, 10);
        try numbers.append(value);
    }

    return try numbers.toOwnedSlice();
}

pub fn parse_data(line_it: *zul.fs.LineIterator, allocator: std.mem.Allocator) ![][]isize {
    var reportList = ArrayList([]isize).init(allocator);
    defer reportList.deinit();

    while (try line_it.next()) |line| {
        const numbers = try parse_line(line, allocator);
        try reportList.append(numbers);
    }

    return try reportList.toOwnedSlice();
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) std.testing.expect(false) catch @panic("TEST FAIL");
    }

    var line_it = try read_data_file();
    defer line_it.deinit();

    const reportList = try parse_data(&line_it, allocator);
    defer {
        // Free each inner array
        for (reportList) |report| {
            allocator.free(report);
        }
        // Free the outer array
        allocator.free(reportList);
    }

    var safeReportCount: usize = 0;

    reportListLoop: for (reportList) |report| {
        var previous: isize = -1;
        var isIncreasing: ?bool = null;

        // Make sure we had enough numbers to determine a pattern
        if (report.len < 2) {
            continue;
        }

        for (report) |value| {
            if (previous == -1) {
                previous = value;
                continue;
            }

            std.debug.print(" ({d} {d}) ", .{ previous, value });

            if (previous == value) {
                continue :reportListLoop;
            }

            const diff: usize = @abs(previous - value);
            std.debug.print(" = {d}\n ", .{diff});
            if (diff > 3) {
                continue :reportListLoop;
            }

            // Check increasing/decreasing pattern
            if (isIncreasing == null) {
                isIncreasing = value > previous;
            } else if (isIncreasing.? and value < previous) {
                continue :reportListLoop;
            } else if (!isIncreasing.? and value > previous) {
                continue :reportListLoop;
            }

            previous = value;
        }

        safeReportCount += 1;
    }

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("\nAnswer = {d}.\n", .{safeReportCount});
    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // don't forget to flush!
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
