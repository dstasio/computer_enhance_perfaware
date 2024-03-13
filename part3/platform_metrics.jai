// Profiling
//#module_parameters(DUMMY := false);
DUMMY :: false;

start_profiling :: inline () {
    profiling_start = read_cpu_timer();
}

// TODO: compute the cpu_frequency automatically
end_and_report_profiling :: inline (cpu_frequency: u64) {
    assert(profiling_start != 0);

    end            := read_cpu_timer();
    total_duration := cast(float64)(end - profiling_start);

    print_time := total_duration / cast(float64)cpu_frequency;
    time_unit  := "ms";
    if print_time < 1 then print_time *= 1000;
    else                 { time_unit.data += 1; time_unit.count -= 1; }

    print("\nTotal Time: %0%0\n", FormatFloat.{value = print_time, trailing_width = 2}, time_unit);

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

        if it.byte_count {
            data_unit := "B";
            data_amount := cast(float64) it.byte_count;
            if data_amount > 1024 { data_amount /= 1024; data_unit = "KiB"; }
            if data_amount > 1024 { data_amount /= 1024; data_unit = "MiB"; }
            if data_amount > 1024 { data_amount /= 1024; data_unit = "GiB"; }

            MiB :: 1024 * 1024;
            GiB :: 1024 * MiB;
            duration_seconds := cast(float64)it.duration_inclusive / cpu_frequency;
            speed := cast(float64)it.byte_count / duration_seconds;
            speed /= GiB;
            print(" --- %0%0 (%0 GiB/s)", FormatFloat.{value = data_amount, trailing_width = 3}, data_unit, speed);
        }

        print("\n");
    }
}

#if DUMMY {
time_function    :: ()            #expand {}
time_block       :: (args: ..Any) #expand {}
time_block_start :: (args: ..Any) #expand {}
time_block_end   :: (args: ..Any) #expand {}
} else {

time_function :: inline () #expand {
    time_block_start(#procedure_name());
    `defer time_block_end(#procedure_name());
}

time_block :: inline ($NAME: string, bytes := 0) #expand {
    time_block_start(NAME, bytes);
    `defer time_block_end(NAME);
}

time_block_start :: inline ($NAME: string, bytes := 0) #expand {
    hook_index := #run new_hook_index();

    using hook := *profiler_hooks[hook_index];
    MARK_NAME :: #run tprint("`_profiling_%_mark", remove_whitespace(NAME));

    byte_count += bytes;

    #insert #run tprint("% : Profiler_Mark;\n", MARK_NAME);
    #insert #run tprint("mark := *%;\n", MARK_NAME);
    mark.parent_hook_index      = profiler_open_hook;
    mark.old_duration_inclusive = duration_inclusive;

    profiler_open_hook = hook_index;

    // @robustness: this will only work for constant strings.
    if !name then name = NAME;

    mark.start_time = read_cpu_timer();
}

time_block_end :: inline ($NAME: string, bytes := 0) #expand {
    end_time := read_cpu_timer();

    using hook := *profiler_hooks[profiler_open_hook];
    assert(name == NAME);

    byte_count += bytes;

    MARK_NAME :: #run tprint("`_profiling_%_mark", remove_whitespace(NAME));
    #insert #run tprint("mark := *%;\n", MARK_NAME);

    elapsed            := end_time - mark.start_time;
    duration_exclusive += elapsed;
    duration_inclusive  = mark.old_duration_inclusive + elapsed;
    profiler_hooks[mark.parent_hook_index].duration_exclusive -= elapsed;

    profiler_open_hook = mark.parent_hook_index;
}
} // DUMMY == false

// OS

#if OS == .WINDOWS {

#import "Windows";

initialize_os_metrics :: () {
    using metrics_data;
    if initialized return;

    initialized = true;
    process_handle = OpenProcess(PROCESS_QUERY_INFORMATION | PROCESS_VM_READ, 0, GetCurrentProcessId());
}

read_os_page_fault_count :: () -> u64 {
    assert(metrics_data.initialized);

    counters : PROCESS_MEMORY_COUNTERS_EX;
    counters.cb = size_of(PROCESS_MEMORY_COUNTERS_EX);
    success := GetProcessMemoryInfo(metrics_data.process_handle, *counters, counters.cb);

    return counters.PageFaultCount;
}

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

Metrics_Data :: struct {
    initialized    : bool;
    process_handle : HANDLE;
}

// OS API
kernel32 :: #system_library "kernel32";
psapi    :: #system_library "psapi";
OpenProcess                :: (dwDesiredAccess: DWORD, bInheritHandle: BOOL, dwProcessId: DWORD)        -> HANDLE #foreign kernel32;
GetProcessMemoryInfo       :: (Process: HANDLE, ppsmemCounters: *PROCESS_MEMORY_COUNTERS_EX, cb: DWORD) -> BOOL   #foreign psapi;
PROCESS_MEMORY_COUNTERS_EX :: struct {
    cb                         : DWORD;
    PageFaultCount             : DWORD ;
    PeakWorkingSetSize         : SIZE_T;
    WorkingSetSize             : SIZE_T;
    QuotaPeakPagedPoolUsage    : SIZE_T;
    QuotaPagedPoolUsage        : SIZE_T;
    QuotaPeakNonPagedPoolUsage : SIZE_T;
    QuotaNonPagedPoolUsage     : SIZE_T;
    PagefileUsage              : SIZE_T;
    PeakPagefileUsage          : SIZE_T;
    PrivateUsage               : SIZE_T;
}
PROCESS_QUERY_INFORMATION  : DWORD : 0x0400;
PROCESS_VM_READ            : DWORD : 0x0010;

} else { // OS != .WINDOWS

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

} // End of OS-related functions

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

//
// Internal Data
//
metrics_data: Metrics_Data;

          MAX_PROFILER_HOOKS :: 64;
#no_reset CURRENT_HOOK_INDEX :=  0; // index 0 is reserved

profiler_hooks     : [MAX_PROFILER_HOOKS]Profiler_Hook;
profiling_start    : u64;
profiler_open_hook : int;

Profiler_Hook :: struct {
    name              : string;

    duration_exclusive : u64; // without children
    duration_inclusive : u64; // with    children

    byte_count         : int;
    // TODO: fill this
    run_count          : int;
};

Profiler_Mark :: struct {
    parent_hook_index      : int;
    old_duration_inclusive : u64;
    start_time             : u64;
}

remove_whitespace :: (str: string) -> string {
    adjusted: string;
    adjusted.count = str.count;
    adjusted.data  = alloc(adjusted.count,, allocator = temp);

    for 0..(str.count - 1) {
        adjusted[it] = ifx str[it] != #char " " else #char "_";
    }
    return adjusted;
}

#import "Machine_X64";
