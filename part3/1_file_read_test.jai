#load "0_repetition_tester.jai";

main :: () {
    cpu_timer_freq := estimate_cpu_frequency(500);

    testfile : struct {
        name := "testfile";
        size : s64;
    };

    _, testfile.size = file_modtime_and_size(testfile.name);
    if !testfile.size {
        print("Test file '%' was not found.\n", testfile.name);
    }

    tester: Tester;
    new_test_wave(*tester, xx testfile.size, cpu_timer_freq, 10);

    while is_testing(*tester) {
        begin_time(*tester);
        file, success := read_entire_file(testfile.name);
        end_time(*tester);

        if success free(file.data);

        if success add_processed_bytes(*tester, xx file.count);
        else       error(*tester, "read_entire_file failed");
    }
}

#import "Basic";
#import "File";
#import "File_Utilities";

#run {
    #import "Compiler";

    set_build_options_dc(.{output_path = "build"});
}
