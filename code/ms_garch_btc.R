# ms_garch_btc.R  --  Etape 3 (Option 2 BTC)  --  v3
# Markov-Switching GARCH(1,1) K=2, innovations Student's t, specification Haas,
# Mittnik & Paolella (2004a) via le package MSGARCH (Ardia et al., 2019).
# Calque de ms_garch.R (projet EUR/USD), avec les differences DECLAREES suivantes :
#   D1. Rendements en % (x100), comme l'etape 2 (Python) : omega lisible, optimisation mieux
#       conditionnee. alpha, beta, nu et P sont invariants a l'echelle.
#   D2. Benchmark GARCH-t a 1 regime estime DANS MSGARCH (moyenne nulle, meme echelle) :
#       comparaison LL/AIC/BIC a specification de moyenne identique (limite de l'EUR/USD).
#   D3. La regle 4.3 du Summary (regime vs ere) est appliquee MECANIQUEMENT, sur les
#       probabilites lissees, avec une variante tolerante en sensibilite.
#   D4. Probabilites FILTREES et chemin de Viterbi exportes (manque de l'EUR/USD).
#   D5. Redemarrages aleatoires du K=2. v2 : le MEILLEUR optimum parmi defaut + redemarrages
#       devient l'ajustement final (la v1 a montre que le defaut n'etait pas l'optimum : +3.09 LL).
#       Le verdict de la regle 4.3 est aussi rapporte pour chaque optimum quasi-optimal.
#   D7. v3 : correction d'un BUG de la v2 -- les redemarrages ecretaient P a [0.6, 0.995], donc TOUS
#       partaient de micro-regimes (P_stay ~ 0.6) et ne pouvaient pas explorer des regimes persistants.
#       Bruit desormais en logit ; + departs 'regimes persistants' (P_1_1 ~ 0.97-0.998, P_2_1 ~ 0.002-0.03).
#       Sensibilite rapportee pour TOUS les optima, avec la meilleure solution a regimes persistants.
#   D6. Verdicts renommes : ERE / PAS_ERE / AUCUN_JOUR_VOLATIL. "REGIME" (v1) laissait croire
#       qu'un regime avait ete trouve, alors que la regle ne detecte que l'ere.
#
# DEFINITION FIXEE AVANT RESULTATS : le regime "volatil" est celui dont les jours dominants
# (prob. lissee > 0.5) ont l'ecart-type realise le plus eleve. On n'utilise pas sigma de long
# terme omega/(1-alpha-beta), peu fiable pres de la frontiere IGARCH.
#
# Emplacement : OPTION 2/code/ms_garch_btc.R  (working directory = code/ ou OPTION 2/)

library(MSGARCH)

# ---- 0. Chemins -------------------------------------------------------------
wd   <- normalizePath(getwd(), winslash = "/")
ROOT <- if (basename(wd) == "code") dirname(wd) else wd
PROC <- file.path(ROOT, "data", "processus")
stopifnot("Dossier data/processus introuvable : lancer depuis code/ ou OPTION 2/" = dir.exists(PROC))
cat("ROOT =", ROOT, "\n")

RUN_RESTARTS <- TRUE
N_PERT       <- 8      # departs perturbes autour du defaut
N_PERS       <- 12     # departs 'regimes persistants'  (~ plusieurs minutes au total ; baisser pour tester)
MIN_RUN_TOL  <- 10     # variante tolerante (sensibilite UNIQUEMENT) : runs < 10 jours fusionnes
NEAR_OPT     <- 3      # optima a moins de 3 points de LL du meilleur : verdict rapporte aussi

