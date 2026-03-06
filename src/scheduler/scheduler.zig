//! Scheduler control for all the tasks

const task = @import("task.zig");
const time = @import("../hal/time.zig");
const Task = task.Task;
const TaskQueue = @import("fixed_buffer.zig").FixedBufferArrayList(*Task, task.MAX_TASKS);

const io = @import("io_manager.zig");
const IoManager = io.IoManager;
const IoCall = io.IoCall;

const heuristics = @import("heuristics.zig");
const logger = @import("../hal/logger.zig");

extern fn SchedulerStart() void;
extern fn ForcePreempt() void;

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
const LOG_EVERY: usize = 10;

pub const Scheduler = struct {
    task_count: usize = 0,
    tasks: [task.MAX_TASKS]Task = undefined,

    total_system_wait: usize = 0,
    avg_system_wait: f32 = 0,

    last_time: u32 = 0,
    switches: u32 = 0,

    ready_queue: TaskQueue = .{},
    io_manager: IoManager = .{},

    pub inline fn ioCall(self: *Scheduler, call: IoCall) void {
        self.io_manager.ioCall(CurrentTask, call);
        ForcePreempt();
    }

    /// Choose who goes next and allocate the proper time slice for them
    pub inline fn schedule(self: *Scheduler) void {
        const now = time.getTimeMicros();

        const delta = now - self.last_time;
        CurrentTask.metadata.run_time = delta;

        CurrentTask.metadata.time_put_on_wait = now;

        if (CurrentTask.state == .ready) {
            self.ready_queue.pushFront(CurrentTask) catch unreachable;
        }
        CurrentTask = self.ready_queue.pop().?;

        CurrentTask.metadata.ready_wait_time = time.getTimeMicros() - CurrentTask.metadata.time_put_on_wait;
        self.total_system_wait += CurrentTask.metadata.ready_wait_time;

        self.calcAvgWait();
        const new_delta = CurrentTask.getDelta(self.avg_system_wait);

        CurrentTask.metadata.timestamp = time.getTimeMicros();
        heuristics.addData(CurrentTask.metadata);

        time.setDelta(new_delta);
        self.last_time = time.getTimeMicros();
    }

    pub inline fn calcAvgWait(self: *Scheduler) void {
        const starve_f: f32 = @floatFromInt(self.total_system_wait);
        const now_f: f32 = @floatFromInt(time.getTimeMicros());
        const len_f: f32 = @floatFromInt(self.task_count);
        self.avg_system_wait = starve_f / now_f / len_f;
    }

    pub fn register(self: *Scheduler, t: *const fn () noreturn, id: u8) void {
        const t_constructed = Task.init(t, id);
        self.tasks[self.task_count] = t_constructed;
        self.tasks[self.task_count].index = self.task_count;

        self.ready_queue.pushFront(&self.tasks[self.task_count]) catch unreachable;

        self.task_count += 1;
    }

    pub fn start(self: *Scheduler) noreturn {
        if (self.task_count == 0) {
            logger.info("Error: No Tasks Registered!!!\r\n");
            @panic("Invalid State");
        }

        CurrentTask = self.ready_queue.pop().?;

        disable_irq();

        self.io_manager.ready_queue_ref = &self.ready_queue;
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
