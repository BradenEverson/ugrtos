//! Heuristics tracker

const std = @import("std");

const c = @cImport({
    @cDefine("USE_HAL_DRIVER", {});
    @cDefine("STM32F446xx", {});
    @cInclude("main.h");
});

const TaskData = @import("task.zig").TaskData;
const FixedBufferAl = @import("fixed_buffer.zig").FixedBufferArrayList;

const logger = @import("../hal/logger.zig");

const MAX_LOGS: usize = 1000;

var entries: FixedBufferAl(TaskData, MAX_LOGS) = .{};

pub fn addData(data: TaskData) void {
    entries.append(data) catch {
        sendAllData();
        @panic("We're done here\n");
    };
}

pub fn sendAllData() void {
    for (0..entries.len) |i| {
        entries.vals[i].log();
    }
}
