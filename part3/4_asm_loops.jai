#load "0_repetition_tester.jai";

BUFFER_SIZE :: 256*1024*1024;

Loop_Routine :: #type (buffer: *u8, buffer_count: int) -> void #c_call;

main :: () {
    cpu_timer_freq := estimate_cpu_frequency(500);
    initialize_os_metrics();

    print("Estimated cpu frequency: %\n", cpu_timer_freq);

    buffer := allocate_buffer(BUFFER_SIZE);

    //exec_loop( "asm_1x3nop_loop");
    //exec_loop( "asm_3x1nop_loop");
    //exec_loop( "asm_9x1nop_loop");
    //exec_loop("asm_18x1nop_loop");

    //exec_loop("asm_empty_loop");
    //exec_loop("asm_jump_on_2_loop");
    exec_loop("asm_jump_on_hit_loop_empty");
    //exec_loop("asm_jump_on_hit_loop");
}

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


#run {
    #import "Compiler";
    set_build_options_dc(.{output_path = "build"});

    { // building asm
        Process :: #import "Process";
        asm_compile_cmd :: string.["nasm", "-g", "-f", "win64", "-o", "build\\4_asm_routines.obj", "4_asm_routines.asm"];
        result, _, _, timeout_reached := Process.run_command(..asm_compile_cmd, timeout_ms = 2000);
        if result.exit_code != 0 || timeout_reached {
            compiler_report("Unable to compile 4_asm_routines.obj, aborting...");
        }

        make_lib_cmd :: string.["lib", "-nologo", "build\\4_asm_routines.obj"];
        result, _, _, timeout_reached = Process.run_command(..make_lib_cmd, timeout_ms = 2000);
        if result.exit_code != 0 || timeout_reached {
            compiler_report("Unable to create library 4_asm_routines.lib, aborting...");
        }
    }
}