# ---- 1. Fonctions utilitaires (regle 4.3, alignement des probabilites) -------------
apply_era_rule <- function(label, thr_share = 0.40) {
  r <- rle(label)
  n_switch <- length(r$lengths) - 1
  hv_runs  <- r$lengths[r$values]
  longest  <- if (length(hv_runs)) max(hv_runs) else 0
  era_a <- n_switch == 1
  era_b <- length(hv_runs) == 1 && (longest / length(label)) > thr_share
  list(n_switch = n_switch, n_hv_runs = length(hv_runs), longest_run = longest,
       share_hv_total = mean(label), share_longest = longest / length(label),
       era_a_single_switch = era_a, era_b_single_block_gt40 = era_b,
       verdict = if (mean(label) == 0) "AUCUN_JOUR_VOLATIL" else if (era_a || era_b) "ERE" else "PAS_ERE")
}
debounce <- function(x, min_len = 10) {   # fusionne les runs INTERIEURS plus courts que min_len
  repeat {
    r <- rle(x); L <- length(r$lengths)
    short <- which(r$lengths < min_len & seq_len(L) > 1 & seq_len(L) < L)
    if (!length(short)) break
    i <- short[which.min(r$lengths[short])]
    e <- cumsum(r$lengths); s <- e - r$lengths + 1
    x[s[i]:e[i]] <- !x[s[i]]
  }
  x
}
take_T <- function(arr, n, k) {          # gere les objets a T ou T+1 lignes
  m <- arr[, 1, k]
  if (length(m) == n + 1) m[2:(n + 1)] else if (length(m) == n) m else
    stop("Dimension inattendue de State() : ", length(m), " lignes pour n = ", n)
}
regime_summary <- function(sm, ret, Pm) {  # sm : n x 2 (probabilites lissees)
  assigned <- ifelse(sm[, 2] > 0.5, 2L, 1L)
  sd_by <- sapply(1:2, function(k) if (sum(assigned == k) > 1) sd(ret[assigned == k]) else NA_real_)
  hv <- if (all(is.na(sd_by))) 1L else which.max(sd_by); lv <- 3L - hv
  p_hv <- sm[, hv]; lab <- p_hv > 0.5
  dur <- 1 / (1 - diag(Pm))
  list(hv = hv, lv = lv, sd_by = sd_by, p_hv = p_hv, lab = lab, rule = apply_era_rule(lab),
       dur_hv = dur[hv], dur_lv = dur[lv], share_ambiguous = mean(pmax(sm[, 1], sm[, 2]) < 0.9))
}
sm_of_fit <- function(f, n) { s <- State(f); sapply(1:2, function(k) take_T(s$SmoothProb, n, k)) }

# ---- 2. Donnees -------------------------------------------------------------
dat <- read.csv(file.path(PROC, "btc_log_returns.csv"), stringsAsFactors = FALSE)
stopifnot(all(c("Date", "log_return") %in% names(dat)))
dates   <- as.Date(dat$Date)
ret_dec <- dat$log_return
ret     <- ret_dec * 100                       # D1
n       <- length(ret)
cat("Observations :", n, "|", format(min(dates)), "->", format(max(dates)), "\n")

# ---- 3. Specifications et estimation -------------------------------------------
spec2 <- CreateSpec(
  variance.spec     = list(model = "sGARCH"),
  distribution.spec = list(distribution = "std"),
  switch.spec       = list(do.mix = FALSE, K = 2)
)
spec1 <- CreateSpec(                            # D2 : 1 regime, meme famille
  variance.spec     = list(model = "sGARCH"),
  distribution.spec = list(distribution = "std")
)
cat("\nEstimation K=1 (benchmark)...\n"); fit1 <- FitML(spec = spec1, data = ret)
cat("\nEstimation K=2 (defaut)...\n");    fit2_default <- FitML(spec = spec2, data = ret)
cat("\n=== K=1 ===\n"); print(summary(fit1))

