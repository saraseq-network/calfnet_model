# Example run of the CalfNet-SICR+E model framework using synthetic data.
# This example is intended to verify that the framework runs and to show expected input structure.

library(tidyverse)
library(lubridate)
library(igraph)
library(mc2d)
library(scales)

source("R/01_prepare_inputs.R")
source("R/02_model_functions.R")
source("R/03_summarize_outputs.R")

movements <- readr::read_csv("synthetic_us_network_dataset/synthetic_us_movement_data.csv", show_col_types = FALSE)
zip_herd_sizes <- readr::read_csv("synthetic_us_network_dataset/synthetic_us_zip_herd_sizes.csv", show_col_types = FALSE)

input <- prepare_calfnet_inputs(
  movements = movements,
  zip_herd_sizes = zip_herd_sizes,
  herd_multiplier = 2.5,
  top_prop = 0.10
)

params <- calfnet_default_params()
params$beta_env <- 2e-5
params$beta_truck <- 0
params$epsilon <- 0.05
params$p_shed <- 0.30
params$p_high_mode <- 0.30

set.seed(123)
example_result <- run_calfnet_sicre(
  input = input,
  params = params,
  intro_type = "high_centrality",
  seed_k = 5,
  seed_IH = 5,
  n_days = input$tmax,
  seed = 123
)

print(example_result$seed_zips)
print(summarize_curve(example_result$curve, seed_k = 5, seed_IH = 5))

p <- ggplot(example_result$curve, aes(x = day)) +
  geom_line(aes(y = IH, color = "IH"), linewidth = 1) +
  geom_line(aes(y = IL, color = "IL"), linewidth = 1) +
  geom_line(aes(y = C, color = "Carriers"), linewidth = 1) +
  labs(
    x = "Day",
    y = "Number of cattle",
    color = NULL,
    title = "Example CalfNet-SICR+E simulation using Paper 1 baseline settings"
  ) +
  theme_classic(base_size = 14)

print(p)
