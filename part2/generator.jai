#load "haversine.jai";

#run {
    #import "Compiler";

    set_build_options_dc(.{output_path = "build"});
}

Arguments :: struct {
    name     : string;
    clusters :     = false;
    seed     : u64 = 0;
    count    : s64 = 100;

    #place seed;
    s: type_of(seed) = ---;

    #place count;
    c: type_of(count) = ---;
}

main :: () {
    success, args := parse_arguments(Arguments);
    if !success return;

    if args.name == "" {
        log("Error: Must give a name\n");
        return;
    }

    random_seed(args.seed);

    context.print_style.default_format_float.zero_removal   = .NO;
    context.print_style.default_format_float.trailing_width = 15;

    x0_range := float.[- 90,  90];
    x1_range := float.[- 90,  90];

    y0_range := float.[-180, 180];
    y1_range := float.[-180, 180];
    if args.clusters {
        MIN_RANGE_SIZE :: 10.0;
        MAX_RANGE_SIZE :: 45.0;
        p0_range_size := random_get_within_range(MIN_RANGE_SIZE, MAX_RANGE_SIZE);
        p1_range_size := random_get_within_range(MIN_RANGE_SIZE, MAX_RANGE_SIZE);

        x0_range[0] = random_get_within_range(x0_range[0], x0_range[1] - p0_range_size);
        x0_range[1] = x0_range[0] + p0_range_size;
        y0_range[0] = random_get_within_range(y0_range[0], y0_range[1] - p0_range_size);
        y0_range[1] = y0_range[0] + p0_range_size;

        x1_range[0] = random_get_within_range(x1_range[0], x1_range[1] - p1_range_size);
        x1_range[1] = x1_range[0] + p1_range_size;
        y1_range[0] = random_get_within_range(y1_range[0], y1_range[1] - p1_range_size);
        y1_range[1] = y1_range[0] + p1_range_size;
    }

    distances_dump := NewArray(args.count + 1, float64);
    dump_cursor    := distances_dump.data + 1; // we're going to put the expected mean as the first float64

    json_builder : String_Builder;
    init_string_builder(*json_builder);
    append(*json_builder, "{\"pairs\":[");

    mean_sum : float64;
    for 0..args.count-1 {
        if it == 0 append(*json_builder, "\n");
        else       append(*json_builder, ",\n");

        x0_deg := random_get_within_range(- 90,  90);
        y0_deg := random_get_within_range(-180, 180);

        x1_deg := random_get_within_range(- 90,  90);
        y1_deg := random_get_within_range(-180, 180);

        TEMPLATE :: "    {\"x0\":%, \"y0\":%, \"x1\":%, \"y1\":%}";

        json_line := tprint(TEMPLATE, x0_deg, y0_deg, x1_deg, y1_deg);
        append(*json_builder, json_line);

        reset_temporary_storage();

        dump_cursor.* = reference_haversine(x0_deg, y0_deg, x1_deg, y1_deg, EARTH_RADIUS);
        mean_sum    += dump_cursor.*;
        dump_cursor += 1;
    }

    mean_sum /= args.count;

    distances_dump[0] = mean_sum;

    INFO_TEMPLATE :: #string INFOSTR
Method: %
Random seed: %
Pair count: %
Expected mean: %
INFOSTR;

    infostr := tprint(INFO_TEMPLATE, ifx args.clusters then "Clusters" else "Uniform", args.seed, args.count, mean_sum);
    write_string(infostr);
    write_entire_file(tprint("info_%.txt", args.name), infostr);

    append(*json_builder, "\n]}");
    write_entire_file(tprint("data_%.json", args.name), *json_builder);

    assert(dump_cursor == (distances_dump.data + distances_dump.count));
    write_entire_file(tprint("ddump_%.f64", args.name), distances_dump.data, (args.count + 1) * size_of(float64));

    reset_temporary_storage();
}

#import "Basic";
#import "Random";
#import "Math";
#import "File";
#import "Command_Line";