# ---- 4. Redemarrages (D5, D7) : le meilleur optimum devient l'ajustement final ---------------
all_fits <- list(default = fit2_default)
if (RUN_RESTARTS) {
  set.seed(20260930)
  base_par <- fit2_default$par
  lg <- function(p) qlogis(pmin(pmax(p, 1e-4), 1 - 1e-4))
  perturb <- function(p) {                      # (a) perturbations autour du defaut
    q <- p
    for (k in 1:2) {
      q[paste0("alpha0_", k)] <- p[paste0("alpha0_", k)] * exp(rnorm(1, 0, 0.4))
      b <- min(0.97, max(0.5, p[paste0("beta_", k)] + rnorm(1, 0, 0.05)))
      a <- min(0.25, max(0.01, p[paste0("alpha1_", k)] * exp(rnorm(1, 0, 0.4))))
      if (a + b > 0.995) a <- max(0.005, 0.995 - b)
      q[paste0("beta_", k)]   <- b
      q[paste0("alpha1_", k)] <- a
      q[paste0("nu_", k)]     <- min(60, max(2.5, p[paste0("nu_", k)] * exp(rnorm(1, 0, 0.3))))
    }
    iP <- grep("^P_", names(p))
    q[iP] <- plogis(lg(p[iP]) + rnorm(length(iP), 0, 0.8))   # v3 : bruit en logit (plus d'ecretage a 0.6)
    q
  }
  persistent_start <- function(p) {             # (b) departs a deux regimes persistants
    q <- p
    q["alpha0_1"] <- exp(runif(1, log(0.005), log(0.05)))   # regime 1 : calme (omega petit)
    q["alpha0_2"] <- exp(runif(1, log(0.1), log(2)))        # regime 2 : volatil (omega grand)
    for (k in 1:2) {
      a <- runif(1, 0.03, 0.15); b <- runif(1, 0.80, 0.94)
      if (a + b > 0.99) b <- 0.99 - a
      q[paste0("alpha1_", k)] <- a; q[paste0("beta_", k)] <- b
      q[paste0("nu_", k)] <- runif(1, 4, 12)
    }
    q["P_1_1"] <- runif(1, 0.97, 0.998)   # reste en regime 1
    q["P_2_1"] <- runif(1, 0.002, 0.03)   # quitte le regime 2 (rarement)
    q
  }
  try_fit <- function(par0) tryCatch(FitML(spec = spec2, data = ret, ctr = list(par0 = par0)), error = function(e) NULL)
  for (i in seq_len(N_PERT)) { f <- try_fit(perturb(base_par));          if (!is.null(f)) all_fits[[paste0("pert_", i)]] <- f }
  for (i in seq_len(N_PERS)) { f <- try_fit(persistent_start(base_par)); if (!is.null(f)) all_fits[[paste0("pers_", i)]] <- f }
}
ll_all <- sapply(all_fits, function(f) f$loglik)
best_name <- names(which.max(ll_all)); best_ll <- max(ll_all)
par_mat <- t(sapply(all_fits, function(f) f$par[names(fit2_default$par)]))
restart_tab <- data.frame(fit = names(all_fits), start = sub("_[0-9]+$", "", names(all_fits)), LL = ll_all, round(par_mat, 4), row.names = NULL)
cat("\n=== Optima trouves (", length(all_fits), "ajustements, tries par LL decroissante) ===\n")
print(restart_tab[order(-restart_tab$LL), ], row.names = FALSE)
cat("LL du defaut :", round(fit2_default$loglik, 3), "| meilleur :", round(best_ll, 3), "(", best_name, ")\n")
if (best_ll > fit2_default$loglik + 0.01) {
  cat(">>> Le defaut N'ETAIT PAS l'optimum. L'ajustement FINAL est :", best_name, "\n")
} else cat(">>> Le defaut est l'optimum retenu.\n")
fit2 <- all_fits[[best_name]]
write.csv(restart_tab, file.path(PROC, "btc_msgarch_restarts.csv"), row.names = FALSE)
restart_ll <- ll_all
cat("\n=== K=2 (ajustement FINAL) ===\n"); print(summary(fit2))

# ---- 5. Criteres (calcul manuel, robuste aux versions du package) ---------------------
ic <- function(fit) {
  k <- length(fit$par); ll <- fit$loglik
  c(k = k, LL = ll, AIC = -2 * ll + 2 * k, BIC = -2 * ll + k * log(n))
}
ic_tab <- rbind(K1 = ic(fit1), K2 = ic(fit2))
cat("\n=== Comparaison K=1 vs K=2 (meme echelle, moyenne nulle) ===\n"); print(round(ic_tab, 2))
cat("AIC favorise :", rownames(ic_tab)[which.min(ic_tab[, "AIC"])],
    "| BIC favorise :", rownames(ic_tab)[which.min(ic_tab[, "BIC"])], "\n")
cat("NB : le test du rapport de vraisemblance K=1 vs K=2 est non standard (parametres non\n",
    "identifies sous H0) ; AIC/BIC sont des reperes, pas des tests.\n")
cat("NB : la colonne 'Pr(>|t|)' de MSGARCH est UNILATERALE (p bilateral = 2 x la valeur affichee).\n")

