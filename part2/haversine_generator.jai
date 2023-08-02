
#import "Basic";

Generator_Arguments :: struct {
    clusters   : bool = true; @"?Generate pairs in two clusters so that their average distance will converge to the distance of the two clusters."
    seed       : int;
    pair_count : int  = 100_000_00;

    #place seed;
    s          : int = ---; @"?Shorthand for 'seed'."

    #place pair_count;
    p          : int = ---; @"?Shorthand for 'pair_count'."
}

main :: () {
    success, args := parse_arguments(Generator_Arguments);

    context.print_style.default_format_float.trailing_width = 15;
    context.print_style.default_format_float.zero_removal   = .NO;

    if !success {
        print("Could not parse command-line arguments...\n");
        return;
    }

    random_seed(cast(u64) args.seed);

    X_ANGLE_MIN : float32 : - 90;
    X_ANGLE_MAX : float32 :   90;
    Y_ANGLE_MIN : float32 : -180;
    Y_ANGLE_MAX : float32 :  180;

    range_0, range_1 : struct {
        min: Vector2;
        max: Vector2;
    };

    mean : float64;

    inv_count := 1.0 / cast(float64)args.pair_count;
    for 0..args.pair_count-1 {
        x0 := random_get_within_range(X_ANGLE_MIN, X_ANGLE_MAX);
        y0 := random_get_within_range(Y_ANGLE_MIN, Y_ANGLE_MAX);
        x1 := random_get_within_range(X_ANGLE_MIN, X_ANGLE_MAX);
        y1 := random_get_within_range(Y_ANGLE_MIN, Y_ANGLE_MAX);

        haversine := reference_haversine(x0, y0, x1, y1, EARTH_RADIUS);
        mean += haversine * inv_count;

        FORMAT_STR :: #string DONE
    {"x0": %, "y0": %, "x1": %, "y1": %},
DONE;
        //print(FORMAT_STR, x0, y0, x1, y1);
    }

    print("Mean: %\n", mean);
}


EARTH_RADIUS : float64 : 6372.8;

reference_haversine :: (x0: float64, y0: float64, x1: float64, y1: float64, earth_radius: float64) -> float64{
    lat1 := y0;
    lat2 := y1;
    lon1 := x0;
    lon2 := x1;
    
    dLat := deg_to_rad(lat2 - lat1);
    dLon := deg_to_rad(lon2 - lon1);
    lat1  = deg_to_rad(lat1);
    lat2  = deg_to_rad(lat2);
    
    a : float64 = square(sin(dLat / 2.0)) + cos(lat1) * cos(lat2) * square(sin(dLon / 2.0));
    c : float64 = 2.0 * asin(sqrt(a));
    
    result := earth_radius * c;
    return result;
}

deg_to_rad :: (deg: float64) -> float64 #expand {
    return 0.01745329251994329577 * deg;
}

#scope_file

#import "Command_Line";
#import "Random";
#import "Math";
