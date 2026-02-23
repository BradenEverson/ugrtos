.syntax unified
.cpu cortex-m4
.fpu softvfp
.thumb

.global SchedulerStart
.global TIM2_IRQHandler

.extern CurrentTask
.extern ScheduleNext
.extern ClearTimerITFlag

.section .text.SchedulerStart
.type SchedulerStart, %function
SchedulerStart:
    cpsid I              // disable interrupts
    ldr r0, =CurrentTask // load current task ptr ptr
    ldr r1, [r0]         // load current task ptr
    ldr sp, [r1]         // load field 1 of current task, SP

    pop {r4-r11}         // load regs 4-11
    pop {r0-r3}          // load regs 0-3
    pop {r12}            // load temp reg
    pop {lr}             // load lr (discard)
    pop {lr}             // load pc to lr
    pop {r1}             // discard the thumb bit psr
    cpsie I              // enable interrupts
    bx lr

.section .text.TIM2_IRQHandler
.type TIM2_IRQHandler, %function
TIM2_IRQHandler:
    cpsid I              // disable interrupts
    push {r4-r11}
    ldr r0, =CurrentTask // load current task ptr ptr
    ldr r1, [r0]         // load current task ptr
    str sp, [r1]         // store the new sp

    push {r0, lr}        // Save r0, lr
    bl ClearTimerITFlag  // clear the timer IT flag
    bl ScheduleNext      // schedule the next task
    pop {r0, lr}         // restore regs

    ldr r0, =CurrentTask // load current task ptr ptr
    ldr r1, [r0]         // new CurrentTask
    ldr sp, [r1]         // deref the stack pointer

    pop {r4-r11}         // restore registers
    cpsie I              // enable interrupts again
    bx lr                // go back to lr
