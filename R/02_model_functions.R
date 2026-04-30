# CalfNet-SICR+E model functions

calfnet_default_params <- function() {
  list(
    beta_env = 2e-5,
    beta_truck = 0,
    epsilon = 0.05,
    p_shed = 0.30,
    k_high = 0.04,
    k_low = 0.0004,
    k_carrier = 0.0004,
    q_ih = 0.18,
    q_il = 0.015,
    p_high_min = 0.05,
    p_high_mode = 0.30,
    p_high_max = 0.50,
    duration_I_shape = 3,
    duration_I_rate = 3 / 17,
    duration_R_min = 140,
    duration_R_rate = 1 / 140,
    duration_C_min = 180,
    duration_C_mode = 365,
    duration_C_max = 1095
  )
}

pick_seed_zips <- function(input,
                           intro_type = c("random_all", "exporters", "high_centrality"),
                           seed_k = 5,
                           seed = NULL) {
  intro_type <- match.arg(intro_type)
  if (!is.null(seed)) set.seed(seed)

  pool <- switch(
    intro_type,
    random_all = input$modeled_zips,
    exporters = intersect(input$exporter_zips, input$modeled_zips),
    high_centrality = intersect(input$high_centrality_zips, input$modeled_zips)
  )

  if (length(pool) < seed_k) {
    stop("Not enough zip codes in selected seeding pool.")
  }

  sample(pool, seed_k, replace = FALSE)
}

draw_movers <- function(draw_n, counts_vec) {
  counts_vec <- pmax(0L, as.integer(counts_vec))
  total_n <- sum(counts_vec)

  if (draw_n <= 0L || total_n <= 0L) {
    return(rep.int(0L, length(counts_vec)))
  }

  draw_n <- min(as.integer(draw_n), total_n)
  out <- integer(length(counts_vec))

  for (k in seq_len(length(counts_vec) - 1L)) {
    if (draw_n <= 0L) break

    out[k] <- rhyper(
      nn = 1L,
      m = counts_vec[k],
      n = total_n - counts_vec[k],
      k = draw_n
    )

    draw_n <- draw_n - out[k]
    total_n <- total_n - counts_vec[k]
  }

  out[length(counts_vec)] <- draw_n
  out
}

p_truck_fun <- function(beta_truck, I_truck, tau_hours) {
  time_scale <- pmin(1, ifelse(is.na(tau_hours), 0, tau_hours) / 24)
  1 - exp(-beta_truck * I_truck * time_scale)
}

