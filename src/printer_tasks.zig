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
        const line = buf[0..term.?];
        _ = line;

        // logger.log("{s}\r\n", .{line});

        // const parse = parseLine(line) catch
        //     GCodeCommand{ .command_type = 0, .command_val = 0 };
        //
        // logger.log("{c} {any} {any} {any} {any}\r\n", .{ parse.command_type, parse.x, parse.y, parse.z, parse.f });
    }
}

const GCodeCommand = struct {
    command_type: u8,
    command_val: i32,
    x: ?f32 = null,
    y: ?f32 = null,
    z: ?f32 = null,
    f: ?f32 = null,
};

pub inline fn parseLine(line: []const u8) !GCodeCommand {
    var result = GCodeCommand{ .command_type = 0, .command_val = 0 };

    var clean_buf: [64]u8 = undefined;
    var write_idx: usize = 0;
    var in_paren = false;

    for (line) |char| {
        if (in_paren) {
            if (char == ')') in_paren = false;
            continue;
        }
        if (char == '(') {
            in_paren = true;
            continue;
        }
        if (char == ';') break;

        if (write_idx < clean_buf.len) {
            clean_buf[write_idx] = char;
            write_idx += 1;
        }
    }
    const clean_line = std.mem.trim(u8, clean_buf[0..write_idx], " \t\r\n");

    var tokens = std.mem.tokenizeScalar(u8, clean_line, ' ');
    while (tokens.next()) |token| {
        if (token.len < 2) continue;

        const letter = std.ascii.toUpper(token[0]);
        const value_str = token[1..];

        switch (letter) {
            'G', 'M' => {
                result.command_type = letter;
                result.command_val = try std.fmt.parseInt(i32, value_str, 10);
            },
            'X' => result.x = try std.fmt.parseFloat(f32, value_str),
            'Y' => result.y = try std.fmt.parseFloat(f32, value_str),
            'Z' => result.z = try std.fmt.parseFloat(f32, value_str),
            'F' => result.f = try std.fmt.parseFloat(f32, value_str),
            else => {},
        }
    }
    return result;
}
