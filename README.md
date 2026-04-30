# CalfNet-SICR+E model framework

This repository provides a reusable, public implementation of the CalfNet-SICR+E model framework and a synthetic example dataset to explore *Salmonella* Dublin epidemic potential in a hypothetical network. It does not reproduce the manuscript’s restricted-data analyses directly because the interstate movement records cannot be shared publicly.

The model is a stochastic, discrete-time, zip code-level Susceptible-Infected-Carrier-Recovered model with an explicit environmental reservoir. It combines:

- empirical or user-provided calf movement records,
- zip code-level cattle population estimates,
- environmental transmission within zip codes,
- movement-mediated transport between zip codes,
- long-term carrier states and intermittent carrier shedding.

## Repository contents

```text
R/
  01_prepare_inputs.R      # Data cleaning, movement indexing, centrality and seed pools
  02_model_functions.R     # Core CalfNet-SICR+E simulation functions
  03_summarize_outputs.R   # Simple summary helpers
examples/
  run_example.R            # Minimal example using synthetic data
data/example/
  example_movement_data.csv
  example_zip_herd_sizes.csv
data/README_data.md        # Input data requirements and restriction note
```

## Data availability

The original interstate calf movement data used in the manuscript are not included in this repository because they contain restricted animal movement records obtained through state data requests. Synthetic example data are provided only to demonstrate the required input structure and to verify that the model framework runs.

## Required R packages

```r
install.packages(c(
  "tidyverse",
  "lubridate",
  "igraph",
  "mc2d",
  "scales"
))
```

## Quick start

Clone the repository, open the project folder in R/RStudio, and run:

```r
source("examples/run_example.R")
```

The example script loads synthetic movement and herd-size data, prepares model inputs, runs one simulation, prints summary outcomes, and plots the IH, IL, and carrier trajectories.

## Input data format

Movement data should contain:

```text
date_shipped, from_zipcode, to_zipcode, total_animals, tau_hours
```

Herd-size data should contain:

```text
zipcode, herd_size
```

See `data/example/` for synthetic examples.

## Basic model workflow

```r
library(tidyverse)
library(lubridate)
library(igraph)
library(mc2d)

source("R/01_prepare_inputs.R")
source("R/02_model_functions.R")
source("R/03_summarize_outputs.R")

movements <- readr::read_csv("data/example/example_movement_data.csv")
zip_herd_sizes <- readr::read_csv("data/example/example_zip_herd_sizes.csv")

input <- prepare_calfnet_inputs(
  movements = movements,
  zip_herd_sizes = zip_herd_sizes,
  herd_multiplier = 1
)

params <- calfnet_default_params()
params$beta_env <- 2e-5
params$beta_truck <- 0
params$epsilon <- 0.05
params$p_shed <- 0.30

result <- run_calfnet_sicre(
  input = input,
  params = params,
  intro_type = "high_centrality",
  seed_k = 2,
  seed_IH = 2,
  seed = 123
)

summarize_curve(result$curve, seed_k = 2, seed_IH = 2)
```

## Citation

If using this framework, please cite the associated manuscript when available:

Sequeira SC, Arruda AG, Arevalo-Mayorga A, Locke SR, Habing GG, Pomeroy LW. CalfNet-SICR+E: a stochastic simulation model of *Salmonella Dublin* transmission throughout US calf movement networks.

## License

MIT License. Copyright (c) [2026] [Sequeira SC et al.]
