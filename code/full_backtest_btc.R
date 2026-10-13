# full_backtest_btc.R  --  Etape 7 (Option 2 BTC) : backtest en fenetre extensive = LE pass/fail de l'Option 2
# Calque de full_backtest.R (EUR/USD, Full_Backtest.md). Criteres (Summary 4.1), fixes AVANT toute estimation :
#   - n de previsions hors-echantillon >= 2500 ; Kupiec bilateral NON rejete a 5 % ; Christoffersen NON rejete a 5 %
#   - couverture a 99 % : rapportee, SANS pass/fail (O3) ; binomial unilateral : rapporte, non decisif (comparabilite EUR/USD)
# Design (O2, valide) : estimation initiale 2014-09-18 -> 2017-12-31 ; test annuel 2018 -> 2026 (2026 partielle) ;
#   chaque 1er janvier : re-estimation sur TOUT l'historique anterieur, puis parametres GELES pendant l'annee ;
#   chaque jour : filtre + prevision a 1 jour avec l'historique jusqu'a la veille (aucune information future).
# Differences declarees :
#   D1. Rendements en %, moyenne nulle (O4). Marche 7j/7 : ~3 190 previsions (EUR/USD : 3 424).
#   D2. Ajustement par fold en multi-departs (depart chaud = fold precedent + defaut + perturbes + "regimes persistants").
#   D3. Repli sur le melange EXACT si Risk() echoue (cas observe le 2020-03-14) ; methode et raison consignees par jour.
#   D4. Niveau 99 % calcule en meme temps (diagnostic).  D5. Sauvegarde incrementale par fold + reprise (RESUME).
# Emplacement : OPTION 2/code/full_backtest_btc.R  (working directory = code/ ou OPTION 2/)

wd   <- normalizePath(getwd(), winslash = "/")
ROOT <- if (basename(wd) == "code") dirname(wd) else wd
PROC <- file.path(ROOT, "data", "processus")
stopifnot("Dossier data/processus introuvable : lancer depuis code/ ou OPTION 2/" = dir.exists(PROC))
source(file.path(ROOT, "code", "msgarch_utils_btc.R"))

YEARS  <- 2018:2026
RESUME <- TRUE          # TRUE : reprend les folds deja calcules ; FALSE : tout recalculer
N_PERT <- 2; N_PERS <- 6
ALPHAS <- c(0.005, 0.025, 0.975, 0.995)
PAR_NAMES <- c("alpha0_1", "alpha1_1", "beta_1", "nu_1", "alpha0_2", "alpha1_2", "beta_2", "nu_2", "P_1_1", "P_2_1")

dat <- read.csv(file.path(PROC, "btc_log_returns.csv"), stringsAsFactors = FALSE)
dates <- as.Date(dat$Date); ret <- dat$log_return * 100; n <- length(ret)
yr <- as.integer(format(dates, "%Y"))
spec2 <- make_spec2()
cat("Donnees :", format(min(dates)), "->", format(max(dates)), "| n =", n, "\n")
cat("Previsions attendues :", sum(yr %in% YEARS), "(critere : >= 2500)\n")

