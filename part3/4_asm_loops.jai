// Compiler Version 0.1.090

#load "0_repetition_tester.jai";

KiB :: inline (b: int) -> int { return 1024 *     b ; }
MiB :: inline (b: int) -> int { return 1024 * KiB(b); }
GiB :: inline (b: int) -> int { return 1024 * MiB(b); }

Loop_Routine :: #type (buffer: *u8, buffer_count: int) -> void #c_call;

main :: () {
    cpu_timer_freq := estimate_cpu_frequency(500);
    initialize_os_metrics();

    print("Estimated cpu frequency: %\n", cpu_timer_freq);

    //execution_tests(cpu_timer_freq);

    //cache_tests_power_of_2(cpu_timer_freq);
    cache_tests_any(cpu_timer_freq, 64);
}

cache_tests_any :: (cpu_timer_freq : u64, $SAMPLE_COUNT : int) {
    buffer := allocate_buffer(GiB(1));

    MAX :: cast,no_check(u64)(-1);

    exec_loop :: (exec_index: int, block_size: int, repeat_count: int, $proc: string = "read_repeated_memory_block_32x8") -> Tester.Results #expand {
        #insert #run tprint("% :: (buffer: *u8, block_size: u64, repeat_count: int) -> void #foreign asm_routines", proc);

        size_f := cast(float64) block_size;
        unit := "B";

             if block_size >= GiB(1) { size_f /= GiB(1); unit = "GiB"; }
        else if block_size >= MiB(1) { size_f /= MiB(1); unit = "MiB"; }
        else if block_size >= KiB(1) { size_f /= KiB(1); unit = "KiB"; }

        print("\n--- %: Reading % % x% ---\n", exec_index, size_f, unit, repeat_count);
        tester: Tester;

        real_tested_bytes : u64 = xx (block_size * repeat_count);
        new_test_wave(*tester, real_tested_bytes, `cpu_timer_freq, 5);

        while is_testing(*tester) {
            begin_time(*tester);
            #insert #run tprint("%(`buffer.data, xx block_size, repeat_count);", proc);
            end_time(*tester);

            add_processed_bytes(*tester, real_tested_bytes);
        }

        return tester.results;
    }

    Sample :: struct {
        block_size: int;
        speed: float64;
    };

    samples: [..]Sample;
    array_reserve(*samples, SAMPLE_COUNT);

    // 2^10 - 2^26

    for total_sample_index: 0..SAMPLE_COUNT-1 {
        using sample : Sample;

        if samples.count == {
            case 0; block_size = 1 << 10;
            case 1; block_size = 1 << 26;
            case; {
                max_delta : float64 = 0;
                max_delta_index : int;
                for 1..(samples.count - 1) {
                    a := samples[it].speed;
                    b := samples[it - 1].speed;
                    delta := abs(b - a);

                    if delta < (0.1 * a) continue;
                    if delta > max_delta {
                        max_delta = delta;
                        max_delta_index = it;
                    }
                }
                assert(max_delta_index > 0);

                block_size = (samples[max_delta_index].block_size + samples[max_delta_index - 1].block_size) / 2;
            }
        }

        print("delta: %\n", buffer.count);
        result := exec_loop(total_sample_index, block_size, buffer.count / block_size).min;

        duration_seconds := cast(float64)result.cpu_time / cpu_timer_freq;
        speed  = cast(float64)result.byte_count / duration_seconds;
        speed /= cast(float64)GiB(1);

        if samples.count < 2 then array_add(*samples, sample);
        else {
            for 0..(samples.count - 1) {
                if samples[it].block_size > block_size {
                    array_insert_at(*samples, sample, it);
                    break;
                }
            }
        }
    }

    csv_builder : String_Builder;
    append(*csv_builder, "Region Size;GiB/s\n");

    for sample: samples {
        using sample;
        append(*csv_builder, tprint("%;%\n", block_size, speed));
        reset_temporary_storage();
    }

    print("\n\n");
    csv := builder_to_string(*csv_builder);
    write_entire_file("samples.csv", csv);

    if samples.count <= 80 then print(csv);
    print("\n");
}

