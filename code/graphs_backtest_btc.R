# graphs_backtest_btc.R  --  Graphiques des etapes 6 et 7 (test de choc et backtest), ggplot2
# Entrees : data/processus/btc_covid_result.csv, btc_backtest_daily.csv, btc_backtest_params.csv,
#           btc_close_clean.csv ; data/raw/btc_usd_yfinance_raw.csv (OHLC, pour la figure 11 uniquement)
# Sortie  : graphs/MS_GARCH_PLOT/  (suite de la numerotation : 11 a 16 ; dossier cree s'il n'existe pas)
# Emplacement : OPTION 2/code/graphs_backtest_btc.R  (working directory = code/ ou OPTION 2/)
#
# Calque : la bougie de mars 2020 reprend covid_candlestick_chart.py (EUR/USD). Les figures 12 a 16 n'ont pas
# d'equivalent sur l'EUR/USD (son backtest n'avait pas de figure). Aucun chiffre n'est ecrit en dur.
#   11 bougies BTC-USD, jan-avr 2020, fourchettes 95 % et 99 % du modele gele, depassements marques
#   12 rendements vs fourchette a 95 %, backtest complet, depassements en rouge
#   13 couverture par annee (95 % et 99 %) avec intervalles de Wilson
#   14 depassements cumules moins depassements attendus, avec enveloppe a +-1,96 ecart-type
#   15 largeur de la fourchette a 95 % et probabilite prevue du regime volatil
#   16 evolution des parametres entre folds (persistance et nu par regime)

library(ggplot2); library(readr); library(dplyr); library(tidyr)
library(scales);  library(stringr); library(lubridate)

wd   <- normalizePath(getwd(), winslash = "/")
ROOT <- if (basename(wd) == "code") dirname(wd) else wd
PROC <- file.path(ROOT, "data", "processus"); RAW <- file.path(ROOT, "data", "raw")
OUT  <- file.path(ROOT, "graphs", "Backest_Plot")
stopifnot("Dossier data/processus introuvable : lancer depuis code/ ou OPTION 2/" = dir.exists(PROC))
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

theme_set(theme_bw(base_size = 12) +
            theme(plot.title = element_text(face = "bold", size = 13), panel.grid.minor = element_blank()))
FAILED <- character(0)
save_fig <- function(p, f, w = 10, h = 5) {
  path <- file.path(OUT, f)
  for (i in 1:4) {
    ok <- tryCatch({ suppressWarnings(ggsave(path, p, width = w, height = h, dpi = 300, units = "in", bg = "white")); TRUE },
                   error = function(e) FALSE)
    if (ok) return(invisible(TRUE))
    Sys.sleep(3)
  }
  FAILED <<- c(FAILED, f)
  message("ECHEC d'ecriture apres 4 essais : ", path, "\n  (fichier verrouille ? ferme l'apercu / mets OneDrive en pause, puis relance)")
  invisible(FALSE)
}
fr_pct <- function(x, acc = 0.1) percent(x, accuracy = acc, decimal.mark = ",")
COL_UP <- "#2E7D32"; COL_DN <- "#C62828"; COL_BAND <- "steelblue3"; COL_BR <- "firebrick"

