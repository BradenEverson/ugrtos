//! Generic tasks to register with known optima

const std = @import("std");

const logger = @import("hal/logger.zig");
const c = @cImport({
    @cDefine("USE_HAL_DRIVER", {});
    @cDefine("STM32F446xx", {});
    @cInclude("main.h");
});

const Scheduler = @import("scheduler/scheduler.zig").Scheduler;

const sched = @import("main.zig");

var buf: [64]u8 = undefined;
const req_size = [1]u8{64};

extern var huart5: c.UART_HandleTypeDef;

const GCodeCommand = struct {
    command_type: u8 = 0,
    command_val: i32 = 0,
    x: f32 = 0,
    y: f32 = 0,
    z: f32 = 0,
    f: f32 = 0,
};

/// G-Code Parser
pub fn gcodeParser() noreturn {
    while (true) {
        // Notify G-Code provider that we're ready
        // for 64 more bytes of G-Code
        _ = c.HAL_UART_Transmit(
            &huart5,
            @ptrCast(&req_size),
            @truncate(req_size.len),
            10,
        );

        // Wait to receive G-Code payload
        sched.ioCall(.{
            .UartReceive = .{
                .buf = &buf,
                .uart = .uart5,
            },
        });

        const term = std.mem.indexOf(u8, &buf, &[_]u8{0xFF});
        const line: []const u8 = if (term) |len| buf[0..len] else &buf;

        var tokens = std.mem.tokenizeAny(u8, line, " ");

        // Parse all tokens in the current line
        while (tokens.next()) |tok| {
            var cmd = GCodeCommand{};
            switch (tok[0]) {
                'G', 'g' => {
                    cmd.command_type = 'G';
                    cmd.command_val = std.fmt.parseInt(i32, tok[1..], 10) catch 0;
                },

                'M', 'm' => {
                    cmd.command_type = 'M';
                    cmd.command_val = std.fmt.parseInt(i32, tok[1..], 10) catch 0;
                },
                'X', 'x' => cmd.x = std.fmt.parseFloat(f32, tok[1..]) catch 0,
                'Y', 'y' => cmd.y = std.fmt.parseFloat(f32, tok[1..]) catch 0,
                'Z', 'z' => cmd.z = std.fmt.parseFloat(f32, tok[1..]) catch 0,
                'F', 'f' => cmd.f = std.fmt.parseFloat(f32, tok[1..]) catch 0,
                else => {},
            }
        }
    }
}

pub fn eStop() noreturn {
    while (true) {
        sched.ioCall(.{
            .GpioWait = .{
                .port = .B,
                .pin = 6,
            },
        });

        @panic("ESTOP TRIGGERED!!!");
    }
}

pub fn heartbeat() noreturn {
    while (true) {
        c.HAL_GPIO_TogglePin(c.GPIOB, c.GPIO_PIN_5);
        sched.ioCall(.{
            .SleepMs = 1000,
        });
    }
}

pub fn fanControl() noreturn {
    const duty_cycle: u32 = 20;
    while (true) {
        c.HAL_GPIO_WritePin(c.GPIOB, c.GPIO_PIN_8, c.GPIO_PIN_SET);
        sched.ioCall(.{ .SleepMs = duty_cycle });

        c.HAL_GPIO_WritePin(c.GPIOB, c.GPIO_PIN_8, c.GPIO_PIN_RESET);
        sched.ioCall(.{ .SleepMs = 100 - duty_cycle });
    }
}

const TARGET_TEMP = 200.0;
const HYSTERESIS = 2.0;

pub fn thermalMonitor() noreturn {
    var heater_on: bool = false;

    while (true) {
        const current_temp = readThermistor();

        if (current_temp < (TARGET_TEMP - HYSTERESIS)) {
            c.HAL_GPIO_WritePin(c.GPIOB, c.GPIO_PIN_0, c.GPIO_PIN_SET);
            heater_on = true;
        } else if (current_temp > (TARGET_TEMP + HYSTERESIS)) {
            c.HAL_GPIO_WritePin(c.GPIOB, c.GPIO_PIN_0, c.GPIO_PIN_RESET);
            heater_on = false;
        }

        sched.ioCall(.{ .SleepMs = 500 });
    }
}

fn readThermistor() f32 {
    return 195.0;
}
