# CalfNet-SICR+E input preparation helpers
# Expected movement columns:
# date_shipped, from_zipcode, to_zipcode, total_animals, tau_hours
# Expected herd-size columns:
# zipcode, herd_size

prepare_calfnet_inputs <- function(movements,
                                   zip_herd_sizes,
                                   herd_multiplier = 1,
                                   top_prop = 0.10) {
  required_movement_cols <- c("date_shipped", "from_zipcode", "to_zipcode", "total_animals", "tau_hours")
  required_herd_cols <- c("zipcode", "herd_size")

  missing_movement <- setdiff(required_movement_cols, names(movements))
  missing_herd <- setdiff(required_herd_cols, names(zip_herd_sizes))

  if (length(missing_movement) > 0) {
    stop("Movement data are missing columns: ", paste(missing_movement, collapse = ", "))
  }
  if (length(missing_herd) > 0) {
    stop("Herd-size data are missing columns: ", paste(missing_herd, collapse = ", "))
  }

  zip_herd_sizes <- zip_herd_sizes %>%
    dplyr::transmute(
      zipcode = sprintf("%05d", as.integer(.data$zipcode)),
      herd_size_base = as.integer(round(.data$herd_size)),
      herd_size = as.integer(ceiling(herd_multiplier * .data$herd_size))
    )

  movements <- movements %>%
    dplyr::mutate(
      date_shipped = suppressWarnings(lubridate::mdy(.data$date_shipped)),
      Day = as.integer(.data$date_shipped - min(.data$date_shipped, na.rm = TRUE)) + 1L,
      From_zipcode = sprintf("%05d", as.integer(.data$from_zipcode)),
      To_zipcode = sprintf("%05d", as.integer(.data$to_zipcode)),
      Total_animals = as.integer(.data$total_animals),
      Tau_hours = as.numeric(.data$tau_hours)
    ) %>%
    dplyr::select(.data$Day, .data$From_zipcode, .data$To_zipcode, .data$Total_animals, .data$Tau_hours) %>%
    dplyr::filter(
      !is.na(.data$Day),
      !is.na(.data$From_zipcode),
      !is.na(.data$To_zipcode),
      !is.na(.data$Total_animals),
      .data$Total_animals > 0
    )

  all_zips_mov <- union(movements$From_zipcode, movements$To_zipcode)
  modeled_zips <- sort(intersect(all_zips_mov, zip_herd_sizes$zipcode))

  if (length(modeled_zips) == 0) {
    stop("No overlapping zip codes between movement data and herd-size data.")
  }

  movements <- movements %>%
    dplyr::filter(.data$From_zipcode %in% modeled_zips, .data$To_zipcode %in% modeled_zips)

  zip_herd_sizes <- zip_herd_sizes %>%
    dplyr::filter(.data$zipcode %in% modeled_zips) %>%
    dplyr::arrange(match(.data$zipcode, modeled_zips))

  zip_seq <- stats::setNames(seq_along(modeled_zips), modeled_zips)
  N0 <- as.integer(zip_herd_sizes$herd_size)
  nzip <- length(modeled_zips)
  tmax <- max(movements$Day, na.rm = TRUE) + 1L

  movements_by_day <- split(movements, movements$Day)
  movements_by_day_idx <- lapply(movements_by_day, function(df) {
    list(
      j_from = unname(zip_seq[df$From_zipcode]),
      i_to = unname(zip_seq[df$To_zipcode]),
      vol = df$Total_animals,
      tau = df$Tau_hours
    )
  })

  exporter_zips <- movements %>%
    dplyr::distinct(.data$From_zipcode) %>%
    dplyr::pull(.data$From_zipcode)

  edges <- movements %>%
    dplyr::group_by(.data$From_zipcode, .data$To_zipcode) %>%
    dplyr::summarise(weight = sum(.data$Total_animals, na.rm = TRUE), .groups = "drop")

  g <- igraph::graph_from_data_frame(
    d = edges,
    directed = TRUE,
    vertices = data.frame(name = modeled_zips)
  )
  igraph::E(g)$weight <- edges$weight

  zscore <- function(x) {
    s <- stats::sd(x, na.rm = TRUE)
    if (is.na(s) || s == 0) return(rep(0, length(x)))
    (x - mean(x, na.rm = TRUE)) / s
  }

  centrality_tbl <- tibble::tibble(
    zipcode = igraph::V(g)$name,
    strength_all = as.numeric(igraph::strength(g, mode = "all", weights = igraph::E(g)$weight)),
    betweenness = as.numeric(igraph::betweenness(g, directed = FALSE, normalized = TRUE))
  ) %>%
    dplyr::mutate(
      strength_log = log1p(.data$strength_all),
      score = 0.5 * zscore(.data$strength_log) + 0.5 * zscore(.data$betweenness)
    )

  high_centrality_zips <- centrality_tbl %>%
    dplyr::arrange(dplyr::desc(.data$score)) %>%
    dplyr::slice_head(prop = top_prop) %>%
    dplyr::pull(.data$zipcode)

  list(
    movements = movements,
    zip_herd_sizes = zip_herd_sizes,
    modeled_zips = modeled_zips,
    zip_seq = zip_seq,
    N0 = N0,
    nzip = nzip,
    tmax = tmax,
    movements_by_day_idx = movements_by_day_idx,
    exporter_zips = exporter_zips,
    high_centrality_zips = high_centrality_zips,
    centrality_tbl = centrality_tbl,
    network = g,
    herd_multiplier = herd_multiplier
  )
}
