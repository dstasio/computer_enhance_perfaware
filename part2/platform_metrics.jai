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

/* NOTE(casey): This does not need to be "inline", it could just be "static"
   because compilers will inline it anyway. But compilers will warn about 
   static functions that aren't used. So "inline" is just the simplest way 
   to tell them to stop complaining about that. */
read_cpu_timer :: () -> u64 #expand {
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
