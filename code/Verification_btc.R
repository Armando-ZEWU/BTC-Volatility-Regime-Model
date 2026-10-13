# verification_btc.R  --  Ce que le backtest NE montre PAS : verifications complementaires (apres l'etape 7)
# Le backtest de l'etape 7 teste la couverture INCONDITIONNELLE a 95 % et l'independance des depassements. Il ne dit pas :
#   (A) si le MS-GARCH fait mieux qu'un modele SIMPLE (une bande peut etre calibree sans etre utile) ;
#   (B) si la largeur de la bande varie a bon escient d'un jour a l'autre (calibration CONDITIONNELLE, discrimination) ;
#   (C) de combien les depassements depassent ;
#   (D) ce qu'il en est de la DIRECTION (jamais testee : moyenne nulle imposee, O4).
# Aucune de ces verifications n'etait au cadrage : ce sont des examens EXPLORATOIRES. Le critere 4.1 (PASS) n'est pas remis en jeu.
# Nombre de comparaisons : declare ci-dessous ; aucun seuil n'est ajuste apres coup.
#
# Entrees : data/processus/btc_log_returns.csv, btc_backtest_daily.csv (etape 7)
# Sorties : data/processus/btc_verif_*.csv
# Emplacement : OPTION 2/code/verification_btc.R  (working directory = code/ ou OPTION 2/)
# Benchmarks (memes 3 193 jours, information jusqu'a la veille uniquement) :
#   HS    simulation historique : quantiles empiriques des 365 derniers rendements
#   EWMA  RiskMetrics (lambda = 0.94), bande Normale
#   FHS   EWMA + quantiles empiriques des 730 derniers rendements standardises (queues lourdes sans parametre)
#   K1    GARCH-t a UN regime, re-estime chaque 1er janvier (necessite MSGARCH ; RUN_K1 = FALSE pour s'en passer)

wd   <- normalizePath(getwd(), winslash = "/")
ROOT <- if (basename(wd) == "code") dirname(wd) else wd
PROC <- file.path(ROOT, "data", "processus")
stopifnot("Dossier data/processus introuvable : lancer depuis code/ ou OPTION 2/" = dir.exists(PROC))

RUN_K1 <- TRUE
LAMBDA <- 0.94; HS_WIN <- 365; FHS_WIN <- 730
P <- c(0.005, 0.025, 0.975, 0.995)            # colonnes : bas 99, bas 95, haut 95, haut 99
HAVE_MS <- exists("FitML") || requireNamespace("MSGARCH", quietly = TRUE)
if (RUN_K1 && HAVE_MS && !exists("FitML")) library(MSGARCH)

# ---- outils (copies des fonctions de msgarch_utils_btc.R : ce script ne depend pas de MSGARCH hors K1) --------------
xlogy <- function(x, y) ifelse(x == 0, 0, x * log(y))
kupiec_pof <- function(x, n, p) { ph <- x / n
lr <- -2 * ((n - x) * log(1 - p) + x * log(p)) + 2 * (xlogy(n - x, 1 - ph) + xlogy(x, ph)); c(LR = lr, p_value = pchisq(lr, 1, lower.tail = FALSE)) }
christoffersen_ind <- function(hit) { hit <- as.integer(hit); a <- head(hit, -1); b <- tail(hit, -1)
n00 <- sum(a == 0 & b == 0); n01 <- sum(a == 0 & b == 1); n10 <- sum(a == 1 & b == 0); n11 <- sum(a == 1 & b == 1)
if ((n01 + n11) == 0 || (n00 + n10) == 0) return(c(LR = NA_real_, p_value = NA_real_))
pi01 <- n01 / (n00 + n01); pi11 <- if ((n10 + n11) > 0) n11 / (n10 + n11) else 0; pi <- (n01 + n11) / (n00 + n01 + n10 + n11)
ll0 <- xlogy(n00 + n10, 1 - pi) + xlogy(n01 + n11, pi)
ll1 <- xlogy(n00, 1 - pi01) + xlogy(n01, pi01) + xlogy(n10, 1 - pi11) + xlogy(n11, pi11)
lr <- -2 * (ll0 - ll1); c(LR = lr, p_value = pchisq(lr, 1, lower.tail = FALSE)) }
t_scale <- function(nu) sqrt((nu - 2) / nu)
nw_lrv <- function(x, L) { x <- x - mean(x); n <- length(x); s <- sum(x * x) / n
for (l in seq_len(L)) s <- s + 2 * (1 - l / (L + 1)) * sum(x[(l + 1):n] * x[1:(n - l)]) / n; s }
dm_test <- function(d) { L <- floor(length(d)^(1 / 3)); t <- mean(d) / sqrt(nw_lrv(d, L) / length(d)); c(t = t, p = 2 * pnorm(-abs(t))) }
slope_hac <- function(x, y, L = 10) { xc <- x - mean(x); b <- sum(xc * (y - mean(y))) / sum(xc^2); e <- (y - mean(y)) - b * xc
u <- xc * e; n <- length(u); S <- sum(u * u); for (l in seq_len(L)) S <- S + 2 * (1 - l / (L + 1)) * sum(u[(l + 1):n] * u[1:(n - l)])
c(slope = b, t = b / sqrt(S / sum(xc^2)^2)) }

