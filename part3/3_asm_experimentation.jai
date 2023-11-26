#load "0_repetition_tester.jai";

BUFFER_SIZE :: 256*1024*1024;

main :: () {
    cpu_timer_freq := estimate_cpu_frequency(500);
    initialize_os_metrics();

    buffer := allocate_buffer(BUFFER_SIZE);

    { // loop assignment
        print("--- loop assignment ---\n");
        tester: Tester;
        new_test_wave(*tester, xx buffer.count, cpu_timer_freq, 10);

        while is_testing(*tester) {
            begin_time(*tester);
            loop(buffer.data, buffer.count);
            end_time(*tester);

            add_processed_bytes(*tester, xx buffer.count);
        }
    }
}

loop :: no_inline (buffer: *u8, buffer_count: int) #c_call {
    for 0..buffer_count-1 {
        buffer[it] = cast,no_check(u8)it;
    }
}


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




optimize :: () {
    #import "Compiler";
    print("Building optimized executable...\n");

    set_build_options_dc(.{do_output = false,});

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
