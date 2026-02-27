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
        logger.info("Buffer Reached Capacity\r\n");
    };
}

pub fn sendAllData() void {
    logger.info("task_id,timestamp_us,total_rt,total_io_wt,total_ready_wt,delta\r\n");
    for (0..entries.len) |i| {
        entries.vals[i].log();
    }
}