par_prev <- NULL; folds <- list(); par_rows <- list(); t0 <- Sys.time()
for (Y in YEARS) {
  f_days <- file.path(PROC, sprintf("btc_backtest_fold_%d.csv", Y)); f_par <- file.path(PROC, sprintf("btc_backtest_par_%d.csv", Y))
  est <- which(dates < as.Date(sprintf("%d-01-01", Y))); win <- which(yr == Y)
  if (RESUME && file.exists(f_days) && file.exists(f_par)) {
    cat(sprintf("\n=== Fold %d : repris depuis le disque ===\n", Y))
    folds[[as.character(Y)]] <- read.csv(f_days, stringsAsFactors = FALSE)
    pr <- read.csv(f_par, stringsAsFactors = FALSE); par_rows[[as.character(Y)]] <- pr
    par_prev <- unlist(pr[1, PAR_NAMES]); next
  }
  cat(sprintf("\n=== Fold %d : estimation sur %d rendements (%s -> %s), test sur %d jours ===\n", Y, length(est),
              format(dates[est[1]]), format(dates[tail(est, 1)]), length(win)))
  fp <- fit_best(ret[est], spec2, par0_list = if (!is.null(par_prev)) list(prev = par_prev) else list(), n_pert = N_PERT, n_pers = N_PERS)
  fl <- flags_fit(fp$par, fp$MatCoef)
  hv <- hv_from_sm(smooth_probs(spec2, fp$par, ret[est]), ret[est])$hv
  cat(sprintf("  %d ajustements | meilleur : %s | LL = %.2f | persistance : %.5f / %.5f | nu : %.2f / %.2f | volatil = indice %d\n",
              fp$n_fits, fp$best, fp$loglik, fl$persistence[1], fl$persistence[2], fl$nu[1], fl$nu[2], hv))
  if (any(fl$flag_persistence_gt_0.999) || any(fl$flag_se_nu_gt_nu)) cat("  >>> DRAPEAUX :", paste(names(fl)[5:6][c(any(fl$flag_persistence_gt_0.999), any(fl$flag_se_nu_gt_nu))], collapse = ", "), "\n")
  pr <- data.frame(year = Y, best = fp$best, loglik = fp$loglik, n_est = length(est), n_fits = fp$n_fits, hv = hv,
                   t(fp$par)[, PAR_NAMES, drop = FALSE], pers1 = fl$persistence[1], pers2 = fl$persistence[2],
                   flag_pers = any(fl$flag_persistence_gt_0.999), flag_se_nu = any(fl$flag_se_nu_gt_nu))
  par_rows[[as.character(Y)]] <- pr
  set.seed(42)
  day_res <- do.call(rbind, lapply(seq_along(win), function(j) {
    d <- win[j]
    out <- tryCatch({
      f <- forecast_1d(spec2, fp$par, ret[1:(d - 1)], ALPHAS)
      data.frame(date = dates[d], year = Y, ret = ret[d], q_low99 = f$q[1], q_low95 = f$q[2], q_high95 = f$q[3], q_high99 = f$q[4],
                 p_volatil = f$w[hv], method = f$method, reason = f$reason, ok = TRUE)
    }, error = function(e) data.frame(date = dates[d], year = Y, ret = ret[d], q_low99 = NA, q_low95 = NA, q_high95 = NA, q_high99 = NA,
                                      p_volatil = NA, method = "echec", reason = conditionMessage(e), ok = FALSE))
    if (j %% 100 == 0) cat(sprintf("  jour %d / %d | %.1f min ecoulees\n", j, length(win), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
    out
  }))
  write.csv(day_res, f_days, row.names = FALSE); write.csv(pr, f_par, row.names = FALSE)   # sauvegarde incrementale
  folds[[as.character(Y)]] <- day_res; par_prev <- fp$par
  cat(sprintf("  fold %d : %d/%d previsions ; %d par repli exact\n", Y, sum(day_res$ok), nrow(day_res), sum(day_res$method == "exact")))
}

# ---- Agregation ---------------------------------------------------------------------------------------------------------------------------
bt <- do.call(rbind, folds); params <- do.call(rbind, par_rows)
cat("\n=== PREVISIONS : ", nrow(bt), "| echecs :", sum(!bt$ok), "| replis exacts :", sum(bt$method == "exact"), "===\n")
if (any(!bt$ok)) { cat(">>> JOURS SANS PREVISION (exclus de la couverture ; biais possible) :\n"); print(bt[!bt$ok, c("date", "reason")], row.names = FALSE) }
if (any(bt$method == "exact")) { cat(">>> Jours en REPLI exact (raisons) :\n"); print(table(bt$reason[bt$method == "exact"])) }
bt <- bt[bt$ok, ]; m <- nrow(bt)
bt$breach95 <- bt$ret < bt$q_low95 | bt$ret > bt$q_high95
bt$breach99 <- bt$ret < bt$q_low99 | bt$ret > bt$q_high99
bt$dir95 <- ifelse(bt$ret < bt$q_low95, "bas", ifelse(bt$ret > bt$q_high95, "haut", ""))

summ <- function(hit, p) { x <- sum(hit); k <- kupiec_pof(x, m, p); ch <- christoffersen_ind(hit)
  data.frame(n = m, breaches = x, expected = round(m * p, 1), coverage = round(1 - x / m, 4), binom_one_sided_p = binom_greater(x, m, p),
             kupiec_LR = k[["LR"]], kupiec_p = k[["p_value"]], christoffersen_LR = ch[["LR"]], christoffersen_p = ch[["p_value"]]) }
s95 <- summ(bt$breach95, 0.05); s99 <- summ(bt$breach99, 0.01)
cat("\n=== COUVERTURE A 95 % ===\n"); print(s95, row.names = FALSE, digits = 4)
cat("\n=== COUVERTURE A 99 % (diagnostic, sans pass/fail) ===\n"); print(s99, row.names = FALSE, digits = 4)
cat(sprintf("\nDepassements bas / haut a 95 %% : %d / %d\n", sum(bt$dir95 == "bas"), sum(bt$dir95 == "haut")))

fold_tab <- do.call(rbind, lapply(split(bt, bt$year), function(g) data.frame(
  year = g$year[1], n = nrow(g), breaches95 = sum(g$breach95), coverage95 = round(1 - mean(g$breach95), 4),
  breaches99 = sum(g$breach99), coverage99 = round(1 - mean(g$breach99), 4), exact_days = sum(g$method == "exact"))))
fold_tab <- merge(fold_tab, params[, c("year", "pers1", "pers2", "nu_1", "nu_2", "flag_pers", "flag_se_nu")], by = "year")
cat("\n=== PAR FOLD ===\n"); print(fold_tab, row.names = FALSE, digits = 4)

# ---- Verdict mecanique (Summary 4.1) ----------------------------------------------------------------------------------------------------------
pass_n <- m >= 2500; pass_k <- s95$kupiec_p >= 0.05; pass_c <- !is.na(s95$christoffersen_p) && s95$christoffersen_p >= 0.05
cat("\n=== CRITERE 4.1 (mecanique) ===\n")
cat(sprintf("n >= 2500 : %s (%d) | Kupiec non rejete a 5 %% : %s (p = %.4f) | Christoffersen non rejete a 5 %% : %s (p = %.4f)\n",
            pass_n, m, pass_k, s95$kupiec_p, pass_c, s95$christoffersen_p))
cat("VERDICT 4.1 :", if (pass_n && pass_k && pass_c) "PASS" else "FAIL", "\n")
cat("Rappel 4.4 : succes de l'Option 2 = 4.1 passe ET 4.3 non classe 'ere' (etape 3 : PAS_ERE).\n")
cat("Rappel 4.1 : deux tests a 5 % => ~10 % de risque de faux rejet sur un modele parfaitement calibre (documente, non corrige).\n")

write.csv(bt, file.path(PROC, "btc_backtest_daily.csv"), row.names = FALSE)
write.csv(rbind(cbind(level = 0.95, s95), cbind(level = 0.99, s99)), file.path(PROC, "btc_backtest_summary.csv"), row.names = FALSE)
write.csv(fold_tab, file.path(PROC, "btc_backtest_fold_summary.csv"), row.names = FALSE)
write.csv(params, file.path(PROC, "btc_backtest_params.csv"), row.names = FALSE)
cat("\nSorties ecrites dans", PROC, "\nRelire TOUT ce qui precede avant de conclure.\n")
