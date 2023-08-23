#load "haversine.jai";
#load "platform_metrics.jai";

#run {
    #import "Compiler";

    set_build_options_dc(.{output_path = "build"});
}


Arguments :: struct {
    name  : string;
}

Pair :: struct {
    x0 : float64;
    y0 : float64;

    x1 : float64;
    y1 : float64;
}

parse_json :: (file: *[]u8) -> Bucket_Array(Pair, 1000) {
    time_function();

    end    := file.data + file.count;
    cursor := file.data;

    advance :: () -> bool #expand {
        `cursor += 1;
        return `cursor < `end;
    }

    allpairs : Bucket_Array(Pair, 1000);

    newpair : Pair;

    time_block_start("loop");
    while cursor < end {
        container: *float64;
        push_pair := false;

        if cursor.* == #char "x" {
            if !advance() break;
                 if cursor.* == #char "0" container = *newpair.x0;
            else if cursor.* == #char "1" container = *newpair.x1;
        }
        else if cursor.* == #char "y" {
            if !advance() break;
                 if cursor.* == #char "0"   container = *newpair.y0;
                 else if cursor.* == #char "1" { container = *newpair.y1; push_pair = true; };
        }
        else {
            cursor += 1;
            continue;
        }

        while advance() if cursor.* == #char ":" break;
        while advance() if cursor.* != #char " " break;

        floatstr: string;
        floatstr.data  = cursor;
        floatstr.count = file.count - (cursor - file.data);

        success: bool = ---;
        container.*, success = string_to_float64(floatstr);
        assert(success);

        if push_pair  bucket_array_add(*allpairs, newpair);

        cursor += 1;
    }
    time_block_end("loop");

    return allpairs;
}

main :: () {
    cpu_frequency  := estimate_cpu_frequency(200);

    start_profiling();

    context.print_style.default_format_float.trailing_width = 13;

    args := get_command_line_arguments();
    if args.count < 2 {
        log_error("[Error] No name was supplied! Usage: % (name)", args[0]);
        return;
    }

    json_filename := tprint("data_%.json", args[1]);
    json_file, success := read_entire_file(json_filename);
    if !success {
        log("Unable to open file '%'", json_filename);
        return;
    }

    reference_distance : *float64;
    expected_mean      : float64;
    ddump_filename := tprint("ddump_%.f64", args[1]);
    if file_exists(ddump_filename) {
        time_block("file_read");
        ddump_file:, success = read_entire_file(ddump_filename);
        assert(success);
        reference_distance   = xx ddump_file.data;
        expected_mean        = reference_distance.*;
        reference_distance  += 1; // the first float64 is the expected mean
    }

    pairs := parse_json(xx *json_file);

    mean_sum : float64;
    for pairs {
        time_block("sum");

        using it;
        distance := reference_haversine(x0, y0, x1, y1, EARTH_RADIUS);

        if reference_distance {
            if !values_are_close(cast(float32) reference_distance.*, xx distance)
                then log("Expected distance '%', but computed distance was '%'", reference_distance.*, distance);
            reference_distance += 1;
        }

        mean_sum += distance;
    }

    mean_sum      /= pairs.count;

    //report_memory_leaks();

    print("Pair count: %\n", pairs.count);
    print("Computed Mean: %\n", mean_sum);
    if reference_distance {
        write_string("  -----------------------------------\n");
        print("Expected Mean: %\n", expected_mean);
        print("Difference:    %\n", expected_mean - mean_sum);
    }

    end_and_report_profiling(cpu_frequency);
}

#import "Command_Line";
#import "File";
#import "Basic"()(MEMORY_DEBUGGER = true);
#import "Bucket_Array";
#import "Math";
#import "Sloppy_Math";
#import "File_Utilities";
