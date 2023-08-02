#load "platform_metrics.jai";

main :: () {
    os_freq := os_timer_frequency();
    print("    OS Freq: %\n", os_freq);

    os_start   := read_os_timer();
    os_end     : u64;
    os_elapsed : u64;
    while(os_elapsed < os_freq)
    {
        os_end = read_os_timer();
        os_elapsed = os_end - os_start;
    }
    
    print("   OS Timer: % -> % = % elapsed\n", os_start, os_end, os_elapsed);
    print(" OS Seconds: %\n", cast(float64)os_elapsed/cast(float64)os_freq);
}

#import "Basic";
