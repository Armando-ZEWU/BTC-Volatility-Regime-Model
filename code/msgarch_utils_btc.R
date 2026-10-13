# msgarch_utils_btc.R  --  fonctions partagees par les etapes 6 (choc) et 7 (backtest)
# A sourcer depuis les scripts : source(file.path(ROOT, "code", "msgarch_utils_btc.R"))
# Regles MSGARCH respectees (Price_Range.md) : seul le vecteur numerique `par` circule (jamais l'objet fit),
# alpha de Risk() = niveaux de la queue GAUCHE, State()/Risk() prennent `data`.
library(MSGARCH)

make_spec2 <- function() CreateSpec(
  variance.spec = list(model = "sGARCH"),
  distribution.spec = list(distribution = "std"),
  switch.spec = list(do.mix = FALSE, K = 2))

# ---- departs pour l'optimisation (meme logique que ms_garch_btc.R v3) -------------------------------
lg <- function(p) qlogis(pmin(pmax(p, 1e-4), 1 - 1e-4))
perturb_par <- function(p) {
  q <- p
  for (k in 1:2) {
    q[paste0("alpha0_", k)] <- p[paste0("alpha0_", k)] * exp(rnorm(1, 0, 0.4))
    b <- min(0.97, max(0.5, p[paste0("beta_", k)] + rnorm(1, 0, 0.05)))
    a <- min(0.25, max(0.01, p[paste0("alpha1_", k)] * exp(rnorm(1, 0, 0.4))))
    if (a + b > 0.995) a <- max(0.005, 0.995 - b)
    q[paste0("beta_", k)] <- b; q[paste0("alpha1_", k)] <- a
    q[paste0("nu_", k)] <- min(60, max(2.5, p[paste0("nu_", k)] * exp(rnorm(1, 0, 0.3))))
  }
  iP <- grep("^P_", names(p)); q[iP] <- plogis(lg(p[iP]) + rnorm(length(iP), 0, 0.8)); q
}
persistent_start_par <- function(p) {
  q <- p
  q["alpha0_1"] <- exp(runif(1, log(0.005), log(0.05)))
  q["alpha0_2"] <- exp(runif(1, log(0.1), log(2)))
  for (k in 1:2) {
    a <- runif(1, 0.03, 0.15); b <- runif(1, 0.80, 0.94)
    if (a + b > 0.99) b <- 0.99 - a
    q[paste0("alpha1_", k)] <- a; q[paste0("beta_", k)] <- b; q[paste0("nu_", k)] <- runif(1, 4, 12)
  }
  q["P_1_1"] <- runif(1, 0.97, 0.998); q["P_2_1"] <- runif(1, 0.002, 0.03); q
}

# Meilleur optimum parmi : defaut + departs "chauds" (par0_list) + perturbations + departs persistants.
fit_best <- function(ret, spec, par0_list = list(), n_pert = 6, n_pers = 12, seed = 42) {
  set.seed(seed)
  try_fit <- function(par0 = NULL) tryCatch(
    if (is.null(par0)) FitML(spec = spec, data = ret) else FitML(spec = spec, data = ret, ctr = list(par0 = par0)),
    error = function(e) NULL)
  fits <- list(); f0 <- try_fit()
  if (!is.null(f0)) fits[["default"]] <- f0
  base <- if (!is.null(f0)) f0$par else if (length(par0_list)) par0_list[[1]] else stop("aucun point de depart")
  for (nm in names(par0_list)) { f <- try_fit(par0_list[[nm]]); if (!is.null(f)) fits[[paste0("warm_", nm)]] <- f }
  for (i in seq_len(n_pert)) { f <- try_fit(perturb_par(base));          if (!is.null(f)) fits[[paste0("pert_", i)]] <- f }
  for (i in seq_len(n_pers)) { f <- try_fit(persistent_start_par(base)); if (!is.null(f)) fits[[paste0("pers_", i)]] <- f }
  if (!length(fits)) stop("aucun ajustement n'a converge")
  ll <- sapply(fits, function(f) f$loglik); best <- names(which.max(ll)); f <- fits[[best]]
  list(par = f$par, loglik = f$loglik, MatCoef = f$Inference$MatCoef, best = best, ll_all = ll, n_fits = length(fits))
}

# ---- drapeaux (Summary 4.2) ------------------------------------------------------------------------------------
flags_fit <- function(par, MatCoef) {
  mc <- as.data.frame(MatCoef); names(mc) <- c("Estimate", "SE", "t", "p")[seq_len(ncol(mc))]
  do.call(rbind, lapply(1:2, function(k) {
    a <- par[[paste0("alpha1_", k)]]; b <- par[[paste0("beta_", k)]]; nu <- par[[paste0("nu_", k)]]
    nu_se <- mc[paste0("nu_", k), "SE"]
    data.frame(regime_index = k, persistence = a + b, nu = nu, nu_se = nu_se,
               flag_persistence_gt_0.999 = (a + b) > 0.999,
               flag_se_nu_gt_nu = isTRUE(nu_se > nu), flag_nu_le_4 = nu <= 4,
               P_stay = if (k == 1) par[["P_1_1"]] else 1 - par[["P_2_1"]])   # P_2_1 = P(regime 2 -> regime 1)
  }))
}

