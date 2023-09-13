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

    duration_exclusive     : u64;
    duration_inclusive     : u64;
    //duration_with_children : u64;
    //parent_hook_index : int;
    //_start_time       : u64;
};

time_function :: inline () #expand {
    hook_index := #run new_hook_index();

    using hook := *profiler_hooks[hook_index];
    `_function_profiling_parent_hook_index := profiler_open_hook;
    old_duration_inclusive := duration_inclusive;
    profiler_open_hook = hook_index;

    `__function_profiling_start_time := read_cpu_timer();

    `defer {
        end_time           := read_cpu_timer();
        elapsed            := (end_time - `__function_profiling_start_time);
        duration_exclusive += elapsed;
        duration_inclusive  = old_duration_inclusive + elapsed;
        if `_function_profiling_parent_hook_index {
            profiler_hooks[`_function_profiling_parent_hook_index].duration_exclusive -= elapsed;
        }

        if !name then name = #procedure_name();


        profiler_open_hook = `_function_profiling_parent_hook_index;
    };
}

time_block :: inline ($__profiling_block_name__: string) #expand {
    hook_index := #run new_hook_index();

    using hook := *profiler_hooks[hook_index];
    `__block_profiling_parent_hook_index := profiler_open_hook;
    profiler_open_hook = hook_index;

    // nocheckin @todo: use name here too
    `__block_profiling_start_time := read_cpu_timer();

    `defer {
        end_time           := read_cpu_timer();
        duration_exclusive += xx (end_time - `__block_profiling_start_time);

        // @robustness: this will only work for constant strings.
        if !name then name = __profiling_block_name__;
        
        // TODO: duration as root

        profiler_open_hook = `__block_profiling_parent_hook_index;
        if `__block_profiling_parent_hook_index {
            profiler_hooks[`__block_profiling_parent_hook_index].duration_exclusive -= duration_exclusive;
        }
    };
}

time_block_start :: inline ($__profiling_block_name__: string) #expand {
    hook_index := #run new_hook_index();

    #insert #run tprint("`__block_profiling_%_parent_hook := profiler_open_hook;", __profiling_block_name__);
    profiler_open_hook = hook_index;

    using hook := *profiler_hooks[hook_index];

    // @robustness: this will only work for constant strings.
    if !name then name = __profiling_block_name__;

    #insert #run tprint("`__block_profiling_%_start_time := read_cpu_timer();", __profiling_block_name__);
}

time_block_end :: inline ($__profiling_block_name__: string) #expand {
    end_time := read_cpu_timer();

    using hook := *profiler_hooks[profiler_open_hook];

    assert(name == __profiling_block_name__);

    duration_exclusive += #insert #run tprint("xx (end_time - `__block_profiling_%_start_time);", __profiling_block_name__);

    // TODO: duration as root

    parent_hook_index := #insert #run tprint("`__block_profiling_%_parent_hook;", __profiling_block_name__);
    profiler_open_hook = xx parent_hook_index;
    if parent_hook_index {
        profiler_hooks[parent_hook_index].duration_exclusive -= duration_exclusive;
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
        if it_index == 0                 continue;
        if it_index > CURRENT_HOOK_INDEX break;

        percentage         := 100.0 * cast(float64)it.duration_exclusive / total_duration;
        as_root_percentage := 100.0 * cast(float64)it.duration_inclusive / total_duration;
        print("%: % -> % (%0%%)",
              it_index, it.name,
              it.duration_exclusive, FormatFloat.{value = percentage, trailing_width = 2});

        if it.duration_inclusive != it.duration_exclusive
            print(" | w/children % (%0%%)", it.duration_inclusive, FormatFloat.{value = as_root_percentage, trailing_width = 2});
        print("\n");
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
    // @note: name cannot be copied at compile-time because #procedure_name() only works
    //        at runtime.
    CURRENT_HOOK_INDEX += 1;
    assert(CURRENT_HOOK_INDEX < MAX_PROFILER_HOOKS);

    return CURRENT_HOOK_INDEX;
}

#import "Machine_X64";
