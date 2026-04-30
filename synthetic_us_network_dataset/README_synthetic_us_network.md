# Synthetic U.S.-like calf movement network example

These files are synthetic and are not derived from restricted animal movement records. They are intended as a demonstration and hypothetical dataset for the CalfNet-SICR+E workflow,

## Files

- `synthetic_us_movement_data.csv`
  - `date_shipped`
  - `from_zipcode`
  - `to_zipcode`
  - `total_animals`
  - `tau_hours`

- `synthetic_us_zip_herd_sizes.csv`
  - `zipcode`
  - `herd_size`

- `synthetic_us_zip_metadata.csv`
  - Optional metadata for checking or plotting the synthetic network.
  - Not required by the core model.

## Synthetic design choices

This dataset was generated to mimic broad structural features often seen in livestock movement systems:

- a heavy-tailed movement distribution, where a small proportion of origins account for a large share of outbound volume;
- mostly regional and within-state movements, with some long-distance interstate movements;
- variable shipment sizes;
- estimated transport duration using approximate synthetic coordinates and a capped travel-time rule.

## Summary

| Quantity | Value |
|---|---:|
| Movement records | 19,882 |
| ZIP codes with herd sizes | 850 |
| ZIP codes observed in movements | 842 |
| Unique directed edges | 9,887 |
| Date range | 2021-06-01 to 2022-05-31 |
| Total animals moved | 442,758 |
| Median animals per shipment | 11 |
| Mean tau_hours | 7.82 |
| Share of outbound volume from top 10% origins | 57.3% |
| Share of movements within the same state | 65.0% |

## Important caveat

This is a demonstration network. It is useful for testing code behavior, plotting, package examples and showing that the model can run on a larger U.S.-like dynamic network. It should not be interpreted as real U.S. cattle movement data or used to make epidemiological claims. You can adapt with your own data, acknowledging our work.
