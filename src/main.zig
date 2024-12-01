const std = @import("std");
const zul = @import("zul");

const fs = std.fs;
const eql = std.mem.eql;
const ArrayList = std.ArrayList;
const test_allocator = std.testing.allocator;

const SPACE = 32;
const ASCII_NUMBER_OFFSET = 48;

const FileOpenError = error{
    ListsOutOfSync,
    AccessDenied,
    OutOfMemory,
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

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) std.testing.expect(false) catch @panic("TEST FAIL");
    }

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    var line_it = try read_data_file();
    defer line_it.deinit();

    var leftList = ArrayList(isize).init(allocator);
    var rightList = ArrayList(isize).init(allocator);
    defer {
        leftList.deinit();
        rightList.deinit();
    }

    std.debug.print("Reading data...\n", .{});
    while (try line_it.next()) |line| {
        // std.debug.print("{s}\n", .{line});

        var left = true;
        var leftValue: isize = 0;
        var rightValue: isize = 0;

        for (line) |char| {
            if (char == SPACE) {
                left = false;
                continue;
            } else if (char < ASCII_NUMBER_OFFSET or char > 57) {
                continue;
            }

            const value = char - ASCII_NUMBER_OFFSET;

            if (left) {
                leftValue *= 10;
                leftValue = leftValue + @as(isize, value);
            } else {
                rightValue *= 10;
                rightValue = rightValue + @as(isize, value);
            }
        }

        try leftList.append(leftValue);
        try rightList.append(rightValue);
        // std.debug.print("L: {d}\tR: {d}\n", .{ leftValue, rightValue });
    }

    // std.debug.print("\n", .{});

    const leftArr = leftList.items;
    const rightArr = rightList.items;

    std.mem.sort(isize, leftArr, {}, comptime std.sort.asc(isize));
    std.mem.sort(isize, rightArr, {}, comptime std.sort.asc(isize));

    // for (leftArr) |value| {
    //     std.debug.print("{d} ", .{value});
    // }

    // std.debug.print("\n", .{});
    // for (rightArr) |value| {
    //     std.debug.print("{d} ", .{value});
    // }

    if (leftArr.len != rightArr.len) {
        return error.ListsOutOfSync;
    }

    var lastValue = @as(isize, 0);
    var lastSimilarity = @as(isize, 0);

    var similarity = @as(isize, 0);
    for (leftArr) |leftValue| {
        if (leftValue == lastValue) {
            similarity += lastSimilarity;
            continue;
        }

        var count = @as(isize, 0);
        for (rightArr) |rightValue| {
            if (leftValue == rightValue) {
                count += 1;
            }
        }

        lastSimilarity = leftValue * count;
        lastValue = leftValue;
        similarity += lastSimilarity;
    }

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Total distance = {d}.\n", .{similarity});
    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // don't forget to flush!
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