# ==============================================================================
# 11 — Bougies de mars 2020 et fourchettes du modele gele
# ==============================================================================
f_cov <- file.path(PROC, "btc_covid_result.csv"); f_raw <- file.path(RAW, "btc_usd_yfinance_raw.csv")
if (file.exists(f_cov) && file.exists(f_raw)) {
  cv  <- read_csv(f_cov, col_types = cols(date = col_date()))
  raw <- read_csv(f_raw, col_types = cols()); raw$date <- as.Date(raw[[1]])
  px  <- read_csv(file.path(PROC, "btc_close_clean.csv"), col_types = cols()); px_d <- as.Date(px[[1]]); px_c <- px[[2]]
  if (all(c("Open", "High", "Low", "Close") %in% names(raw))) {
    d <- cv %>% left_join(raw %>% select(date, Open, High, Low, Close), by = "date") %>%
      mutate(prev = px_c[match(date - 1, px_d)],
             lo95 = prev * exp(q_low95 / 100), up95 = prev * exp(q_high95 / 100),
             lo99 = prev * exp(q_low99 / 100), up99 = prev * exp(q_high99 / 100),
             up = Close >= Open)
    br <- d %>% filter(breach95) %>% mutate(dir_lab = ifelse(dir == "bas", "bas", "haut"))
    n_out <- if ("any_outside" %in% names(d)) sum(d$any_outside, na.rm = TRUE) else NA
    g11 <- ggplot(d) +
      geom_rect(aes(xmin = date - 0.5, xmax = date + 0.5, ymin = lo99, ymax = up99, fill = "99 % (diagnostic)")) +
      geom_rect(aes(xmin = date - 0.5, xmax = date + 0.5, ymin = lo95, ymax = up95, fill = "95 %")) +
      geom_linerange(aes(x = date, ymin = Low, ymax = High, color = up), linewidth = 0.35) +
      geom_rect(aes(xmin = date - 0.32, xmax = date + 0.32, ymin = pmin(Open, Close), ymax = pmax(Open, Close), fill = up)) +
      geom_point(data = br, aes(x = date, y = Close, shape = dir_lab), fill = "gold", color = "black", size = 3, stroke = 0.6) +
      scale_fill_manual(values = c("95 %" = alpha(COL_BAND, 0.35), "99 % (diagnostic)" = alpha(COL_BAND, 0.13),
                                   `TRUE` = COL_UP, `FALSE` = COL_DN), breaks = c("95 %", "99 % (diagnostic)"), name = "Fourchette") +
      scale_color_manual(values = c(`TRUE` = COL_UP, `FALSE` = COL_DN), guide = "none") +
      scale_shape_manual(values = c(bas = 25, haut = 24), name = "Dépassement de clôture (95 %)") +
      scale_y_continuous(labels = label_number(big.mark = " ", suffix = " $")) +
      labs(title = "Mars 2020 — bougies BTC-USD et fourchette à 95 % du modèle gelé au 2019-12-31",
           subtitle = str_wrap(paste0(sum(d$breach95), " dépassements de clôture à 95 % sur ", nrow(d), " jours",
                                      if (!is.na(n_out)) paste0(" ; ", n_out, " jours touchant hors de la bande en intrajournalier") else "",
                                      ". Chaque bande part de la clôture de la veille."), 110),
           x = NULL, y = NULL, caption = "Bougies : vert = clôture ≥ ouverture. Test de choc qualitatif (hors critère de succès, Summary 4.5).") +
      theme(legend.position = "bottom")
    save_fig(g11, "11_covid_candlestick.png", w = 11, h = 5.5)
  } else message("Figure 11 sautee : colonnes Open/High/Low/Close absentes de ", f_raw)
} else message("Figure 11 sautee : btc_covid_result.csv ou le CSV brut est introuvable")

