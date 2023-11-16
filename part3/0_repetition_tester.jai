#load "platform_metrics.jai";

Tester :: struct {
    cpu_timer_frequency        : u64;
    target_processed_byte_count: u64;
    try_for_time               : u64;
    tests_started_at           : u64;

    state                      : Tester_State;
    print_new_minimums         : bool;
     open_block_count          : int;
    close_block_count          : int;
    time_accumulated_this_test : u64;
    bytes_processed_this_test  : u64;

    using results: Results;

    Results :: struct {
        test_count: u64;
        total_time: u64;
          max_time: u64;
          min_time: u64;
    };
}

Tester_State :: enum {
    Uninitialized;
    Testing;
    Completed;
    Error;
}

new_test_wave :: (using tester: *Tester, _target_processed_bytes: u64, _cpu_timer_freq: u64, _seconds_to_try := 10) {
    if state == .Uninitialized {
        state = .Testing;
        target_processed_byte_count = _target_processed_bytes;
        cpu_timer_frequency         = _cpu_timer_freq;
        print_new_minimums          = true;
        results.min_time            = cast,no_check(u64)(-1);
    } else if state == .Completed {
        state = .Testing;

        if target_processed_byte_count != _target_processed_bytes  error(tester, "Processed byte count mismatch");
        if cpu_timer_frequency         != _cpu_timer_freq          error(tester, "CPU frequency changed");
    }

    try_for_time     = xx _seconds_to_try * _cpu_timer_freq;
    tests_started_at = read_cpu_timer();
}

is_testing :: (using tester: *Tester) -> bool {
    current_time := read_cpu_timer();
    if state == .Testing {
        if open_block_count {
            if bytes_processed_this_test != target_processed_byte_count {
                error(tester, tprint("processed % bytes, but expected to process %.", bytes_processed_this_test, target_processed_byte_count));
            }

            if open_block_count != close_block_count {
                error(tester, tprint("unmatched timing block open/close: opened %, closed %.", open_block_count, close_block_count));
            }

            if state == .Testing {
                elapsed_time := time_accumulated_this_test;
                test_count += 1;
                total_time += elapsed_time;
                if max_time < elapsed_time then max_time = elapsed_time;
                if min_time > elapsed_time {
                    min_time = elapsed_time;
                    tests_started_at = current_time;

                    if print_new_minimums {
                        print_time("Min", xx min_time, cpu_timer_frequency, bytes_processed_this_test);
                        print("                               \r");
                    }
                }

                open_block_count           = 0;
                close_block_count          = 0;
                time_accumulated_this_test = 0;
                bytes_processed_this_test  = 0;
            }
        }

        if (current_time - tests_started_at) > try_for_time {
            state = .Completed;

            print("                                                         \r");
            print_results(results, cpu_timer_frequency, target_processed_byte_count);
        }
    }

    return state == .Testing;
}
begin_time :: (using tester: *Tester) {
    open_block_count += 1;
    time_accumulated_this_test -= read_cpu_timer();
}
end_time :: (using tester: *Tester) {
    close_block_count += 1;
    time_accumulated_this_test += read_cpu_timer();
}

add_processed_bytes :: (using tester: *Tester, bytes: u64) {
    bytes_processed_this_test += bytes;
}

error      :: (tester: *Tester, message: string) {
    tester.state = .Error;
    log_error("[ERROR/Repetition tester] Encountered error during repetition testing: %", message);
}

print_time :: (label: string, cpu_time: float64, cpu_timer_frequency: u64, byte_count: u64) {
    print("%: %", label, cpu_time);
    if cpu_timer_frequency {
        seconds := cpu_time / cast(float64)cpu_timer_frequency;
        print(" (%ms)", 1000*seconds);

        if byte_count {
            GiB :: 1024.0 * 1024.0 * 1024.0;
            best_bandwidth := byte_count / (GiB * seconds);
            print(" %GiB/s", best_bandwidth);
        }
    }
}

print_results :: (using results: Tester.Results, cpu_timer_frequency: u64, byte_count: u64) {
    print_time("Min", xx min_time, cpu_timer_frequency, byte_count);
    print("\n");

    print_time("Max", xx max_time, cpu_timer_frequency, byte_count);
    print("\n");

    if test_count {
        print_time("Avg", cast(float64)total_time / test_count, cpu_timer_frequency, byte_count);
        print("\n");
    }
}