cache_tests_power_of_2 :: (cpu_timer_freq : u64) {
    buffer := allocate_buffer(GiB(1));

    MAX :: cast,no_check(u64)(-1);

    exec_loop :: (mask: u64, $proc: string = "read_memory_32x8") -> Tester.Results #expand {
        #insert #run tprint("% :: (buffer: *u8, buffer_count: int, subaddress_mask: u64) -> void #foreign asm_routines", proc);

        size : int = ifx mask > cast(u64)buffer.count then buffer.count else xx (mask + 1);
        size_f := cast(float64) size;
        unit := "B";

             if size >= GiB(1) { size_f /= GiB(1); unit = "GiB"; }
        else if size >= MiB(1) { size_f /= MiB(1); unit = "MiB"; }
        else if size >= KiB(1) { size_f /= KiB(1); unit = "KiB"; }

        print("\n--- Reading % % ---\n", size_f, unit);
        tester: Tester;
        new_test_wave(*tester, xx `buffer.count, `cpu_timer_freq, 10);

        while is_testing(*tester) {
            begin_time(*tester);
            #insert #run tprint("%(`buffer.data, `buffer.count, mask);", proc);
            end_time(*tester);

            add_processed_bytes(*tester, xx `buffer.count);
        }

        return tester.results;
    }

    csv_builder : String_Builder;
    append(*csv_builder, "Region Size;GiB/s\n");

    mask_bit_index := 10;
    for 0..29 {
        mask : u64 = xx ((1 << mask_bit_index) - 1);
        result := exec_loop(mask).min;
        mask_bit_index += 1;

        duration_seconds := cast(float64)result.cpu_time / cpu_timer_freq;
        speed := cast(float64)result.byte_count / duration_seconds;
        speed /= cast(float64)GiB(1);

        append(*csv_builder, tprint("%;%\n", mask + 1, speed));
        reset_temporary_storage();

        if (mask + 1) >= xx buffer.count break;
    }

    print("\n\n");
    print(builder_to_string(*csv_builder));
    print("\n");
}

execution_tests :: (cpu_timer_freq : u64) {
    exec_loop :: ($proc: string) #expand {
        #insert #run tprint("% :: (buffer: *u8, buffer_count: int) -> void #foreign asm_routines", proc);

        print("\n--- % ---\n", proc);
        tester: Tester;
        new_test_wave(*tester, xx `buffer.count, `cpu_timer_freq, 10);

        while is_testing(*tester) {
            begin_time(*tester);
            #insert #run tprint("%(`buffer.data, `buffer.count);", proc);
            end_time(*tester);

            add_processed_bytes(*tester, xx `buffer.count);
        }
    }

    buffer := allocate_buffer(MiB(256));

    #if 0 {
        exec_loop( "asm_1x3nop_loop");
        exec_loop( "asm_3x1nop_loop");
        exec_loop( "asm_9x1nop_loop");
        exec_loop("asm_18x1nop_loop");
    }

    #if 0 {
        exec_loop("asm_jump_always_loop");
        exec_loop("asm_jump_mod2_loop");
        exec_loop("asm_jump_mod3_loop");
        exec_loop("asm_jump_mod16_loop");
    }

    #if 0 {
        exec_loop("asm_64_aligned_loop");
        exec_loop("asm_3_aligned_loop");
        exec_loop("asm_15_aligned_loop");
        exec_loop("asm_63_aligned_loop");
    }

    #if 0 {
        exec_loop("read_x1");
        exec_loop("read_x2");
        exec_loop("read_x3");
        exec_loop("read_x4");
    }

    #if 1 {
        //exec_loop("read_simd_4x2");
        //exec_loop("read_simd_8x2");
        //exec_loop("read_simd_16x2");
        exec_loop("read_simd_32x2");
    }

    #if 0 {
        exec_loop("write_x1");
        exec_loop("write_x2");
        exec_loop("write_x3");
        exec_loop("write_x4");
    }

    #if 0 {
        exec_loop("read_1x2");
        exec_loop("read_8x2");
    }
}

#scope_file


asm_routines :: #library,no_dll "build/4_asm_routines";

allocate_buffer :: (size: int) -> []u8 {
    buffer: []u8;
    buffer.count = size;

    #if OS == .WINDOWS {
        Windows :: #import "Windows";

        buffer.data  = Windows.VirtualAlloc(xx 0, xx buffer.count, Windows.MEM_RESERVE|Windows.MEM_COMMIT, Windows.PAGE_READWRITE);
    }

    assert(buffer.data != null);
    return buffer;
}

#import "Basic";
#import "Math"; // for abs()
#import "File";


#run {
    #import "Compiler";
    set_build_options_dc(.{output_path = "build"});

    { // building asm
        Process :: #import "Process";
        asm_compile_cmd :: string.["nasm", "-g", "-f", "win64", "-o", "build\\4_asm_routines.obj", "4_asm_routines.asm"];
        result, _, _, timeout_reached := Process.run_command(..asm_compile_cmd, timeout_ms = 2000, capture_and_return_output = true, print_captured_output = true);
        if result.exit_code != 0 || timeout_reached {
            compiler_report("Unable to compile 4_asm_routines.obj, aborting...");
        }

        make_lib_cmd :: string.["lib", "-nologo", "build\\4_asm_routines.obj"];
        result, _, _, timeout_reached = Process.run_command(..make_lib_cmd, timeout_ms = 2000, capture_and_return_output = true, print_captured_output = true);
        if result.exit_code != 0 || timeout_reached {
            compiler_report("Unable to create library 4_asm_routines.lib, aborting...");
        }
    }
}