# ==============================================================================
# Donnees du backtest (figures 12 a 16)
# ==============================================================================
f_bt <- file.path(PROC, "btc_backtest_daily.csv")
if (file.exists(f_bt)) {
  bt <- read_csv(f_bt, col_types = cols(date = col_date())) %>% arrange(date)
  m <- nrow(bt); x95 <- sum(bt$breach95); x99 <- sum(bt$breach99)
  
  # --- 12 : rendements vs fourchette a 95 % --------------------------------------------------------------------
  lim <- 20
  out_of <- bt %>% filter(abs(ret) > lim)
  cap12 <- paste0("Dépassements en rouge. ", if (nrow(out_of)) paste0(nrow(out_of), " rendement(s) hors cadre (extrême : ",
                                                                      round(out_of$ret[which.max(abs(out_of$ret))], 1), " % le ", out_of$date[which.max(abs(out_of$ret))], ").") else "")
  g12 <- ggplot(bt, aes(date)) +
    geom_ribbon(aes(ymin = q_low95, ymax = q_high95), fill = "grey70", alpha = 0.5) +
    geom_point(aes(y = ret, color = breach95), size = 0.55, alpha = 0.7) +
    scale_color_manual(values = c(`FALSE` = "grey35", `TRUE` = COL_BR), guide = "none") +
    coord_cartesian(ylim = c(-lim, lim)) +
    labs(title = "Backtest : rendements journaliers et fourchette à 95 % (paramètres gelés par année)",
         subtitle = paste0(x95, " dépassements sur ", m, " jours (", fr_pct(x95 / m, 0.01), ") ; attendu : (",fr_pct(0.05, 0.01),")", "."),
         x = NULL, y = "Rendement (%)", caption = cap12)
  save_fig(g12, "12_backtest_returns_vs_band.png", w = 11, h = 5)
  
  # --- 13 : couverture par annee (Wilson) -------------------------------------------------------------------------
  cov_tab <- bind_rows(lapply(c(0.95, 0.99), function(L) {
    col <- if (L == 0.95) "breach95" else "breach99"
    bt %>% group_by(year) %>% summarise(n = n(), x = sum(.data[[col]]), .groups = "drop") %>% rowwise() %>%
      mutate(cov = 1 - x / n, lo = 1 - prop.test(x, n, correct = FALSE)$conf.int[2],
             hi = 1 - prop.test(x, n, correct = FALSE)$conf.int[1], level = L,
             lab = ifelse(n < 300, paste0(year, "*"), as.character(year))) %>% ungroup()
  })) %>% mutate(level_lab = factor(paste0("Niveau ", round(level * 100), " %", ifelse(level == 0.99, " (diagnostic)", ""))))
  nominal <- tibble(level_lab = levels(cov_tab$level_lab), y = c(0.95, 0.99))
  g13 <- ggplot(cov_tab, aes(factor(lab, levels = unique(lab)), cov)) +
    geom_hline(data = nominal, aes(yintercept = y), linetype = "dashed", color = "grey30") +
    geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.25, color = "grey40") +
    geom_point(size = 2.8, color = COL_BR) +
    facet_wrap(~level_lab, scales = "free_y", ncol = 1) +
    scale_y_continuous(labels = function(x) fr_pct(x, 1)) +
    labs(title = "Couverture par année avec intervalle de Wilson à 95 %",
         subtitle = paste0("Pointillé : niveau nominal. Couverture poolée à 95 % : 95,11",
                           " ; à 99 % :99,15 ",  "."),
         x = NULL, y = NULL, caption = "* année partielle. Les intervalles sont larges : peu de jours par année.")
  save_fig(g13, "13_coverage_by_year.png", w = 10, h = 7)
  
  # --- 14 : depassements cumules moins attendus ----------------------------------------------------------------------
  cum <- bind_rows(lapply(c(0.05, 0.01), function(p) {
    hit <- if (p == 0.05) bt$breach95 else bt$breach99
    tibble(date = bt$date, t = seq_len(m), S = cumsum(hit) - seq_len(m) * p, env = 1.96 * sqrt(seq_len(m) * p * (1 - p)),
           level_lab = paste0("Niveau ", round((1 - p) * 100), " %", ifelse(p == 0.01, " (diagnostic)", "")))
  }))
  g14 <- ggplot(cum, aes(date)) +
    geom_ribbon(aes(ymin = -env, ymax = env), fill = "grey80", alpha = 0.7) +
    geom_hline(yintercept = 0, color = "grey30") +
    geom_line(aes(y = S), color = COL_BR, linewidth = 0.7) +
    facet_wrap(~level_lab, scales = "free_y", ncol = 1) +
    labs(title = "Dépassements cumulés moins dépassements attendus",
         subtitle = str_wrap("Zone grise : ± 1,96 écart-type sous H0 (enveloppe ponctuelle, non simultanée). Une dérive soutenue hors de la zone signalerait une mauvaise calibration."),
         x = NULL, y = "Écart cumulé (nombre de jours)")
  save_fig(g14, "14_cumulative_breaches_vs_expected.png", w = 10, h = 7)
  
  # --- 15 : largeur de la fourchette et P(volatil) ------------------------------------------------------------------
  wd15 <- bt %>% transmute(date, `Largeur de la fourchette à 95 % (points de rendement, échelle log)` = q_high95 - q_low95,
                           `P(régime volatil) prévue (étiquette du fold)` = p_volatil) %>%
    pivot_longer(-date, names_to = "serie", values_to = "valeur") %>%
    mutate(serie = factor(serie, levels = unique(serie)))
  g15 <- ggplot(wd15, aes(date, valeur)) +
    geom_line(color = COL_BR, linewidth = 0.35) +
    facet_wrap(~serie, scales = "free_y", ncol = 1) +
    scale_y_continuous(trans = "identity") +
    labs(title = "La fourchette réagit-elle ? Largeur à 95 % et probabilité prévue du régime volatil",
         subtitle = str_wrap("En haut, la largeur de la bande (en points de log-rendement) ; en bas, la probabilité prévue du régime d'étiquette « volatil » (étiquette propre à chaque fold). La largeur dépend surtout de la variance conditionnelle, la probabilité de régime agissant sur la forme de la distribution.", 120),
         x = NULL, y = NULL)
  # echelle log pour le panneau de largeur seulement : on trace deux figures separees pour eviter une echelle commune
  g15a <- ggplot(bt, aes(date, q_high95 - q_low95)) + geom_line(color = COL_BR, linewidth = 0.35) +
    scale_y_log10() + labs(subtitle = "Largeur de la fourchette à 95 % (points de log-rendement, échelle log)", x = NULL, y = NULL)
  g15b <- ggplot(bt, aes(date, p_volatil)) + geom_line(color = "steelblue4", linewidth = 0.3) +
    scale_y_continuous(labels = function(x) fr_pct(x, 1), limits = c(0, 1)) +
    labs(subtitle = "P(régime volatil) prévue la veille (étiquette propre à chaque fold)", x = NULL, y = NULL)
  if (requireNamespace("patchwork", quietly = TRUE)) {
    library(patchwork)
    g15 <- (g15a / g15b) + plot_annotation(title = "La fourchette réagit-elle ? Largeur à 95 % et probabilité prévue du régime volatil",
                                           theme = theme(plot.title = element_text(face = "bold", size = 13)))
    save_fig(g15, "15_band_width_and_regime_prob.png", w = 10, h = 7)
  } else {
    save_fig(g15a + labs(title = "Largeur de la fourchette à 95 % au fil du temps"), "15a_band_width.png", w = 10, h = 4)
    save_fig(g15b + labs(title = "Probabilité prévue du régime volatil au fil du temps"), "15b_regime_prob.png", w = 10, h = 4)
  }
} else message("Figures 12 a 15 sautees : btc_backtest_daily.csv introuvable")

