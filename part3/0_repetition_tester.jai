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

    accumulated_this_test      : Repetition_Value;

    using results: Results;

    Results :: struct {
        total     : Repetition_Value;
          max     : Repetition_Value;
          min     : Repetition_Value;
    };
}

Repetition_Value :: union ($T := u64) {
    Type :: enum {
        Test_Count;

        CPU_Time;
        Page_Faults;
        Byte_Count;
    }

    elements : [3]T;
    struct {
        test_count  : T;
        cpu_time    : T;
        page_faults : T;
        byte_count  : T;
    }
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
        results.min.cpu_time        = cast,no_check(u64)(-1);
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
            accum := accumulated_this_test;

            if open_block_count != close_block_count {
                error(tester, tprint("unmatched timing block open/close: opened %, closed %.", open_block_count, close_block_count));
            }

            if accum.byte_count != target_processed_byte_count {
                error(tester, tprint("processed % bytes, but expected to process %.", accum.byte_count, target_processed_byte_count));
            }

            if state == .Testing {
                accum.test_count = 1;

                for *total.elements {
                    it += accum.elements[it_index];
                }

                if max.cpu_time < accum.cpu_time then max = accum;
                if min.cpu_time > accum.cpu_time {
                    min = accum;
                    tests_started_at = current_time;

                    if print_new_minimums {
                        print_time("Min", xx min, cpu_timer_frequency);
                        print("                               \r");
                    }
                }

                open_block_count      = 0;
                close_block_count     = 0;
                accumulated_this_test = .{};
            }
        }

        if (current_time - tests_started_at) > try_for_time {
            state = .Completed;

            print("                                                         \r");
            print_results(results, cpu_timer_frequency);
        }
    }

    return state == .Testing;
}
begin_time :: (using tester: *Tester) {
    open_block_count += 1;
    accumulated_this_test.cpu_time -= read_cpu_timer();
}
end_time :: (using tester: *Tester) {
    close_block_count += 1;
    accumulated_this_test.cpu_time += read_cpu_timer();
}

add_processed_bytes :: (using tester: *Tester, bytes: u64) {
    accumulated_this_test.byte_count += bytes;
}

error      :: (tester: *Tester, message: string) {
    tester.state = .Error;
    log_error("[ERROR/Repetition tester] Encountered error during repetition testing: %", message);
}

print_time :: (label: string, value_u64: Repetition_Value, cpu_timer_frequency: u64) {
    divisor : float64 = 1.0 / (cast(float64) (ifx value_u64.test_count else 1));

    v : Repetition_Value(float64);
    for *v.elements  it.* = cast(float64)value_u64.elements[it_index] * divisor;

    print("%: %", label, v.cpu_time);
    if cpu_timer_frequency {
        seconds := v.cpu_time / cast(float64)cpu_timer_frequency;
        print(" (%ms)", 1000*seconds);

        if value_u64.byte_count {
            GiB :: 1024.0 * 1024.0 * 1024.0;
            best_bandwidth := v.byte_count / (GiB * seconds);
            print(" %GiB/s", best_bandwidth);
        }
    }
}

print_results :: (using results: Tester.Results, cpu_timer_frequency: u64) {
    print_time("Min", min, cpu_timer_frequency);
    print("\n");

    print_time("Max", max, cpu_timer_frequency);
    print("\n");

    if total.test_count {
        print_time("Avg", total, cpu_timer_frequency);
        print("\n");
    }
}
