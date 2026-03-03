//! Logging functionality

const c = @cImport({
    @cDefine("USE_HAL_DRIVER", {});
    @cDefine("STM32F446xx", {});
    @cInclude("main.h");
});

const std = @import("std");

extern var huart2: c.UART_HandleTypeDef;

pub inline fn info(msg: []const u8) void {
    _ = c.HAL_UART_Transmit(&huart2, @ptrCast(msg), @truncate(msg.len), 1000);
}

var buf: [1024]u8 = undefined;

pub inline fn log(comptime fmt: []const u8, args: anytype) void {
    const print = std.fmt.bufPrint(&buf, fmt, args) catch unreachable;
    info(print);
}
