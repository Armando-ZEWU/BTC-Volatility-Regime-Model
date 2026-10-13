# ms_garch_forecast_btc.R  --  Etape 5 (Option 2 BTC) : fourchette de prix a 1 jour
# Calque de ms_garch_forecast.R (EUR/USD, decrit dans Price_Range.md), avec les differences DECLAREES :
#   D1. Rendements en % (x100), comme les etapes 2-3. Les quantiles de rendement sortent en % de log-rendement.
#   D2. Niveaux : 20/50/80/95 % (eventail, comme l'EUR/USD) + 99 % (diagnostic, valide en O3).
#   D3. Quantiles EXACTS du melange (resolution numerique de F(q) = p) compares a ceux de Risk()
#       (grille numerique) : verification chiffree de la grille, non faite avec cette precision sur l'EUR/USD.
#   D4. L'initialisation de la recursion de variance par regime n'est PAS supposee : trois candidates sont
#       comparees a predict()$vol (le melange pondere doit retrouver predict()$vol, cf. Price_Range.md 4.1).
# Regles du package respectees (Price_Range.md 2.2-2.3) :
#   - alpha de Risk() = niveaux de la queue GAUCHE : un intervalle bilateral a 95 % = c(0.025, 0.975)
#   - jamais de saveRDS() d'un objet fit (pointeur C++ mort) : seul le vecteur numerique `par` est relu
#   - State() et Risk() prennent `data`, predict() prend `newdata`
# Emplacement : OPTION 2/code/ms_garch_forecast_btc.R  (working directory = code/ ou OPTION 2/)

library(MSGARCH)

# ---- 0. Chemins -------------------------------------------------------------
wd   <- normalizePath(getwd(), winslash = "/")
ROOT <- if (basename(wd) == "code") dirname(wd) else wd
PROC <- file.path(ROOT, "data", "processus")
stopifnot("Dossier data/processus introuvable : lancer depuis code/ ou OPTION 2/" = dir.exists(PROC))

# ---- helpers (testes hors MSGARCH) -----------------------------------------------
reg_recursion <- function(r, om, a, b, init) {      # variance au jour n+1 (Haas et al. 2004a)
  s2 <- init
  for (t in seq_along(r)) s2 <- om + a * r[t]^2 + b * s2
  s2
}
t_scale <- function(nu) sqrt((nu - 2) / nu)           # t de Student standardisee (variance 1), nu > 2
mix_cdf <- function(x, w, sig, nu) sum(w * pt(x / (sig * t_scale(nu)), nu))
mix_quantile <- function(p, w, sig, nu) {
  uniroot(function(x) mix_cdf(x, w, sig, nu) - p, interval = c(-1e5, 1e5), tol = 1e-12)$root
}
regime_quantile <- function(p, sig, nu) qt(p, nu) * t_scale(nu) * sig
# ---- fin helpers -------------------------------------------------------------------

# ---- 1. Donnees et parametres ------------------------------------------------------
dat <- read.csv(file.path(PROC, "btc_log_returns.csv"), stringsAsFactors = FALSE)
px  <- read.csv(file.path(PROC, "btc_close_clean.csv"), stringsAsFactors = FALSE)
dates <- as.Date(dat$Date); ret <- dat$log_return * 100; n <- length(ret)
last_date <- dates[n]
last_price <- px[[2]][as.Date(px[[1]]) == last_date]
if (length(last_price) != 1) stop("Prix introuvable ou ambigu pour ", format(last_date), " : fichiers desynchronises ?")
cat("Derniere date :", format(last_date), "| dernier prix :", last_price, "| n =", n, "\n")

sv <- readRDS(file.path(PROC, "btc_msgarch_par.rds"))
par <- sv$par; hv <- sv$highvol_index; lv <- 3L - hv
cat("Ajustement final retenu a l'etape 3 :", sv$best_fit, "| LL =", round(sv$loglik, 2),
    "| regime volatil = indice", hv, "\n")

spec2 <- CreateSpec(                                  # nouvelle spec (pointeur C++ valide)
  variance.spec     = list(model = "sGARCH"),
  distribution.spec = list(distribution = "std"),
  switch.spec       = list(do.mix = FALSE, K = 2)
)

# ---- 2. Probabilites de regime pour le jour suivant -----------------------------------
st <- State(object = spec2, par = par, data = ret)
cat("\n--- str(State) ---\n"); str(st)
if (dim(st$PredProb)[1] != n + 1) stop("PredProb : ", dim(st$PredProb)[1], " lignes, attendu ", n + 1)
w_next <- as.numeric(st$PredProb[n + 1, 1, ])         # indices bruts (k=1, k=2)
cat("P(regime volatil demain) =", round(w_next[hv], 4), "| P(regime calme demain) =", round(w_next[lv], 4), "\n")

# ---- 3. Fourchette du melange via Risk() ----------------------------------------------------
levels_all <- c(0.20, 0.50, 0.80, 0.95, 0.99)
alpha_lo   <- (1 - levels_all) / 2
alphas     <- sort(c(alpha_lo, 1 - alpha_lo))
set.seed(42)
risk <- Risk(object = spec2, par = par, data = ret, alpha = alphas, nahead = 1, do.es = FALSE)
cat("\n--- str(Risk) ---\n"); str(risk)
VaR <- as.numeric(risk$VaR)
if (length(VaR) != length(alphas)) stop("Risk()$VaR : ", length(VaR), " valeurs pour ", length(alphas), " niveaux")
if (any(diff(VaR) <= 0)) stop("Quantiles Risk() non croissants : convention de alpha mal lue ?")
idx <- function(a) which.min(abs(alphas - a))
cat("\nFourchette 95 % du melange (rendement %, alpha = 0.025 / 0.975) :",
    round(VaR[idx(0.025)], 4), "/", round(VaR[idx(0.975)], 4), "\n")

