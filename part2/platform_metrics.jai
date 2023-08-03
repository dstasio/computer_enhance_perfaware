// Profiling

#scope_file

          MAX_PROFILER_HOOKS :: 64;
#no_reset CURRENT_HOOK_INDEX :=  0; // index 0 is reserved

profiler_hooks     : [MAX_PROFILER_HOOKS]Profiler_Hook;
profiling_start    : u64;
profiler_open_hook : int;


#scope_export

Profiler_Hook :: struct {
    name              : string;
    duration          : u64;
    parent_hook_index : int;
    _start_time       : u64;
};

time_function :: inline () #expand {
    print("timing\n");
    hook_index := #run new_hook_index();
    print("op: %, i: %\n", profiler_open_hook, hook_index);
    assert(profiler_open_hook != hook_index);

    using hook := *profiler_hooks[hook_index];
    if !name {
        name = copy_string(context.stack_trace.info.name);
    }
    parent_hook_index  = profiler_open_hook;
    profiler_open_hook = hook_index;

    _start_time = read_cpu_timer();

    `defer {
        end_time := read_cpu_timer();

        duration += end_time - _start_time;

        if parent_hook_index {
            profiler_open_hook = parent_hook_index;

            profiler_hooks[parent_hook_index].duration -= duration;
        }
    };
}

time_block :: inline (name_: string) #expand {
    hook_index := #run new_hook_index();
    assert(profiler_open_hook != hook_index);

    using hook := *profiler_hooks[hook_index];
    if !name {
        name = copy_string(name_);
    }
    parent_hook_index  = profiler_open_hook;
    profiler_open_hook = hook_index;

    _start_time = read_cpu_timer();

    `defer {
        end_time := read_cpu_timer();

        duration += end_time - _start_time;

        if parent_hook_index {
            profiler_open_hook = parent_hook_index;

            profiler_hooks[parent_hook_index].duration -= duration;
        }
    };
}

time_block_start :: inline (name_: string) #expand {
    hook_index := #run new_hook_index();

    profiler_open_hook = hook_index;

    using hook := *profiler_hooks[hook_index];

    if !name then name = copy_string(name_);
    _start_time = read_cpu_timer();

}

time_block_end :: inline (name_: string) #expand {
    end_time := read_cpu_timer();

    using hook := *profiler_hooks[profiler_open_hook];

    assert(name == name_);

    print("dur bef: %\n", duration);
    duration += end_time - _start_time;
    print("dur aft: %\n", duration);

    if parent_hook_index {
        profiler_open_hook = parent_hook_index;

        profiler_hooks[parent_hook_index].duration -= duration;
    }
}

start_profiling :: inline () {
    profiling_start = read_cpu_timer();
}

end_and_report_profiling :: inline (cpu_frequency: u64) {
    assert(profiling_start != 0);

    end            := read_cpu_timer();
    total_duration := cast(float64)(end - profiling_start);

    print("\nTotal Time: %ms\n", FormatFloat.{value = 1000.0 * total_duration / cast(float64)cpu_frequency, trailing_width = 2});

    for profiler_hooks {
        if it_index > CURRENT_HOOK_INDEX break;

        percentage := 100.0 * cast(float64)it.duration / total_duration;
        print("%: % (%0%%)\n", it_index, it, FormatFloat.{value = percentage, trailing_width = 2});
    }
}

// OS

#if OS == .WINDOWS {

#import "Windows";

os_timer_frequency :: () -> s64 {
    frequency: s64 = ---;
    QueryPerformanceFrequency(*frequency);
    return frequency;
}

read_os_timer :: () -> s64 {
    value: s64 = ---;
    QueryPerformanceCounter(*value);
    return value;
}

}
else {

#import "POSIX";

os_timer_frequency :: () -> s64 #expand {
    return 1000000;
}

read_os_timer :: () -> s64 {
    value: timeval = ---;
    gettimeofday(*value, null);
    
    result := os_timer_frequency() * value.tv_sec + value.tv_usec;
    return result;
}

}

read_cpu_timer :: inline () -> u64 {
    return rdtsc();
}

estimate_cpu_frequency :: (milliseconds_to_wait: u64) -> cpu_freq: u64, was_able_to_estimate: bool {
    os_freq := os_timer_frequency();

    cpu_start    : s64 = xx read_cpu_timer();
    os_start     : s64 = read_os_timer();
    os_end       : s64 = 0;
    os_elapsed   : s64 = 0;
    os_wait_time : s64 = xx (cast(float)os_freq * (milliseconds_to_wait / 1000.0));
    while os_elapsed < os_wait_time {
        os_end     = read_os_timer();
        os_elapsed = os_end - os_start;
    }
    
    cpu_end     : s64 = xx read_cpu_timer();
    cpu_elapsed : s64 = cpu_end - cpu_start;
    cpu_freq    : u64 = 0;
    if os_elapsed {
        cpu_freq = xx (os_freq * cpu_elapsed / os_elapsed);
        return cpu_freq, true;
    }
    
    return 0, was_able_to_estimate = false;
}

#scope_file

new_hook_index :: () -> int #expand {
    CURRENT_HOOK_INDEX += 1;
    assert(CURRENT_HOOK_INDEX < MAX_PROFILER_HOOKS);
    return CURRENT_HOOK_INDEX;
}

#import "Machine_X64";