# ---- 6. Parametres, drapeaux (seuils du Summary 4.2) ------------------------------------
mc <- as.data.frame(fit2$Inference$MatCoef)
names(mc) <- c("Estimate", "SE", "t", "p")[seq_len(ncol(mc))]
get <- function(nm, col = "Estimate") mc[nm, col]
flag_rows <- lapply(1:2, function(k) {
  a <- get(paste0("alpha1_", k)); b <- get(paste0("beta_", k))
  nu <- get(paste0("nu_", k)); nu_se <- get(paste0("nu_", k), "SE")
  pers <- a + b
  data.frame(regime_index = k, omega = get(paste0("alpha0_", k)), alpha = a, beta = b,
             persistence = pers,
             half_life_days = ifelse(pers < 1, log(0.5) / log(pers), Inf),
             nu = nu, nu_se = nu_se,
             flag_persistence_gt_0.999 = pers > 0.999,
             flag_se_nu_gt_nu = !is.na(nu_se) && nu_se > nu,
             flag_nu_le_4 = nu <= 4)
})
par_tab <- do.call(rbind, flag_rows)
cat("\n=== Parametres par regime (indices bruts MSGARCH) ===\n"); print(par_tab, digits = 4)
P  <- TransMat(fit2)
cat("\n=== Matrice de transition (indices bruts) ===\n"); print(P)

# ---- 7. Probabilites de regime ---------------------------------------------------------------
st <- State(fit2)
cat("\n=== Structure de State() (verifiee en v1 : Filt T, Pred T+1, Smooth T+1, Viterbi T) ===\n")
str(st)
sm  <- sapply(1:2, function(k) take_T(st$SmoothProb, n, k))
fl  <- sapply(1:2, function(k) take_T(st$FiltProb,   n, k))
vit <- tryCatch(as.integer(st$Viterbi)[seq_len(n)], error = function(e) rep(NA_integer_, n))

# ---- 8. Regime volatil = ecart-type realise le plus eleve sur ses jours dominants -----------
Pm <- as.matrix(P)
rs <- regime_summary(sm, ret, Pm)
hv <- rs$hv; lv <- rs$lv; sd_by <- rs$sd_by
cat("\nEcart-type realise sur jours dominants (%/jour) : regime 1 =", round(sd_by[1], 3),
    "| regime 2 =", round(sd_by[2], 3), "=> regime VOLATIL = regime", hv, "\n")
cat("Duree esperee 1/(1-P_kk) : volatil =", round(rs$dur_hv, 1), "jours | calme =", round(rs$dur_lv, 1), "jours\n")
cat("Part de jours ambigus (max des probabilites lissees < 0.9) :", round(100 * rs$share_ambiguous, 1), "%\n")
prob_hv_smooth <- rs$p_hv; prob_hv_filt <- fl[, hv]

# ---- 9. Regle 4.3 (gelee) : "ere" si bascule unique OU bloc volatil unique > 40 % -----------
lab_strict  <- rs$lab
lab_tol     <- debounce(lab_strict, MIN_RUN_TOL)
rule_strict <- rs$rule
rule_tol    <- apply_era_rule(lab_tol)
cat("\n=== REGLE 4.3 (verdict CONTRAIGNANT = version stricte, ajustement FINAL) ===\n")
cat("STRICTE   :", paste(names(rule_strict), unlist(rule_strict), sep = "=", collapse = " | "), "\n")
cat("TOLERANTE (sensibilite, runs <", MIN_RUN_TOL, "j fusionnes) :",
    paste(names(rule_tol), unlist(rule_tol), sep = "=", collapse = " | "), "\n")
if (rule_tol$verdict == "AUCUN_JOUR_VOLATIL" && rule_strict$verdict != "AUCUN_JOUR_VOLATIL")
  cat(">>> Variante tolerante DEGENEREE : tous les blocs volatils sont plus courts que", MIN_RUN_TOL, "jours.\n")
if (rule_strict$verdict != rule_tol$verdict)
  cat(">>> Les deux versions DIVERGENT : verdict fragile, a documenter tel quel (la version stricte reste celle de la regle).\n")

r <- rle(lab_strict); e <- cumsum(r$lengths); s <- e - r$lengths + 1
runs_df <- data.frame(highvol = r$values, start = dates[s], end = dates[e], days = r$lengths)
cat("\n=== Runs (15 plus longs, tous regimes confondus) ===\n")
print(head(runs_df[order(-runs_df$days), ], 15), row.names = FALSE)

