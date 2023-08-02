#load "platform_metrics.jai";

main :: () {
    args := get_command_line_arguments();

    milliseconds_to_wait := 1000;
    if args.count > 1 {
        milliseconds_to_wait = string_to_int(args[1]);
    }

    os_freq : u64 = os_timer_frequency();
    print("    OS Freq: % (reported)\n", os_freq);

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
    }
    
    print("   OS Timer: % -> % = % elapsed\n", os_start, os_end, os_elapsed);
    print(" OS Seconds: %\n", cast(float64)os_elapsed/cast(float64)os_freq);
    
    print("  CPU Timer: % -> % = % elapsed\n", cpu_start, cpu_end, cpu_elapsed);
    print("   CPU Freq: % (guessed)\n", cpu_freq);
}

#import "Command_Line";
#import "Basic";