# ---- regimes et prevision a 1 jour ----------------------------------------------------------------------------------
take_T <- function(arr, n, k) { m <- arr[, 1, k]
if (length(m) == n + 1) m[2:(n + 1)] else if (length(m) == n) m else stop("dimension inattendue de State()") }
hv_from_sm <- function(sm, ret) {          # regime volatil = ecart-type realise le plus eleve sur ses jours dominants
  assigned <- ifelse(sm[, 2] > 0.5, 2L, 1L)
  sd_by <- sapply(1:2, function(k) if (sum(assigned == k) > 1) sd(ret[assigned == k]) else NA_real_)
  list(hv = if (all(is.na(sd_by))) 1L else which.max(sd_by), sd_by = sd_by)
}
smooth_probs <- function(spec, par, ret) { n <- length(ret); st <- State(object = spec, par = par, data = ret)
sapply(1:2, function(k) take_T(st$SmoothProb, n, k)) }
# Melange exact (independant de la grille de Risk()) : meme logique que ms_garch_forecast_btc.R (etape 5)
reg_recursion <- function(r, om, a, b, init) { s2 <- init; for (t in seq_along(r)) s2 <- om + a * r[t]^2 + b * s2; s2 }
t_scale <- function(nu) sqrt((nu - 2) / nu)
mix_cdf <- function(x, w, sig, nu) sum(w * pt(x / (sig * t_scale(nu)), nu))
mix_quantile <- function(p, w, sig, nu) uniroot(function(x) mix_cdf(x, w, sig, nu) - p, interval = c(-1e6, 1e6), tol = 1e-12)$root
exact_forecast <- function(par, hist, w, alphas) {
  sig <- sapply(1:2, function(k) sqrt(reg_recursion(hist, par[[paste0("alpha0_", k)]], par[[paste0("alpha1_", k)]],
                                                    par[[paste0("beta_", k)]], init = var(hist))))   # l'initialisation est sans effet (beta^T ~ 0)
  nu <- c(par[["nu_1"]], par[["nu_2"]])
  if (any(nu <= 2)) stop("nu <= 2 : quantiles standardises indefinis")
  sapply(alphas, function(p) mix_quantile(p, w, sig, nu))
}

# Prevision a 1 jour : Risk() d'abord (fidelite a l'EUR/USD) ; si Risk() echoue ou renvoie des quantiles
# incoherents (cas observe le 2020-03-14, apres le plus grand choc), repli sur le melange EXACT, avec
# la methode et la raison consignees pour chaque jour.
forecast_1d <- function(spec, par, hist, alphas) {   # alphas CROISSANTS (queue gauche)
  n <- length(hist)
  st <- State(object = spec, par = par, data = hist)
  if (dim(st$PredProb)[1] != n + 1) stop("PredProb : dimension inattendue")
  w <- as.numeric(st$PredProb[n + 1, 1, ])
  q <- tryCatch({
    rk <- Risk(object = spec, par = par, data = hist, alpha = alphas, nahead = 1, do.es = FALSE)
    qq <- as.numeric(rk$VaR)
    if (length(qq) != length(alphas) || any(!is.finite(qq)) || any(diff(qq) <= 0)) stop("quantiles Risk() incoherents : ", paste(round(qq, 3), collapse = " "))
    qq
  }, error = function(e) e)
  if (inherits(q, "error")) {
    return(list(w = w, q = exact_forecast(par, hist, w, alphas), method = "exact", reason = conditionMessage(q)))
  }
  list(w = w, q = q, method = "risk", reason = "")
}

# ---- tests de couverture ------------------------------------------------------------------------------------------------------
xlogy <- function(x, y) ifelse(x == 0, 0, x * log(y))
kupiec_pof <- function(x, n, p) {          # H0 : taux de depassement = p ; chi2(1), bilateral
  ph <- x / n
  lr <- -2 * ((n - x) * log(1 - p) + x * log(p)) + 2 * (xlogy(n - x, 1 - ph) + xlogy(x, ph))
  c(LR = lr, p_value = pchisq(lr, 1, lower.tail = FALSE))
}
christoffersen_ind <- function(hit) {      # independance des depassements ; chi2(1)
  hit <- as.integer(hit); a <- head(hit, -1); b <- tail(hit, -1)
  n00 <- sum(a == 0 & b == 0); n01 <- sum(a == 0 & b == 1); n10 <- sum(a == 1 & b == 0); n11 <- sum(a == 1 & b == 1)
  if ((n01 + n11) == 0 || (n00 + n10) == 0) return(c(LR = NA_real_, p_value = NA_real_))
  pi01 <- n01 / (n00 + n01); pi11 <- if ((n10 + n11) > 0) n11 / (n10 + n11) else 0
  pi <- (n01 + n11) / (n00 + n01 + n10 + n11)
  ll0 <- xlogy(n00 + n10, 1 - pi) + xlogy(n01 + n11, pi)
  ll1 <- xlogy(n00, 1 - pi01) + xlogy(n01, pi01) + xlogy(n10, 1 - pi11) + xlogy(n11, pi11)
  lr <- -2 * (ll0 - ll1); c(LR = lr, p_value = pchisq(lr, 1, lower.tail = FALSE))
}
binom_greater <- function(x, n, p) binom.test(x, n, p, alternative = "greater")$p.value   # sous-couverture (comme l'EUR/USD)