# ---- 9b. Sensibilite : TOUS les optima trouves (verdict NON contraignant) -------------------------
sens <- do.call(rbind, lapply(names(all_fits), function(nm) {
  f <- all_fits[[nm]]
  tryCatch({
    r_ <- regime_summary(sm_of_fit(f, n), ret, as.matrix(TransMat(f)))
    data.frame(fit = nm, start = sub("_[0-9]+$", "", nm), LL = round(f$loglik, 2),
               near_opt = f$loglik >= best_ll - NEAR_OPT, verdict = r_$rule$verdict,
               n_switch = r_$rule$n_switch, n_hv_runs = r_$rule$n_hv_runs, longest_run = r_$rule$longest_run,
               share_hv_total = round(r_$rule$share_hv_total, 4),
               dur_hv = round(r_$dur_hv, 1), dur_lv = round(r_$dur_lv, 1),
               share_ambiguous = round(r_$share_ambiguous, 3))
  }, error = function(e) NULL)
}))
cat("\n=== SENSIBILITE : regle 4.3 et durees pour TOUS les optima (near_opt = a <", NEAR_OPT, "LL du meilleur) ===\n")
if (!is.null(sens)) {
  print(sens[order(-sens$LL), ], row.names = FALSE)
  no <- sens[sens$near_opt, ]
  if (length(unique(no$verdict)) > 1) cat(">>> Le verdict DEPEND de l'optimum parmi les quasi-optimaux : conclusion fragile.\n")
  pers <- sens[sens$dur_hv >= 20 & sens$dur_lv >= 20, ]   # seuil DESCRIPTIF, non contraignant
  if (nrow(pers)) {
    bp <- pers[which.max(pers$LL), ]
    cat(">>> Meilleure solution a DEUX regimes persistants (durees >= 20 j) :", bp$fit, "| LL =", bp$LL,
        "| ecart au meilleur =", round(bp$LL - best_ll, 2), "\n")
  } else cat(">>> AUCUNE solution a deux regimes persistants (durees >= 20 j) parmi les", nrow(sens), "optima trouves.\n")
  write.csv(sens, file.path(PROC, "btc_msgarch_optima_sensitivity.csv"), row.names = FALSE)
}

# ---- 10. Sorties (tout en numerique/CSV, jamais l'objet fit) --------------------------------
ord <- c(lv, hv)
P_ord <- Pm[ord, ord, drop = FALSE]
dimnames(P_ord) <- list(from = c("calme", "volatil"), to = c("calme", "volatil"))
write.csv(P_ord, file.path(PROC, "btc_msgarch_transition_matrix.csv"), row.names = TRUE)

out <- data.frame(Date = dates, log_return = ret_dec,
                  prob_highvol_smoothed = prob_hv_smooth, prob_lowvol_smoothed = sm[, lv],
                  prob_highvol_filtered = prob_hv_filt,
                  viterbi_raw = vit, highvol_index = hv,
                  label_highvol_strict = lab_strict, label_highvol_tol = lab_tol)
write.csv(out, file.path(PROC, "btc_msgarch_regime_probs.csv"), row.names = FALSE)

par_tab$regime <- ifelse(par_tab$regime_index == hv, "volatil", "calme")
par_tab$sd_realise_jours_dominants <- sd_by[par_tab$regime_index]
write.csv(par_tab, file.path(PROC, "btc_msgarch_params_flags.csv"), row.names = FALSE)
write.csv(as.data.frame(ic_tab), file.path(PROC, "btc_msgarch_ic_comparison.csv"), row.names = TRUE)
write.csv(rbind(cbind(version = "stricte", as.data.frame(rule_strict)),
                cbind(version = "tolerante", as.data.frame(rule_tol))),
          file.path(PROC, "btc_msgarch_era_rule.csv"), row.names = FALSE)
write.csv(runs_df, file.path(PROC, "btc_msgarch_highvol_runs.csv"), row.names = FALSE)
write.csv(data.frame(highvol_index = hv, sd_volatil = sd_by[hv], sd_calme = sd_by[lv],
                     dur_volatil_j = rs$dur_hv, dur_calme_j = rs$dur_lv,
                     share_ambiguous = rs$share_ambiguous, best_fit = best_name,
                     LL_final = fit2$loglik, LL_default = fit2_default$loglik),
          file.path(PROC, "btc_msgarch_regime_descriptives.csv"), row.names = FALSE)
saveRDS(list(par = fit2$par, loglik = fit2$loglik, MatCoef = fit2$Inference$MatCoef,
             par_K1 = fit1$par, loglik_K1 = fit1$loglik, restart_ll = restart_ll,
             highvol_index = hv, best_fit = best_name),
        file.path(PROC, "btc_msgarch_par.rds"))
cat("\nSorties ecrites dans", PROC, "\nRelire TOUT ce qui precede avant de conclure.\n")