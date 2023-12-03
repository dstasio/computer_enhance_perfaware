#load "0_repetition_tester.jai";

BUFFER_SIZE :: 256*1024*1024;

main :: () {
    cpu_timer_freq := estimate_cpu_frequency(500);
    initialize_os_metrics();

    buffer := allocate_buffer(BUFFER_SIZE);

    { // loop assignment
        print("\n--- loop assignment ---\n");
        tester: Tester;
        new_test_wave(*tester, xx buffer.count, cpu_timer_freq, 10);

        while is_testing(*tester) {
            begin_time(*tester);
            loop(buffer.data, buffer.count);
            end_time(*tester);

            add_processed_bytes(*tester, xx buffer.count);
        }
    }

    { // asm_mov_all_bytes
        print("\n--- asm loop mov_all_bytes ---\n");
        tester: Tester;
        new_test_wave(*tester, xx buffer.count, cpu_timer_freq, 10);

        while is_testing(*tester) {
            begin_time(*tester);
            loop_asm_mov_all_bytes(buffer.data, buffer.count);
            end_time(*tester);

            add_processed_bytes(*tester, xx buffer.count);
        }
    }

    { // asm_nop_all_bytes
        print("\n--- asm loop nop_all_bytes ---\n");
        tester: Tester;
        new_test_wave(*tester, xx buffer.count, cpu_timer_freq, 10);

        while is_testing(*tester) {
            begin_time(*tester);
            loop_asm_nop_all_bytes(buffer.data, buffer.count);
            end_time(*tester);

            add_processed_bytes(*tester, xx buffer.count);
        }
    }

    { // asm_cmp_all_bytes
        print("\n--- asm loop cmp_all_bytes ---\n");
        tester: Tester;
        new_test_wave(*tester, xx buffer.count, cpu_timer_freq, 10);

        while is_testing(*tester) {
            begin_time(*tester);
            loop_asm_cmp_all_bytes(buffer.data, buffer.count);
            end_time(*tester);

            add_processed_bytes(*tester, xx buffer.count);
        }
    }

    { // asm_dec_all_bytes
        print("\n--- asm loop dec_all_bytes ---\n");
        tester: Tester;
        new_test_wave(*tester, xx buffer.count, cpu_timer_freq, 10);

        while is_testing(*tester) {
            begin_time(*tester);
            loop_asm_dec_all_bytes(buffer.data, buffer.count);
            end_time(*tester);

            add_processed_bytes(*tester, xx buffer.count);
        }
    }
}


#scope_file

loop :: no_inline (buffer: *u8, buffer_count: int) #c_call {
    for 0..buffer_count-1 {
        buffer[it] = cast,no_check(u8)it;
    }
}

loop_asm_mov_all_bytes :: (buffer: *u8, buffer_count: int) -> void #foreign asm_routines "asm_mov_all_bytes";
loop_asm_nop_all_bytes :: (buffer: *u8, buffer_count: int) -> void #foreign asm_routines "asm_nop_all_bytes";
loop_asm_cmp_all_bytes :: (buffer: *u8, buffer_count: int) -> void #foreign asm_routines "asm_cmp_all_bytes";
loop_asm_dec_all_bytes :: (buffer: *u8, buffer_count: int) -> void #foreign asm_routines "asm_dec_all_bytes";

asm_routines :: #library,no_dll "build/3_asm_routines";

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



#scope_export
optimize :: () {
    #import "Compiler";
    print("Building optimized executable...\n");

    set_build_options_dc(.{do_output = false,});

    { // building asm
        Process :: #import "Process";
        asm_compile_cmd :: string.["nasm", "-g", "-f", "win64", "-o", "build\\3_asm_routines.obj", "3_asm_routines.asm"];
        result, _, _, timeout_reached := Process.run_command(..asm_compile_cmd, timeout_ms = 2000);
        if result.exit_code != 0 || timeout_reached {
            compiler_report("Unable to compile 3_asm_routines.obj, aborting...");
        }

        make_lib_cmd :: string.["lib", "build\\3_asm_routines.obj"];
        result, _, _, timeout_reached = Process.run_command(..make_lib_cmd, timeout_ms = 2000);
        if result.exit_code != 0 || timeout_reached {
            compiler_report("Unable to create library 3_asm_routines.lib, aborting...");
        }
    }

    options := get_build_options();
    options.output_path            = "build";
    options.output_executable_name = "3_asm_experimentation_optimized";
    options.output_type            = .EXECUTABLE;

    set_optimization(*options, .OPTIMIZED_SMALL, true);

    w := compiler_create_workspace();
    set_build_options(options, w);
    add_build_file(#file, w);
}

#run {
    #import "Compiler";
    set_build_options_dc(.{output_path = "build"});
}
