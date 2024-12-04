const std = @import("std");
const zul = @import("zul");
const root = @import("root");

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

pub fn splice_array(slice: []const isize, skip_index: usize, allocator: std.mem.Allocator) ![]isize {
    // Create a new array with length - 1
    var result = try allocator.alloc(isize, slice.len - 1);

    // Copy first part
    @memcpy(result[0..skip_index], slice[0..skip_index]);

    // Copy second part
    @memcpy(result[skip_index..], slice[skip_index + 1 ..]);

    return result;
}

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

pub fn check_sequence(report: []const isize) bool {
    if (report.len < 2) return false;

    const isIncreasing = report[0] < report[1];

    var last_value: ?isize = null;

    for (report) |value| {
        if (last_value == null) {
            last_value = value;
            continue;
        }

        if (last_value == value) {
            return false;
        }

        // Check difference
        const diff = @abs(last_value.? - value);
        if (diff > 3) return false;

        // Check pattern
        if (isIncreasing and value <= last_value.?) {
            return false;
        } else if (!isIncreasing and value >= last_value.?) {
            return false;
        }

        last_value = value;
    }

    return true;
}

pub fn is_report_safe(report: []const isize, allocator: std.mem.Allocator) !bool {
    // First try without skipping any number
    if (check_sequence(report)) return true;

    // Try skipping each number
    for (0..report.len) |skip_index| {
        const tmp = try splice_array(report, skip_index, allocator);
        defer allocator.free(tmp);

        if (check_sequence(tmp)) return true;
    }

    return false;
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

    for (reportList) |report| {
        if (try is_report_safe(report, allocator)) {
            safeReportCount += 1;
        }
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
