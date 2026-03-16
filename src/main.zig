//! Zig Entrypoint

const std = @import("std");

const logger = @import("hal/logger.zig");
const time = @import("hal/time.zig");

const heuristics = @import("scheduler/heuristics.zig");
const io = @import("scheduler/io_manager.zig");

const tasks = @import("tasks.zig");
const printer_tasks = @import("printer_tasks.zig");
const scheduler = @import("scheduler/scheduler.zig");

const c = @cImport({
    @cDefine("USE_HAL_DRIVER", {});
    @cDefine("STM32F446xx", {});
    @cInclude("main.h");
});

var sched = scheduler.Scheduler{};

pub inline fn ioCall(call: io.IoCall) void {
    sched.ioCall(call);
}

pub fn logDeltaTables() void {
    for (0..sched.task_count) |i| {
        logger.log("{c} - {any}\r\n", .{ sched.tasks[i].id, sched.tasks[i].agent.deltas });
    }
}

pub fn logQTables() void {
    for (0..sched.task_count) |i| {
        logger.log("{c} - {any}\r\n", .{ sched.tasks[i].id, sched.tasks[i].agent.q_table });
    }
}

export fn ScheduleNext() void {
    sched.schedule();
}

export fn sleepIt() void {
    sched.io_manager.sleepRetIt();
}

export fn gpioIt(port: usize, pin: usize) void {
    _ = port;
    const gpio = io.Gpio{ .port = .B, .pin = pin };
    sched.io_manager.gpioRetIt(gpio);
}

export fn uartRxIt(u: u8) void {
    const uart = io.Uart.fromU8(u).?;
    sched.io_manager.uartReceiveRetIt(uart);
}

export fn uartTxIt(u: u8) void {
    const uart = io.Uart.fromU8(u).?;
    sched.io_manager.uartTransmitRetIt(uart);
}

export fn buttonIt() void {
    scheduler.disable_irq();
    heuristics.sendAllData();
    logDeltaTables();
    logQTables();
    @panic("We should not recover from this");
}

extern var huart5: c.UART_HandleTypeDef;
const msg = [1]u8{64};
var buf: [64]u8 = undefined;

export fn entry() callconv(.c) void {
    c.SET_TIME_DELTA(10);

    // sched.register(printer_tasks.eStop, 'e');
    // sched.register(printer_tasks.thermalMonitor, 'T');
    // sched.register(printer_tasks.heartbeat, 'H');
    // sched.register(printer_tasks.fanControl, 'f');
    // sched.register(printer_tasks.gcodeParser, 'G');

    // sched.register(tasks.uartPrint(), 'U');
    // sched.register(tasks.echo, 'E');
    // sched.register(tasks.ioBlinky, 'B');
    // sched.register(tasks.ioBlinky2, 'D');
    // sched.register(tasks.ioBlinky3, 'E');
    sched.register(tasks.cpuBlinky, 'C');
    sched.register(tasks.cpuBlinky2, 'G');

    sched.start();
}