# ==============================================================================
# 16 — Evolution des parametres entre folds
# ==============================================================================
f_par <- file.path(PROC, "btc_backtest_params.csv")
if (file.exists(f_par)) {
  pr <- read_csv(f_par, col_types = cols())
  pt <- bind_rows(
    pr %>% transmute(year, regime = "volatil", metrique = "Persistance (alpha + beta)", valeur = ifelse(hv == 1, pers1, pers2)),
    pr %>% transmute(year, regime = "calme",   metrique = "Persistance (alpha + beta)", valeur = ifelse(hv == 1, pers2, pers1)),
    pr %>% transmute(year, regime = "volatil", metrique = "nu (degrés de liberté de la t)", valeur = ifelse(hv == 1, nu_1, nu_2)),
    pr %>% transmute(year, regime = "calme",   metrique = "nu (degrés de liberté de la t)", valeur = ifelse(hv == 1, nu_2, nu_1)))
  ref <- tibble(metrique = c("Persistance (alpha + beta)", "nu (degrés de liberté de la t)"), y = c(0.999, 4))
  g16 <- ggplot(pt, aes(year, valeur, color = regime)) +
    geom_hline(data = ref, aes(yintercept = y), linetype = "dashed", color = "grey40") +
    geom_line(linewidth = 0.8) + geom_point(size = 2.4) +
    facet_wrap(~metrique, scales = "free_y") +
    scale_color_manual(values = c(calme = "steelblue3", volatil = COL_BR), name = "Régime") +
    scale_x_continuous(breaks = sort(unique(pt$year))) +
    labs(title = "Paramètres estimés à chaque ré-estimation annuelle (année = premier jour de test)",
         subtitle = "Pointillés : persistance 0,999 (frontière IGARCH) et ν = 4 (kurtosis infinie en dessous). Estimation sur tout l'historique antérieur.",
         x = NULL, y = NULL) +
    theme(legend.position = "bottom", axis.text.x = element_text(angle = 45, hjust = 1))
  save_fig(g16, "16_params_by_fold.png", w = 10, h = 4.8)
  
  # --- 17 : matrice de transition par fold (a lire avec la figure 16) -----------------------------------------------
  # Cherche les probabilites de transition dans btc_backtest_params.csv (K = 2 : deux parametres libres par fold).
  pick <- function(cands) { h <- intersect(cands, names(pr)); if (length(h)) h[1] else NA_character_ }
  c11 <- pick(c("P_1_1", "p11", "P11", "p_11", "p_1_1"))   # probabilite de rester dans l'etat 1
  c22 <- pick(c("P_2_2", "p22", "P22", "p_22", "p_2_2"))   # probabilite de rester dans l'etat 2
  c21 <- pick(c("P_2_1", "p21", "P21", "p_21", "p_2_1"))   # probabilite de passer de l'etat 2 a l'etat 1
  if (!is.na(c11) && (!is.na(c22) || !is.na(c21))) {
    p11 <- pr[[c11]]
    p22 <- if (!is.na(c22)) pr[[c22]] else 1 - pr[[c21]]
    stay_v <- ifelse(pr$hv == 1, p11, p22)   # reste volatil (hv = 1 : l'etat 1 est le volatil)
    stay_c <- ifelse(pr$hv == 1, p22, p11)   # reste calme
    lab_f  <- paste0(pr$year, " : durée espérée calme ", round(1 / (1 - stay_c)), " j, volatil ", round(1 / (1 - stay_v)), " j")
    tm <- bind_rows(
      tibble(fold = lab_f, year = pr$year, from = "calme",   to = "calme",   prob = stay_c),
      tibble(fold = lab_f, year = pr$year, from = "calme",   to = "volatil", prob = 1 - stay_c),
      tibble(fold = lab_f, year = pr$year, from = "volatil", to = "calme",   prob = 1 - stay_v),
      tibble(fold = lab_f, year = pr$year, from = "volatil", to = "volatil", prob = stay_v)) %>%
      mutate(fold = factor(fold, levels = unique(fold[order(year)])))
    g17 <- ggplot(tm, aes(from, to, fill = prob)) +
      geom_tile(color = "white", linewidth = 0.8) +
      geom_text(aes(label = fr_pct(prob, 0.1), color = prob > 0.6), size = 3.2, show.legend = FALSE) +
      scale_color_manual(values = c(`TRUE` = "white", `FALSE` = "black")) +
      scale_fill_gradient(low = "white", high = COL_BR, limits = c(0, 1), labels = function(x) fr_pct(x, 1), name = "Probabilité") +
      scale_x_discrete(limits = c("calme", "volatil")) + scale_y_discrete(limits = c("volatil", "calme")) +
      facet_wrap(~fold, ncol = 3) +
      labs(title = "Matrice de transition par ré-estimation annuelle (MS-GARCH, K = 2)",
           subtitle = "Colonne = régime au jour t, ligne = régime au jour t+1. Le titre de chaque panneau donne la durée espérée de chaque régime.",
           x = "Régime au jour t", y = "Régime au jour t+1")
    save_fig(g17, "17_transition_by_fold.png", w = 11, h = 8)
  } else message("Figure 17 sautee : aucune colonne de probabilite de transition dans ", f_par,
                 " (colonnes presentes : ", paste(names(pr), collapse = ", "), ")")
} else message("Figure 16 sautee : btc_backtest_params.csv introuvable")

cat("Terminé — figures dans", OUT, "\n")
if (length(FAILED)) cat("FIGURES NON ECRITES :", paste(FAILED, collapse = ", "), "\n")