# ---- 4. Recursion de variance par regime : initialisation validee contre predict() ---------------
pr <- predict(object = spec2, par = par, nahead = 1, newdata = ret)
vol_pred <- as.numeric(pr$vol)
pk <- function(nm, k) unname(par[paste0(nm, "_", k)])
inits <- function(k) c(uncond = if (pk("alpha1", k) + pk("beta", k) < 1) pk("alpha0", k) / (1 - pk("alpha1", k) - pk("beta", k)) else NA_real_,
                       sample = var(ret), first_sq = ret[1]^2)
cand <- c("uncond", "sample", "first_sq")
chk <- sapply(cand, function(ci) {
  s2 <- sapply(1:2, function(k) reg_recursion(ret, pk("alpha0", k), pk("alpha1", k), pk("beta", k), inits(k)[[ci]]))
  sqrt(sum(w_next * s2))
})
cat("\n--- Validation de la recursion (volatilite du melange, %/jour) ---\n")
print(data.frame(init = cand, vol_melange = round(chk, 6), predict_vol = round(vol_pred, 6),
                 ecart_relatif = signif((chk - vol_pred) / vol_pred, 3)), row.names = FALSE)
best_init <- cand[which.min(abs(chk - vol_pred))]
rel <- abs(chk[best_init] - vol_pred) / vol_pred
if (!is.finite(rel) || rel > 1e-3) warning("Recursion NON validee (ecart relatif ", signif(rel, 3), ") : ne pas utiliser les fourchettes par regime.")
cat("Initialisation retenue :", best_init, "| ecart relatif :", signif(rel, 3), "\n")
s2_k <- sapply(1:2, function(k) reg_recursion(ret, pk("alpha0", k), pk("alpha1", k), pk("beta", k), inits(k)[[best_init]]))
sig_k <- sqrt(s2_k); nu_k <- sapply(1:2, function(k) pk("nu", k))
if (any(nu_k <= 2)) stop("nu <= 2 dans un regime : quantiles standardises indefinis")
cat("sigma(t+1) par regime : volatil =", round(sig_k[hv], 4), "| calme =", round(sig_k[lv], 4), "(%/jour)\n")

# ---- 5. Quantiles EXACTS du melange vs grille de Risk() -----------------------------------------
exact <- sapply(alphas, function(p) mix_quantile(p, w_next, sig_k, nu_k))
cmp <- data.frame(alpha = alphas, risk = round(VaR, 4), exact = round(exact, 4),
                  ecart_relatif_pct = round(100 * (VaR - exact) / abs(exact), 2))
cat("\n--- Quantiles du melange : Risk() vs resolution exacte ---\n"); print(cmp, row.names = FALSE)

# ---- 6. Fourchettes par regime (chaque regime pris comme certain) -------------------------------
rc <- do.call(rbind, lapply(names(c(volatil = hv, calme = lv)), function(lab) {
  k <- c(volatil = hv, calme = lv)[[lab]]
  data.frame(confidence_level = levels_all, regime = lab, sigma_next = sig_k[k], nu = nu_k[k],
             return_q_low  = sapply(alpha_lo,     function(p) regime_quantile(p, sig_k[k], nu_k[k])),
             return_q_high = sapply(1 - alpha_lo, function(p) regime_quantile(p, sig_k[k], nu_k[k])))
}))
cat("\n--- Fourchettes a 95 % par regime (rendement %) ---\n")
print(rc[rc$confidence_level == 0.95, ], row.names = FALSE)

# ---- 7. Sorties ------------------------------------------------------------------------------------------
fan <- data.frame(confidence_level = levels_all,
                  return_q_low  = VaR[sapply(alpha_lo, idx)],
                  return_q_high = VaR[sapply(1 - alpha_lo, idx)])
inputs <- data.frame(last_date = format(last_date), last_price = last_price, confidence_level = 0.95,
                     return_q_low = VaR[idx(0.025)], return_q_high = VaR[idx(0.975)],
                     return_q_low_99 = VaR[idx(0.005)], return_q_high_99 = VaR[idx(0.995)],
                     vol_forecast = vol_pred,
                     prob_volatil_next = w_next[hv], prob_calme_next = w_next[lv], init_used = best_init)
write.csv(inputs, file.path(PROC, "btc_msgarch_price_range_inputs.csv"), row.names = FALSE)
write.csv(fan,    file.path(PROC, "btc_msgarch_fan_chart_inputs.csv"), row.names = FALSE)
write.csv(rc,     file.path(PROC, "btc_msgarch_regime_conditional_forecast.csv"), row.names = FALSE)
write.csv(cmp,    file.path(PROC, "btc_msgarch_mixture_check.csv"), row.names = FALSE)
cat("\nSorties ecrites dans", PROC, "\nRelire TOUT ce qui precede (surtout la validation de la recursion) avant de conclure.\n")