# ---- donnees ------------------------------------------------------------------------------------------------------------------
dat <- read.csv(file.path(PROC, "btc_log_returns.csv"), stringsAsFactors = FALSE)
dates <- as.Date(dat$Date); r <- dat$log_return * 100; n <- length(r)
bt <- read.csv(file.path(PROC, "btc_backtest_daily.csv"), stringsAsFactors = FALSE); bt$date <- as.Date(bt$date)
idx <- match(bt$date, dates); stopifnot(!anyNA(idx), max(abs(r[idx] - bt$ret)) < 1e-6)
y <- r[idx]; m <- length(idx)
cat("Jours evalues :", m, "|", format(min(bt$date)), "->", format(max(bt$date)), "\n")

# ---- (A) benchmarks -------------------------------------------------------------------------------------------------------------------
hs <- t(sapply(idx, function(d) quantile(r[(d - HS_WIN):(d - 1)], probs = P, names = FALSE)))
s2 <- numeric(n); s2[1] <- var(r[1:30]); for (t in 2:n) s2[t] <- LAMBDA * s2[t - 1] + (1 - LAMBDA) * r[t - 1]^2
sig <- sqrt(s2)
ew <- outer(sig[idx], qnorm(P))
zst <- r / sig
fhs <- t(sapply(idx, function(d) sig[d] * quantile(zst[(d - FHS_WIN):(d - 1)], probs = P, names = FALSE)))
mods <- list(`MS-GARCH (K=2)` = as.matrix(bt[, c("q_low99", "q_low95", "q_high95", "q_high99")]), `EWMA Normale` = ew,
             `EWMA + FHS` = fhs, `Simulation historique 365 j` = hs)
if (RUN_K1 && HAVE_MS) {
  spec1 <- CreateSpec(variance.spec = list(model = "sGARCH"), distribution.spec = list(distribution = "std"))
  k1 <- matrix(NA_real_, m, 4); yrs <- format(bt$date, "%Y")
  for (Y in unique(yrs)) {
    est <- which(dates < as.Date(paste0(Y, "-01-01")))
    f <- tryCatch(FitML(spec = spec1, data = r[est]), error = function(e) NULL); if (is.null(f)) { cat("K1 : echec fold", Y, "\n"); next }
    p <- f$par; om <- p[["alpha0_1"]]; a <- p[["alpha1_1"]]; b <- p[["beta_1"]]; nu <- p[["nu_1"]]
    s2k <- numeric(n); s2k[1] <- var(r[est]); for (t in 2:n) s2k[t] <- om + a * r[t - 1]^2 + b * s2k[t - 1]
    rows <- which(yrs == Y); k1[rows, ] <- outer(sqrt(s2k[idx[rows]]), qt(P, nu) * t_scale(nu))
    cat(sprintf("K1 fold %s : alpha+beta = %.4f, nu = %.2f\n", Y, a + b, nu))
  }
  mods <- append(mods, list(`GARCH-t (K=1)` = k1), after = 1)
}
score <- function(q, y) { lo95 <- q[, 2]; hi95 <- q[, 3]; lo99 <- q[, 1]; hi99 <- q[, 4]
list(b95 = y < lo95 | y > hi95, b99 = y < lo99 | y > hi99, w95 = hi95 - lo95, w99 = hi99 - lo99,
     is95 = (hi95 - lo95) + (2 / 0.05) * (lo95 - y) * (y < lo95) + (2 / 0.05) * (y - hi95) * (y > hi95),
     is99 = (hi99 - lo99) + (2 / 0.01) * (lo99 - y) * (y < lo99) + (2 / 0.01) * (y - hi99) * (y > hi99)) }
