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

    #if 0 { // read_entire_file
        print("--- read_entire_file ---\n");
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

    while true {
    { // file_read
        print("--- file_read ---\n");
        tester: Tester;
        new_test_wave(*tester, xx testfile.size, cpu_timer_freq, 10);

        buffer := alloc(testfile.size);
        assert(buffer != null);

        while is_testing(*tester) {
            file, opened := file_open(testfile.name, log_errors = true);
            if !opened {
                error(*tester, tprint("Could not open file '%'\n", testfile.name));
                break;
            }

            begin_time(*tester);
            success, bytes_read := file_read(file, buffer, testfile.size);
            end_time(*tester);

            if success && (bytes_read != testfile.size) print("Tried to read % bytes, but actually read % bytes\n", testfile.size, bytes_read);

            if success add_processed_bytes(*tester, xx bytes_read);
            else       error(*tester, "file_read failed");

            file_close(*file);
        }

        free(buffer);

    }

    { // file_read
        print("--- file_read (loop alloc) ---\n");
        tester: Tester;
        new_test_wave(*tester, xx testfile.size, cpu_timer_freq, 10);

        while is_testing(*tester) {
            buffer := alloc(testfile.size);
            assert(buffer != null);

            file, opened := file_open(testfile.name, log_errors = true);
            if !opened {
                error(*tester, tprint("Could not open file '%'\n", testfile.name));
                break;
            }

            begin_time(*tester);
            success, bytes_read := file_read(file, buffer, testfile.size);
            end_time(*tester);

            if success && (bytes_read != testfile.size) print("Tried to read % bytes, but actually read % bytes\n", testfile.size, bytes_read);

            if success add_processed_bytes(*tester, xx bytes_read);
            else       error(*tester, "file_read failed");

            file_close(*file);
            free(buffer);
        }
    }
    }
}

#import "Basic";
#import "File";
#import "File_Utilities";

#run {
    #import "Compiler";

    set_build_options_dc(.{output_path = "build"});
}