run_calfnet_sicre <- function(input,
                              params = calfnet_default_params(),
                              intro_type = c("random_all", "exporters", "high_centrality"),
                              seed_k = 5,
                              seed_IH = 5,
                              n_days = input$tmax,
                              fixed_seed_zips = NULL,
                              seed = NULL) {
  intro_type <- match.arg(intro_type)
  if (!is.null(seed)) set.seed(seed)

  p <- utils::modifyList(calfnet_default_params(), params)

  if (is.null(fixed_seed_zips)) {
    seed_zips <- pick_seed_zips(
      input = input,
      intro_type = intro_type,
      seed_k = seed_k,
      seed = seed
    )
  } else {
    seed_zips <- fixed_seed_zips
  }

  seed_idx <- unname(input$zip_seq[seed_zips])

  p_high <- mc2d::rpert(1, min = p$p_high_min, mode = p$p_high_mode, max = p$p_high_max)
  duration_I <- rgamma(1, shape = p$duration_I_shape, rate = p$duration_I_rate)
  duration_R <- p$duration_R_min + rexp(1, rate = p$duration_R_rate)
  duration_C <- mc2d::rpert(1, min = p$duration_C_min, mode = p$duration_C_mode, max = p$duration_C_max)

  p_leave_I <- 1 - exp(-1 / duration_I)
  p_recover_C <- 1 - exp(-1 / duration_C)
  p_wane_R <- 1 - exp(-1 / duration_R)

  S <- as.integer(input$N0)
  IH <- integer(input$nzip)
  IL <- integer(input$nzip)
  C <- integer(input$nzip)
  R <- integer(input$nzip)
  E <- numeric(input$nzip)

  for (i in seed_idx) {
    n_seed <- min(as.integer(seed_IH), S[i])
    S[i] <- S[i] - n_seed
    IH[i] <- IH[i] + n_seed
  }

  ever_infected_zip <- (IH + IL + C) > 0

  out <- vector("list", n_days + 1)
  out[[1]] <- tibble::tibble(
    day = 0,
    S = sum(S),
    IH = sum(IH),
    IL = sum(IL),
    C = sum(C),
    R = sum(R),
    infected_total = sum(IH + IL + C),
    active_infected_zips = sum((IH + IL + C) > 0),
    cumulative_infected_zips = sum(ever_infected_zip),
    incidence = 0
  )

  for (t in seq_len(n_days)) {
    moved_S <- integer(input$nzip)
    moved_IH <- integer(input$nzip)
    moved_IL <- integer(input$nzip)
    moved_C <- integer(input$nzip)
    moved_R <- integer(input$nzip)

    m <- input$movements_by_day_idx[[as.character(t)]]

    if (!is.null(m)) {
      for (k in seq_along(m$vol)) {
        j <- m$j_from[k]
        i <- m$i_to[k]
        v <- m$vol[k]
        tau <- m$tau[k]

        if (is.na(j) || is.na(i) || v <= 0) next

        drawn <- draw_movers(v, c(S[j], IH[j], IL[j], C[j], R[j]))
        names(drawn) <- c("S", "IH", "IL", "C", "R")

        S[j] <- S[j] - drawn["S"]
        IH[j] <- IH[j] - drawn["IH"]
        IL[j] <- IL[j] - drawn["IL"]
        C[j] <- C[j] - drawn["C"]
        R[j] <- R[j] - drawn["R"]

        I_truck <- drawn["IH"] + drawn["IL"] + drawn["C"]
        inf_truck <- 0L

        if (drawn["S"] > 0 && I_truck > 0) {
          p_truck <- p_truck_fun(p$beta_truck, I_truck, tau)
          p_truck <- max(0, min(1, p_truck))
          inf_truck <- rbinom(1, drawn["S"], p_truck)
        }

        if (inf_truck > 0) {
          drawn["S"] <- drawn["S"] - inf_truck
          drawn["IH"] <- drawn["IH"] + inf_truck
        }

        moved_S[i] <- moved_S[i] + drawn["S"]
        moved_IH[i] <- moved_IH[i] + drawn["IH"]
        moved_IL[i] <- moved_IL[i] + drawn["IL"]
        moved_C[i] <- moved_C[i] + drawn["C"]
        moved_R[i] <- moved_R[i] + drawn["R"]
      }
    }

    S <- S + moved_S
    IH <- IH + moved_IH
    IL <- IL + moved_IL
    C <- C + moved_C
    R <- R + moved_R

    p_env <- pmin(1, 1 - exp(-p$beta_env * E))
    new_inf <- rbinom(input$nzip, S, p_env)
    new_IH <- rbinom(input$nzip, new_inf, p_high)
    new_IL <- new_inf - new_IH

    leave_IH <- rbinom(input$nzip, IH, p_leave_I)
    toC_IH <- rbinom(input$nzip, leave_IH, p$q_ih)
    toR_IH <- leave_IH - toC_IH

    leave_IL <- rbinom(input$nzip, IL, p_leave_I)
    toC_IL <- rbinom(input$nzip, leave_IL, p$q_il)
    toR_IL <- leave_IL - toC_IL

    recover_C <- rbinom(input$nzip, C, p_recover_C)
    wane_R <- rbinom(input$nzip, R, p_wane_R)

    S <- S - new_inf + wane_R
    IH <- IH + new_IH - leave_IH
    IL <- IL + new_IL - leave_IL
    C <- C + toC_IH + toC_IL - recover_C
    R <- R + toR_IH + toR_IL + recover_C - wane_R

    shed_C <- rbinom(input$nzip, C, p$p_shed)

    E <- pmax(
      0,
      (1 - p$epsilon) * E +
        p$k_high * IH +
        p$k_low * IL +
        p$k_carrier * shed_C
    )

    ever_infected_zip <- ever_infected_zip | ((IH + IL + C) > 0)

    out[[t + 1]] <- tibble::tibble(
      day = t,
      S = sum(S),
      IH = sum(IH),
      IL = sum(IL),
      C = sum(C),
      R = sum(R),
      infected_total = sum(IH + IL + C),
      active_infected_zips = sum((IH + IL + C) > 0),
      cumulative_infected_zips = sum(ever_infected_zip),
      incidence = sum(new_inf)
    )
  }

  zip_final <- tibble::tibble(
    zipcode = input$modeled_zips,
    ever_infected = as.integer(ever_infected_zip),
    active_infected_final = as.integer((IH + IL + C) > 0),
    intro_type = intro_type
  )

  list(
    curve = dplyr::bind_rows(out) %>%
      dplyr::mutate(intro_type = intro_type),
    zip_final = zip_final,
    seed_zips = seed_zips,
    parameters = p
  )
}