sc <- lapply(mods, score, y = y)
tabA <- do.call(rbind, lapply(names(sc), function(nm) { s <- sc[[nm]]; ok <- !is.na(s$b95)
k95 <- kupiec_pof(sum(s$b95[ok]), sum(ok), 0.05); k99 <- kupiec_pof(sum(s$b99[ok]), sum(ok), 0.01)
dm <- if (nm == "MS-GARCH (K=2)") c(t = NA, p = NA) else dm_test(s$is95[ok] - sc[[1]]$is95[ok])
data.frame(modele = nm, n = sum(ok), dep95 = sum(s$b95[ok]), couv95 = round(1 - mean(s$b95[ok]), 4), kupiec_p95 = round(k95[["p_value"]], 3),
           christ_p95 = round(christoffersen_ind(s$b95[ok])[["p_value"]], 3), largeur95_moy = round(mean(s$w95[ok]), 2),
           IS95_moy = round(mean(s$is95[ok]), 2), dep99 = sum(s$b99[ok]), couv99 = round(1 - mean(s$b99[ok]), 4), kupiec_p99 = round(k99[["p_value"]], 3),
           largeur99_moy = round(mean(s$w99[ok]), 2), IS99_moy = round(mean(s$is99[ok]), 2),
           DM_t_IS95_vs_MS = round(dm[["t"]], 2), DM_p = round(dm[["p"]], 3)) }))
cat("\n=== (A) MS-GARCH contre des modeles simples (memes jours, memes folds) ===\n")
cat("IS = score d'intervalle (plus bas = mieux ; penalise largeur ET depassements). DM : t > 0 = le modele est PIRE que le MS-GARCH.\n")
print(tabA, row.names = FALSE)
cat("Comparaisons de (A) : 4 modeles x 1 test de score ; DM avec correction HAC (Newey-West) ; queues lourdes => t indicatif.\n")

# ---- (B) calibration conditionnelle et discrimination -----------------------------------------------------------------------------
cat("\n=== (B1) Couverture a 95 % par tercile de LARGEUR de bande (calibration conditionnelle) ===\n")
tabB1 <- do.call(rbind, lapply(names(sc), function(nm) { s <- sc[[nm]]; ok <- !is.na(s$b95)
g <- cut(s$w95[ok], quantile(s$w95[ok], c(0, 1/3, 2/3, 1)), include.lowest = TRUE, labels = c("etroit", "moyen", "large"))
do.call(rbind, lapply(levels(g), function(l) { b <- s$b95[ok][g == l]; k <- kupiec_pof(sum(b), length(b), 0.05)
data.frame(modele = nm, tercile_largeur = l, n = length(b), depassements = sum(b), couverture = round(1 - mean(b), 4), kupiec_p = round(k[["p_value"]], 3)) })) }))
print(tabB1, row.names = FALSE)
cat("\n=== (B2) Regression de |rendement| sur la demi-largeur de la bande a 95 % (le niveau de risque est-il bien classe ?) ===\n")
tabB2 <- do.call(rbind, lapply(names(sc), function(nm) { s <- sc[[nm]]; ok <- !is.na(s$w95); hw <- s$w95[ok] / 2; a <- abs(y[ok])
h <- slope_hac(hw, a); data.frame(modele = nm, pente = round(h[["slope"]], 3), t_HAC = round(h[["t"]], 1), R2 = round(cor(hw, a)^2, 4)) }))
print(tabB2, row.names = FALSE)
cat("Pente ~ constante positive et R2 eleve = la largeur suit bien l'ampleur du mouvement du jour. Une bande a largeur constante aurait R2 = 0.\n")

