#load "haversine.jai";

Arguments :: struct {
    pairs : string;
    ddump : string;
}

Pair :: struct {
    x0 : float64;
    y0 : float64;

    x1 : float64;
    y1 : float64;
}

parse_json :: (file: *[]u8) -> Bucket_Array(Pair, 1000) {
    end    := file.data + file.count;
    cursor := file.data;

    advance :: () -> bool #expand {
        `cursor += 1;
        return `cursor < `end;
    }

    allpairs : Bucket_Array(Pair, 1000);

    newpair : Pair;
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

    return allpairs;
}

main :: () {
    context.print_style.default_format_float.trailing_width = 13;

    success, args, is_set := parse_arguments(Arguments);
    if !success return;

    if !is_set.pairs {
        show_help(Arguments, Default_Argument_Flags, .["help", "HELP", "?"]);
        return;
    }

    points_file:, success = read_entire_file(args.pairs);
    if !success {
        log("Unable to open file '%'", args.pairs);
        return;
    }

    reference_distance : *float64;
    expected_mean : float64;
    if is_set.ddump {
        ddump_file:, success = read_entire_file(args.ddump);
        assert(success);
        reference_distance   = xx ddump_file.data;
        expected_mean        = reference_distance.*;
        reference_distance  += 1; // the first float64 is the expected mean
    }

    pairs := parse_json(xx *points_file);

    mean_sum : float64;
    for pairs {
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

    print("Pair count: %\n", pairs.count);
    print("Computed Mean: %\n", mean_sum);
    if reference_distance {
        write_string("  -----------------------------------\n");
        print("Expected Mean: %\n", expected_mean);
        print("Difference:    %\n", expected_mean - mean_sum);
    }
}

#import "Command_Line";
#import "File";
#import "Basic";
#import "Bucket_Array";
#import "Math";
#import "Sloppy_Math";
