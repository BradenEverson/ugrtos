//! Scheduler control for all the tasks

const task = @import("task.zig");
const time = @import("../hal/time.zig");
const Task = task.Task;

const heuristics = @import("heuristics.zig");
const logger = @import("../hal/logger.zig");

extern fn SchedulerStart() void;

const c = @cImport({
    @cDefine("USE_HAL_DRIVER", {});
    @cDefine("STM32F446xx", {});
    @cInclude("main.h");
});

pub inline fn disable_irq() void {
    asm volatile ("cpsid i" ::: .{ .memory = true });
}

pub inline fn enable_irq() void {
    asm volatile ("cpsie i" ::: .{ .memory = true });
}

export var CurrentTask: *Task = undefined;

/// How many context switches between logging
const LOG_EVERY: usize = 100;

pub const Scheduler = struct {
    task_count: usize = 0,
    curr: usize = 0,
    tasks: [task.MAX_TASKS]Task = undefined,

    total_system_wait: usize = 0,
    avg_system_wait: f32 = 0,

    last_time: u32 = 0,
    switches: u32 = 0,

    /// Choose who goes next and allocate the proper time slice for them
    pub inline fn preempt_schedule(self: *Scheduler) void {
        const prev = self.curr;

        const now = time.getTimeMicros();

        const delta = now - self.last_time;
        // CurrentTask.metadata.total_run_time += delta;
        CurrentTask.metadata.run_time = delta;

        // TODO: If we enter an IO wait queue instead don't do this
        // we might just want a different version of schedule
        CurrentTask.metadata.time_put_on_wait = now;

        self.curr += 1;
        self.curr %= self.task_count;

        CurrentTask = &self.tasks[self.curr];

        self.last_time = time.getTimeMicros();

        if (self.curr != prev) {
            // If we were not the last one running, need to update
            // non-busy time spent waiting
            CurrentTask.metadata.ready_wait_time = self.last_time - CurrentTask.metadata.time_put_on_wait;
            self.total_system_wait += CurrentTask.metadata.ready_wait_time;
        }

        self.calcAvgWait();

        self.switches += 1;
        if (self.switches % (LOG_EVERY + self.curr) == 0) {
            CurrentTask.metadata.timestamp = self.last_time;
            heuristics.addData(CurrentTask.metadata);
        }

        const new_delta = CurrentTask.getDelta(self.avg_system_wait);
        time.setDelta(new_delta);
    }

    pub inline fn calcAvgWait(self: *Scheduler) void {
        const starve_f: f32 = @floatFromInt(self.total_system_wait);
        const now_f: f32 = @floatFromInt(self.total_system_wait);
        const len_f: f32 = @floatFromInt(self.task_count);
        self.avg_system_wait = starve_f / now_f / len_f;
    }

    pub fn register(self: *Scheduler, t: *const fn () noreturn, id: u8) void {
        const t_constructed = Task.init(t, id);
        self.tasks[self.task_count] = t_constructed;

        if (self.task_count == 0) {
            CurrentTask = &self.tasks[self.task_count];
        }

        self.task_count += 1;
    }

    pub fn start(self: *Scheduler) noreturn {
        if (self.task_count == 0) {
            logger.info("Error: No Tasks Registered!!!\r\n");
            @panic("Invalid State");
        }

        disable_irq();

        self.last_time = time.getTimeMicros();

        for (0..self.task_count) |i| {
            self.tasks[i].metadata.time_put_on_wait = self.last_time;
        }

        c.SCHEDULER_ENABLE_IT();

        // Call the start asm fn
        SchedulerStart();

        unreachable;
    }
};
