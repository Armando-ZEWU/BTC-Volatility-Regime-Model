# covid_shock_test_btc.R  --  Etape 6 (Option 2 BTC) : test de choc QUALITATIF, mars 2020
# Calque de covid_robustness_test.R (EUR/USD, Covid_Robustness_Test.md). Statut (Summary 4.5) : hors critere de succes.
# Design : modele MS-GARCH(K=2) RE-ESTIME sur les donnees jusqu'au 2019-12-31 (jamais exposees au choc), puis GELE ;
#          prevision a 1 jour sur chaque jour du 2020-01-01 au 2020-04-30 (121 jours), historique etendu jour apres jour.
# Differences declarees :
#   D1. Marche 7j/7 : 121 jours (EUR/USD : 84 jours de bourse). Attendus a 95 % : ~6.05 depassements ; a 99 % : ~1.21.
#   D2. Ajustement pre-2020 par multi-departs (defaut + perturbes + "regimes persistants"), pas par un seul depart :
#       l'etape 3 a montre que le depart par defaut ne trouve pas l'optimum global.
#   D3. Le niveau 99 % est rapporte (diagnostic valide en O3).
#   D4. Diagnostic intrajournalier High/Low depuis la MEME source (yfinance) : pas de decalage inter-sources
#       (l'EUR/USD comparait FRED a Pound Sterling Live). Non decisif.
#   D5. Tests : binomial unilateral (comme l'EUR/USD) + Kupiec bilateral ; Christoffersen indique si calculable.
# Emplacement : OPTION 2/code/covid_shock_test_btc.R  (working directory = code/ ou OPTION 2/)

wd   <- normalizePath(getwd(), winslash = "/")
ROOT <- if (basename(wd) == "code") dirname(wd) else wd
PROC <- file.path(ROOT, "data", "processus"); RAW <- file.path(ROOT, "data", "raw")
stopifnot("Dossier data/processus introuvable : lancer depuis code/ ou OPTION 2/" = dir.exists(PROC))
source(file.path(ROOT, "code", "msgarch_utils_btc.R"))

CUT_PRE   <- as.Date("2019-12-31")
WIN_START <- as.Date("2020-01-01"); WIN_END <- as.Date("2020-04-30")
ALPHAS    <- c(0.005, 0.025, 0.975, 0.995)       # 99 % bas, 95 % bas, 95 % haut, 99 % haut

# ---- 1. Donnees ---------------------------------------------------------------------------------
dat <- read.csv(file.path(PROC, "btc_log_returns.csv"), stringsAsFactors = FALSE)
px  <- read.csv(file.path(PROC, "btc_close_clean.csv"), stringsAsFactors = FALSE)
dates <- as.Date(dat$Date); ret <- dat$log_return * 100; n <- length(ret)
pre <- dates <= CUT_PRE; n_pre <- sum(pre)
win <- which(dates >= WIN_START & dates <= WIN_END)
cat("Pre-2020 :", format(min(dates)), "->", format(max(dates[pre])), "| n =", n_pre, "(attendu 1931)\n")
cat("Fenetre  :", format(dates[win[1]]), "->", format(dates[tail(win, 1)]), "| n =", length(win), "(attendu 121)\n")
stopifnot(length(win) == 121, max(dates[pre]) + 1 == WIN_START)

# ---- 2. Re-estimation pre-2020 (jamais exposee au choc), puis gel ------------------------------------------
spec2 <- make_spec2()
ret_pre <- ret[pre]
cat("\nAjustement MS-GARCH pre-2020 (multi-departs)...\n")
fp <- fit_best(ret_pre, spec2)
cat("Ajustements :", fp$n_fits, "| meilleur :", fp$best, "| LL =", round(fp$loglik, 2),
    "| optima distincts (LL arrondie a 0.5) :", length(unique(round(2 * fp$ll_all) / 2)), "\n")
print(round(fp$par, 5))
fl <- flags_fit(fp$par, fp$MatCoef)
cat("\n--- Drapeaux du modele pre-2020 (Summary 4.2) ---\n"); print(fl, row.names = FALSE)
sm_pre <- smooth_probs(spec2, fp$par, ret_pre)
hv_info <- hv_from_sm(sm_pre, ret_pre); hv <- hv_info$hv; lv <- 3L - hv
cat("Regime volatil (pre-2020) = indice", hv, "| ecart-type realise sur jours dominants :", round(hv_info$sd_by, 3), "\n")
saveRDS(list(par = fp$par, loglik = fp$loglik, MatCoef = fp$MatCoef, highvol_index = hv, best_fit = fp$best),
        file.path(PROC, "btc_covid_pre2020_par.rds"))

