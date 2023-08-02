// Profiling

#add_context profilings : (string, u64);
#add_context profiling_start : u64;

time_function :: inline () #expand {
    name       := copy_string(context.stack_trace.info.name);
    start_time := read_cpu_timer();

    `defer {
        end_time := read_cpu_timer();
        duration := end_time - start_time;

        elem, new := find_or_add(*context.profilings, name);

        if new then elem.* = 0;
        elem.* += duration;
    };
}

time_block :: inline (name: string) #expand {
    start_time := read_cpu_timer();

    `defer {
        end_time := read_cpu_timer();
        duration := end_time - start_time;

        elem, new := find_or_add(*context.profilings, copy_string(name));

        if new then elem.* = 0;
        elem.* += duration;
    };
}

start_profiling :: inline () {
    context.profiling_start = read_cpu_timer();
}

end_and_report_profiling :: inline (cpu_frequency: u64) {
    assert(context.profiling_start != 0);

    end            := read_cpu_timer();
    total_duration := cast(float64)(end - context.profiling_start);

    print("\nTotal Time: %ms\n", FormatFloat.{value = 1000.0 * total_duration / cast(float64)cpu_frequency, trailing_width = 2});

    for context.profilings {
        percentage := 100.0 * cast(float64)it / total_duration;
        print("%: % (%0%%)\n", it_index, it, FormatFloat.{value = percentage, trailing_width = 2});
    }
}

// OS

#if OS == .WINDOWS {

#import "Windows";

os_timer_frequency :: () -> u64 {
    frequency: LARGE_INTEGER = ---;
    QueryPerformanceFrequency(*frequency);
    return frequency.QuadPart;
}

read_os_timer :: () -> u64 {
    value: LARGE_INTEGER = ---;
    QueryPerformanceCounter(*value);
    return value.QuadPart;
}

}
else {

#import "POSIX";

os_timer_frequency :: () -> u64 #expand {
    return 1000000;
}

read_os_timer :: () -> u64 {
    value: timeval = ---;
    gettimeofday(*value, null);
    
    result := os_timer_frequency() * cast(u64)value.tv_sec + cast(u64)value.tv_usec;
    return result;
}

}

read_cpu_timer :: inline () -> u64 {
    return rdtsc();
}

estimate_cpu_frequency :: (milliseconds_to_wait: u64) -> cpu_freq: u64, was_able_to_estimate: bool {
    os_freq : u64 = os_timer_frequency();

    cpu_start    : u64 = read_cpu_timer();
    os_start     : u64 = read_os_timer();
    os_end       : u64 = 0;
    os_elapsed   : u64 = 0;
    os_wait_time : u64 = xx (cast(float)os_freq * (milliseconds_to_wait / 1000.0));
    while os_elapsed < os_wait_time {
        os_end     = read_os_timer();
        os_elapsed = os_end - os_start;
    }
    
    cpu_end     : u64 = read_cpu_timer();
    cpu_elapsed : u64 = cpu_end - cpu_start;
    cpu_freq    : u64 = 0;
    if os_elapsed {
        cpu_freq = os_freq * cpu_elapsed / os_elapsed;
        return cpu_freq, true;
    }
    
    return 0, was_able_to_estimate = false;
}

#import "Machine_X64";
#import "Hash_Table";