# ---- (C) taille des depassements (MS-GARCH) --------------------------------------------------------------------------------------------
cat("\n=== (C) Taille des depassements du MS-GARCH ===\n")
sizes <- function(bb, lo, hi, yy) { d <- ifelse(yy < lo, lo - yy, yy - hi)[bb]; hw <- ((hi - lo) / 2)[bb]
data.frame(n = length(d), moy_pp = mean(d), med_pp = median(d), p90_pp = quantile(d, .9), max_pp = max(d), moy_rel = mean(d / hw), max_rel = max(d / hw), n_rel_gt_1 = sum(d / hw > 1)) }
tabC <- rbind(cbind(niveau = 0.95, sizes(sc[[1]]$b95, bt$q_low95, bt$q_high95, y)), cbind(niveau = 0.99, sizes(sc[[1]]$b99, bt$q_low99, bt$q_high99, y)))
print(round(tabC, 2), row.names = FALSE)
cat("rel = depassement / demi-largeur ; n_rel_gt_1 = jours ou le rendement sort de plus d'une demi-largeur AU-DELA de la borne.\n")

# ---- (D) direction : 3 tests declares -------------------------------------------------------------------------------------------------
cat("\n=== (D) Direction : autocorrelation et persistance du signe (3 tests ; Bonferroni 0,05/3 = 0,0167) ===\n")
lb <- function(x, l) Box.test(x, lag = l, type = "Ljung-Box")$p.value
cat(sprintf("Ljung-Box sur les rendements (tout l'echantillon) : lag 10 p = %.4f | lag 20 p = %.4f   [test 1 : direction lineaire]\n", lb(r, 10), lb(r, 20)))
cat(sprintf("Ljung-Box sur |rendements| : lag 10 p = %.2e | lag 20 p = %.2e   [temoin : le regroupement de volatilite doit, lui, etre massif]\n", lb(abs(r), 10), lb(abs(r), 20)))
s <- sign(r); same <- (s[-1] == s[-n]) & s[-1] != 0 & s[-n] != 0; nz <- s[-1] != 0 & s[-n] != 0
bin1 <- binom.test(sum(same[nz]), sum(nz), 0.5)
cat(sprintf("Persistance du signe a 1 jour : %d / %d = %.3f ; binomial bilateral p = %.4f   [test 2]\n", sum(same[nz]), sum(nz), sum(same[nz]) / sum(nz), bin1$p.value))
pre_tr <- sapply(idx, function(d) sum(r[(d - 20):(d - 1)])); hit <- sign(pre_tr) == sign(y) & sign(y) != 0; ok <- sign(y) != 0
bin2 <- binom.test(sum(hit[ok]), sum(ok), 0.5)
cat(sprintf("Tendance 20 jours -> signe du lendemain (jours du backtest) : %d / %d = %.3f ; binomial bilateral p = %.4f   [test 3]\n", sum(hit[ok]), sum(ok), sum(hit[ok]) / sum(ok), bin2$p.value))
cat(sprintf("Part de jours haussiers : %.3f (backtest) | rendement moyen : %.3f %%/jour (derive realisee, non une prevision)\n", mean(y > 0), mean(y)))
tabD <- data.frame(test = c("LB lag10 rendements", "LB lag20 rendements", "persistance signe 1j", "tendance 20j -> signe"),
                   p = c(lb(r, 10), lb(r, 20), bin1$p.value, bin2$p.value))

# ---- sorties ----------------------------------------------------------------------------------------------------------------------------------
write.csv(tabA, file.path(PROC, "btc_verif_benchmarks.csv"), row.names = FALSE)
write.csv(tabB1, file.path(PROC, "btc_verif_conditional_terciles.csv"), row.names = FALSE)
write.csv(tabB2, file.path(PROC, "btc_verif_mincer_zarnowitz.csv"), row.names = FALSE)
write.csv(tabC, file.path(PROC, "btc_verif_breach_size.csv"), row.names = FALSE)
write.csv(tabD, file.path(PROC, "btc_verif_direction.csv"), row.names = FALSE)
cat("\nSorties ecrites dans", PROC, "\nRelire TOUT ce qui precede avant de conclure ; chaque resultat est exploratoire.\n")