# ---- 3. Prevision a 1 jour, parametres GELES -------------------------------------------------------------------------
set.seed(42)
res <- do.call(rbind, lapply(seq_along(win), function(j) {
  d <- win[j]
  out <- tryCatch({
    f <- forecast_1d(spec2, fp$par, ret[1:(d - 1)], ALPHAS)
    data.frame(date = dates[d], ret = ret[d], q_low99 = f$q[1], q_low95 = f$q[2], q_high95 = f$q[3], q_high99 = f$q[4],
               p_volatil = f$w[hv], method = f$method, reason = f$reason, ok = TRUE)
  }, error = function(e) data.frame(date = dates[d], ret = ret[d], q_low99 = NA, q_low95 = NA, q_high95 = NA,
                                    q_high99 = NA, p_volatil = NA, method = "echec", reason = conditionMessage(e), ok = FALSE))
  if (j %% 20 == 0) cat("  jour", j, "/", length(win), "\n")
  out
}))
cat("Previsions reussies :", sum(res$ok), "/", nrow(res), "\n")
if (any(!res$ok)) { cat(">>> ATTENTION : jours SANS prevision :", format(res$date[!res$ok]), "\n")
  print(res[!res$ok, c("date", "reason")], row.names = FALSE) }
if (any(res$method == "exact")) { cat(">>> Jours calcules par REPLI (melange exact, Risk() en echec ou incoherent) :\n")
  print(res[res$method == "exact", c("date", "ret", "q_low95", "q_high95", "reason")], row.names = FALSE, digits = 4) }
res <- res[res$ok, ]

# ---- 4. Couverture ---------------------------------------------------------------------------------------------------------------
res$breach95 <- res$ret < res$q_low95 | res$ret > res$q_high95
res$breach99 <- res$ret < res$q_low99 | res$ret > res$q_high99
res$dir <- ifelse(res$ret < res$q_low95, "bas", ifelse(res$ret > res$q_high95, "haut", ""))
res$size_pp <- ifelse(res$ret < res$q_low95, res$q_low95 - res$ret, ifelse(res$ret > res$q_high95, res$ret - res$q_high95, 0))
m <- nrow(res); x95 <- sum(res$breach95); x99 <- sum(res$breach99)
summ <- function(x, p, hit) {
  k <- kupiec_pof(x, m, p); ch <- christoffersen_ind(hit)
  data.frame(n = m, breaches = x, expected = round(m * p, 2), coverage = round(1 - x / m, 4),
             binom_one_sided_p = binom_greater(x, m, p), kupiec_LR = k[["LR"]], kupiec_p = k[["p_value"]],
             christoffersen_p = ch[["p_value"]])
}
s95 <- summ(x95, 0.05, res$breach95); s99 <- summ(x99, 0.01, res$breach99)
cat("\n=== COUVERTURE A 95 % (cible 95 %) ===\n"); print(s95, row.names = FALSE, digits = 4)
cat("\n=== COUVERTURE A 99 % (diagnostic, cible 99 %) ===\n"); print(s99, row.names = FALSE, digits = 4)
cat("\nLecture : test QUALITATIF (Summary 4.5). Avec n =", m, "la puissance est faible : une absence de rejet\n",
    "n'est pas une validation, et un rejet isole ne serait pas decisif.\n")
cat("\n=== DEPASSEMENTS A 95 % (P(volatil) = probabilite du regime d'etiquette 'volatil' au moment de la prevision) ===\n")
print(res[res$breach95, c("date", "ret", "q_low95", "q_high95", "dir", "size_pp", "p_volatil")], row.names = FALSE, digits = 4)

# ---- 5. Diagnostic intrajournalier High/Low (meme source, non decisif) -----------------------------------------------------------
raw_f <- file.path(RAW, "btc_usd_yfinance_raw.csv"); intr <- NULL
if (file.exists(raw_f)) {
  raw <- read.csv(raw_f, stringsAsFactors = FALSE)
  if (all(c("High", "Low") %in% names(raw))) {
    raw$Date <- as.Date(raw[[1]]); pxd <- as.Date(px[[1]])
    prev_close <- px[[2]][match(res$date - 1, pxd)]
    up <- prev_close * exp(res$q_high95 / 100); lo <- prev_close * exp(res$q_low95 / 100)
    hi_d <- raw$High[match(res$date, raw$Date)]; lo_d <- raw$Low[match(res$date, raw$Date)]
    res$high_touch <- hi_d > up; res$low_touch <- lo_d < lo
    res$any_outside <- res$breach95 | res$high_touch | res$low_touch
    intr <- data.frame(close_breaches = sum(res$breach95), high_above = sum(res$high_touch, na.rm = TRUE),
                       low_below = sum(res$low_touch, na.rm = TRUE), unique_days_outside = sum(res$any_outside, na.rm = TRUE), n = m)
    cat("\n=== INTRAJOURNALIER (95 %, bornes en prix depuis la cloture veille ; non decisif) ===\n"); print(intr, row.names = FALSE)
  }
}

# ---- 6. Sorties ----------------------------------------------------------------------------------------------------------------------------
write.csv(res, file.path(PROC, "btc_covid_result.csv"), row.names = FALSE)
write.csv(rbind(cbind(level = 0.95, s95), cbind(level = 0.99, s99)), file.path(PROC, "btc_covid_summary.csv"), row.names = FALSE)
if (!is.null(intr)) write.csv(intr, file.path(PROC, "btc_covid_intraday.csv"), row.names = FALSE)
write.csv(flags_fit(fp$par, fp$MatCoef), file.path(PROC, "btc_covid_pre2020_flags.csv"), row.names = FALSE)
cat("\nSorties ecrites dans", PROC, "\nRelire TOUT ce qui precede avant de conclure.\n")