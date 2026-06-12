
**Recommended Plan**

1. **Use device location**
   - Flutter package: `geolocator`
   - Ask for foreground location permission.
   - Get `lat/lng`.
   - Keep last known location as fallback.
   - Add missing permission in android manifest if it doesn't exist

2. **Use OpenStreetMap/Overpass as the first provider**
   Query the correct mosque tags. In OSM, mosques are usually not `amenity=mosque`; they are commonly:

   - `amenity=place_of_worship`
   - `religion=muslim`
   - sometimes `building=mosque`

   OSM wiki confirms this tagging pattern: `amenity=place_of_worship` plus `religion=muslim`; `building=mosque` alone only describes the building, not necessarily current use. Sources: [OSM place of worship](https://wiki.openstreetmap.org/wiki/Tag%3Aamenity%3Dplace_of_worship), [OSM mosque](https://wiki.openstreetmap.org/wiki/Mosque).

   Example Overpass query:

   ```text
    [out:json][timeout:25];
    // Target coordinates: 51°07'11.6"N 0°11'16.2"W -> Lat: 51.119889, Lon: -0.187833
    (
        node["amenity"="place_of_worship"]["religion"="muslim"](around:3000, 51.119889, -0.187833);
        way["amenity"="place_of_worship"]["religion"="muslim"](around:3000, 51.119889, -0.187833);
        relation["amenity"="place_of_worship"]["religion"="muslim"](around:3000, 51.119889, -0.187833);
    );
    // output geolocations and meta information
    out body;
    >;
    out skel qt;
   ```

3. **Do progressive radius search**
   Don’t only search one fixed radius. Add option for the user to adjust the radius and a button to start searching but it will auto search with default option (3 km) upon opening the page

   Suggested flow:

   - Search `3 km`
   - If fewer than 3 results, search `5 km`
   - If fewer than 3 results, search `10 km`
   - Max around `25 km`, depending on city/rural context


8. **Show results**
   In Flutter:

   - Use `flutter_map` or `maplibre` for non-Google maps.
   - Use OpenStreetMap/vector tiles for display.
   - Sort by Haversine distance.
   - Show distance, address, and navigation button.
   - For navigation, open external apps using `url_launcher`, e.g. Apple Maps, Google Maps, Waze, etc. You are not using Google Places API just by opening navigation.

**Architecture I’d Use**

```text
Flutter app
  -> get current location
  -> call your backend /nearby-mosques
      -> query your verified DB
      -> query Overpass
      -> fallback to Foursquare if needed
      -> dedupe/cache/sort
  -> return normalized mosque list
  -> show list + map
```

Add loading while fetching API response and for tiles on the map, add for each mosque add /assets/mosque/mosque.png as an icon and when user clicks on it, it will show options as mentioned above specifically the option to open in maps

Support for localization is important as well for everything.