# Data notes

The original interstate calf movement data used in the manuscript are not included in this repository because they contain restricted animal movement records obtained through state data requests.

This repository includes synthetic example input files to demonstrate the required file structure for the CalfNet-SICR+E model framework.

## Required movement data columns

`data/example/example_movement_data.csv` shows the expected movement format:

- `date_shipped`: shipment date, formatted as `MM/DD/YYYY`
- `from_zipcode`: origin zip code
- `to_zipcode`: destination zip code
- `total_animals`: number of calves moved
- `tau_hours`: estimated transport duration in hours

## Required herd-size data columns

`data/example/example_zip_herd_sizes.csv` shows the expected herd-size format:

- `zipcode`: zip code
- `herd_size`: estimated number of cattle in that zip code

Users with approved access to comparable movement data can reproduce the workflow by formatting their data with these required columns.
