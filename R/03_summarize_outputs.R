# CalfNet-SICR+E output summaries

summarize_curve <- function(curve, seed_k = 5, seed_IH = 5) {
  curve %>%
    dplyr::summarise(
      peak_infections = max(.data$infected_total, na.rm = TRUE),
      cumulative_infections = sum(.data$incidence, na.rm = TRUE) + seed_k * seed_IH,
      peak_IH = max(.data$IH, na.rm = TRUE),
      peak_IL = max(.data$IL, na.rm = TRUE),
      peak_carriers = max(.data$C, na.rm = TRUE),
      max_cumulative_infected_zips = max(.data$cumulative_infected_zips, na.rm = TRUE)
    )
}

summarize_many_simulations <- function(sim_results, seed_k = 5, seed_IH = 5) {
  purrr::map_dfr(seq_along(sim_results), function(i) {
    summarize_curve(sim_results[[i]]$curve, seed_k = seed_k, seed_IH = seed_IH) %>%
      dplyr::mutate(
        sim = i,
        intro_type = unique(sim_results[[i]]$curve$intro_type)
      )
  })
}

median_ci <- function(x, nboot = 1000) {
  x <- x[is.finite(x)]
  if (length(x) == 0) {
    return(c(median = NA_real_, lo = NA_real_, hi = NA_real_))
  }

  boot_medians <- replicate(
    nboot,
    stats::median(sample(x, size = length(x), replace = TRUE), na.rm = TRUE)
  )

  c(
    median = stats::median(x, na.rm = TRUE),
    lo = unname(stats::quantile(boot_medians, 0.025, na.rm = TRUE)),
    hi = unname(stats::quantile(boot_medians, 0.975, na.rm = TRUE))
  )
}

format_ci <- function(x) {
  vals <- median_ci(x)
  paste0(
    scales::comma(round(vals[["median"]])),
    " (",
    scales::comma(round(vals[["lo"]])),
    "-",
    scales::comma(round(vals[["hi"]])),
    ")"
  )
}
