/* ========================================================================
   LISTING 65
   ======================================================================== */

EARTH_RADIUS :: 6372.8;

square :: (a: float64) -> float64 {
    return a*a;
}

rad_from_deg :: (degrees: float64) -> float64 {
    return 0.01745329251994329577 * degrees;
}

// NOTE(casey): EarthRadius is generally expected to be 6372.8
reference_haversine :: (x0: float64, y0: float64, x1: float64, y1: float64, earth_radius: float64) -> float64 {
    /* NOTE(casey): This is not meant to be a "good" way to calculate the Haversine distance.
       Instead, it attempts to follow, as closely as possible, the formula used in the real-world
       question on which these homework exercises are loosely based.
    */
    
    lat1 := y0;
    lat2 := y1;
    lon1 := x0;
    lon2 := x1;
    
    dLat := rad_from_deg(lat2 - lat1);
    dLon := rad_from_deg(lon2 - lon1);
    lat1  = rad_from_deg(lat1);
    lat2  = rad_from_deg(lat2);
    
    a := square(sin(dLat/2.0)) + cos(lat1)*cos(lat2)*square(sin(dLon/2));
    c := 2.0*asin(sqrt(a));
    
    result := earth_radius * c;
    return result;
}
