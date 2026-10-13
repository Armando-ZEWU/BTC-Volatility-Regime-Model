# graphs_distribution_btc.R  --  La distribution des rendements BTC et ses queues epaisses (ggplot2)
# Entrees : data/processus/btc_log_returns.csv ; btc_garch_shocks.csv et btc_garch_step2_table.csv (etape 2) ;
#           btc_msgarch_regime_probs.csv (etape 3) ; btc_backtest_daily.csv (etape 7)
# Sortie  : graphs/DISTRIBUTION_PLOT/  (cree s'il n'existe pas ; change OUT plus bas pour le ranger ailleurs)
# Emplacement : OPTION 2/code/graphs_distribution_btc.R  (working directory = code/ ou OPTION 2/)
# Figures :
#   D1 densite empirique des rendements en echelle LOG (points = classes de l'histogramme) + Normale + t ajustee
#   D2 QQ-plots : rendements vs Normale ; residus du GARCH-t vs Normale ; residus du GARCH-t vs t(nu)
#   D3 probabilite de depasser x (log-log) : empirique (pertes et gains) vs Normale vs t ajustee
#   D4 estimateur de Hill (indice de queue) pour les pertes et les gains
#   D5 distribution par regime (etiquette de l'optimum final de l'etape 3)
#   D6 rendements par annee (boites) avec kurtosis en exces
#   D7 taille des depassements a 95 % du backtest, rapportee a la demi-largeur de la bande
# Le script imprime aussi des tableaux : moments par annee, comptes de jours extremes vs attendus, Hill.
library(ggplot2); library(readr); library(dplyr); library(tidyr); library(scales); library(stringr); library(lubridate)

wd   <- normalizePath(getwd(), winslash = "/")
ROOT <- if (basename(wd) == "code") dirname(wd) else wd
PROC <- file.path(ROOT, "data", "processus")
OUT  <- file.path(ROOT, "graphs", "Distribution_PLOT")
stopifnot("Dossier data/processus introuvable : lancer depuis code/ ou OPTION 2/" = dir.exists(PROC))
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

theme_set(theme_bw(base_size = 12) + theme(plot.title = element_text(face = "bold", size = 13), panel.grid.minor = element_blank()))
FAILED <- character(0)
save_fig <- function(p, f, w = 10, h = 5) {
  path <- file.path(OUT, f)
  for (i in 1:4) {
    ok <- tryCatch({ suppressWarnings(ggsave(path, p, width = w, height = h, dpi = 300, units = "in", bg = "white")); TRUE }, error = function(e) FALSE)
    if (ok) return(invisible(TRUE)); Sys.sleep(3)
  }
  FAILED <<- c(FAILED, f); message("ECHEC d'ecriture apres 4 essais : ", path, " (fichier verrouille ? ferme l'apercu / mets OneDrive en pause)"); invisible(FALSE)
}
fr <- function(x, d = 2) format(round(x, d), decimal.mark = ",")
kurt_ex <- function(x) mean((x - mean(x))^4) / mean((x - mean(x))^2)^2 - 3
skew_f  <- function(x) mean((x - mean(x))^3) / mean((x - mean(x))^2)^1.5
COL_N <- "steelblue3"; COL_T <- "firebrick"

# ---- Donnees --------------------------------------------------------------------------------------------
dat <- read_csv(file.path(PROC, "btc_log_returns.csv"), col_types = cols(Date = col_date()))
r <- dat$log_return * 100; n <- length(r); mu <- mean(r); s <- sd(r)
cat("n =", n, "| moyenne =", fr(mu, 4), "% | ecart-type =", fr(s, 3), "% | asymetrie =", fr(skew_f(r), 2),
    "| kurtosis en exces =", fr(kurt_ex(r), 2), "| min =", fr(min(r), 1), "% | max =", fr(max(r), 1), "%\n")

# t de Student a position-echelle ajustee par maximum de vraisemblance (rendements INCONDITIONNELS)
ft <- tryCatch(MASS::fitdistr(r, "t", start = list(m = 0, s = 2, df = 3), lower = c(-Inf, 0.01, 2.05)), error = function(e) NULL)
if (is.null(ft)) stop("Ajustement t impossible : verifier le paquet MASS")
tm <- ft$estimate[["m"]]; ts_ <- ft$estimate[["s"]]; tdf <- ft$estimate[["df"]]
cat("t ajustee (inconditionnelle) : position =", fr(tm, 3), "| echelle =", fr(ts_, 3), "| nu =", fr(tdf, 2), "\n")
dt_ls <- function(x) dt((x - tm) / ts_, tdf) / ts_
pt_ls <- function(x) pt((x - tm) / ts_, tdf)

# ==============================================================================
# D1 — Histogramme en echelle log
# ==============================================================================
xr <- c(-30, 25); n_out <- sum(r < xr[1] | r > xr[2])
g1 <- ggplot(tibble(r = r), aes(r)) +
  stat_bin(aes(y = after_stat(density)), geom = "point", bins = 140, color = "grey25", size = 1.1) +   # points : lisibles en echelle log
  stat_function(fun = function(x) dnorm(x, mu, s), aes(color = "Normale (même moyenne et écart-type)"), linewidth = 0.9, n = 800) +
  stat_function(fun = dt_ls, aes(color = paste0("t de Student ajustée (ν = ", fr(tdf, 2), ")")), linewidth = 0.9, n = 800) +
  scale_y_log10(limits = c(1e-5, 1), labels = label_number(drop0trailing = TRUE, decimal.mark = ",")) +
  scale_color_manual(values = setNames(c(COL_N, COL_T), c("Normale (même moyenne et écart-type)", paste0("t de Student ajustée (ν = ", fr(tdf, 2), ")")))) +
  coord_cartesian(xlim = xr) +
  labs(title = "Distribution des rendements journaliers BTC-USD, densité en échelle logarithmique",
       subtitle = str_wrap(paste0("L'échelle log rend visibles les queues : là où la Normale tombe à zéro, la distribution observée garde de la masse. Kurtosis en excès : ", fr(kurt_ex(r), 1), " ; asymétrie : ", fr(skew_f(r), 2), "."), 110),
       x = "Rendement journalier (%)", y = "Densité (échelle log)", color = NULL,
       caption = paste0(n_out, " rendement(s) hors cadre (extrême : ", fr(min(r), 1), " %). t ajustée sur les rendements bruts (inconditionnelle) : ν diffère du ν d'un GARCH-t.")) +
  theme(legend.position = "bottom")
save_fig(g1, "D1_histogram_log_density.png")

# ==============================================================================
# D2 — QQ-plots (unites : ecarts-types, droite y = x)
# ==============================================================================
nu_g <- tryCatch({ tb <- read_csv(file.path(PROC, "btc_garch_step2_table.csv"), col_types = cols()); as.numeric(tb[tb[[1]] == "nu", "t"][[1]]) }, error = function(e) NA_real_)
if (is.na(nu_g)) { nu_g <- 3.18; message("nu du GARCH-t non lu : valeur de l'etape 2 (3,18) utilisee") }
qq_df <- function(z, theo_fun, lab) { z <- sort(z); tibble(emp = z, theo = theo_fun(ppoints(length(z))), panel = lab) }
zr <- (r - mu) / s
parts <- list(qq_df(zr, qnorm, "Rendements bruts vs Normale"))
f_sh <- file.path(PROC, "btc_garch_shocks.csv")
if (file.exists(f_sh)) {
  sh <- read_csv(f_sh, col_types = cols())
  zs <- sh$standardized_residual
  parts[[2]] <- qq_df(zs, qnorm, "Résidus du GARCH-t vs Normale")
  parts[[3]] <- qq_df(zs, function(p) qt(p, nu_g) * sqrt((nu_g - 2) / nu_g), paste0("Résidus du GARCH-t vs t(ν = ", fr(nu_g, 2), ")"))
}
qq <- bind_rows(parts) %>% mutate(panel = factor(panel, levels = unique(panel)))
g2 <- ggplot(qq, aes(theo, emp)) +
  geom_abline(slope = 1, intercept = 0, color = "grey40", linetype = "dashed") +
  geom_point(size = 0.6, alpha = 0.6, color = COL_T) +
  facet_wrap(~panel) +
  labs(title = "QQ-plots : où les queues quittent la droite",
       subtitle = "Axes en écarts-types. Les points qui s'éloignent de la diagonale sont des quantiles extrêmes que la loi de référence n'explique pas.",
       x = "Quantile théorique", y = "Quantile observé")
save_fig(g2, "D2_qqplots.png", w = 11, h = 4.5)

# ==============================================================================
# D3 — P(depasser x), log-log
# ==============================================================================
xs <- exp(seq(log(0.5), log(max(abs(r)) * 1.05), length.out = 300))
emp <- tibble(x = xs,
              Pertes = sapply(xs, function(x) mean(r < -x)),
              Gains  = sapply(xs, function(x) mean(r >  x))) %>%
  pivot_longer(-x, names_to = "serie", values_to = "p") %>% filter(p > 0)
ref <- tibble(x = xs, `Normale (côté unique)` = 1 - pnorm(xs, 0, s), `t ajustée (côté unique)` = 1 - pt_ls(xs)) %>%
  pivot_longer(-x, names_to = "serie", values_to = "p") %>% filter(p > 1e-8)
g3 <- ggplot() +
  geom_line(data = ref, aes(x, p, color = serie), linewidth = 0.9) +
  geom_step(data = emp, aes(x, p, color = serie), linewidth = 0.7) +
  scale_x_log10(labels = label_number(decimal.mark = ",")) + scale_y_log10(labels = label_number(drop0trailing = TRUE, decimal.mark = ",")) +
  scale_color_manual(values = c(Pertes = "black", Gains = "grey50", `Normale (côté unique)` = COL_N, `t ajustée (côté unique)` = COL_T), name = NULL) +
  labs(title = "Probabilité de dépasser x : observé contre Normale et t (échelles log-log)",
       subtitle = str_wrap("Une queue en loi de puissance est une droite décroissante en log-log ; la Normale s'effondre. Écart entre pertes et gains = asymétrie des queues."),
       x = "x (%)", y = "P(rendement < −x) ou P(rendement > x)") + theme(legend.position = "bottom")
save_fig(g3, "D3_tail_probability_loglog.png")

# ==============================================================================
# D4 — Estimateur de Hill (indice de queue alpha ; la t a nu degres de liberte a alpha = nu)
# ==============================================================================
hill <- function(x, ks) { xs_ <- sort(x, decreasing = TRUE); sapply(ks, function(k) 1 / mean(log(xs_[1:k] / xs_[k + 1]))) }
ks <- 15:400
hl <- bind_rows(tibble(k = ks, alpha = hill(-r[r < 0], ks), queue = "Pertes (queue gauche)"),
                tibble(k = ks, alpha = hill(r[r > 0], ks), queue = "Gains (queue droite)"))
cat("\n=== Hill : indice de queue alpha a k = 50 / 100 / 200 ===\n")
print(hl %>% filter(k %in% c(50, 100, 200)) %>% mutate(alpha = round(alpha, 2)) %>% pivot_wider(names_from = k, values_from = alpha), n = 10)
g4 <- ggplot(hl, aes(k, alpha, color = queue)) +
  geom_hline(yintercept = tdf, linetype = "dashed", color = "grey40") +
  geom_line(linewidth = 0.8) +
  scale_color_manual(values = c("Pertes (queue gauche)" = "black", "Gains (queue droite)" = "grey55"), name = NULL) +
  labs(title = "Estimateur de Hill : indice de queue en fonction du nombre d'extrêmes retenus (k)",
       subtitle = str_wrap(paste0("Un plateau stable indique un indice de queue estimable ; plus α est petit, plus la queue est lourde (variance infinie si α ≤ 2, kurtosis infinie si α ≤ 4). Pointillé : ν de la t ajustée (", fr(tdf, 2), ")."), 115),
       x = "k (nombre d'observations extrêmes retenues)", y = "Indice de queue α̂",
       caption = "Hill suppose des observations indépendantes ; le regroupement de volatilité biaise l'estimation (lecture indicative).") +
  theme(legend.position = "bottom")
save_fig(g4, "D4_hill_plot.png")

# ==============================================================================
# D5 — Par regime (etiquette de l'optimum final, etape 3)
# ==============================================================================
f_rp <- file.path(PROC, "btc_msgarch_regime_probs.csv")
if (file.exists(f_rp)) {
  rp <- read_csv(f_rp, col_types = cols(Date = col_date())) %>% mutate(ret = log_return * 100, regime = ifelse(label_highvol_strict, "volatil", "calme"))
  kk <- rp %>% group_by(regime) %>% summarise(sd = sd(ret), k = kurt_ex(ret), mx = min(ret), .groups = "drop")
  cat("\n=== Par regime (etiquettes de l'etape 3) ===\n"); print(kk %>% mutate(across(where(is.numeric), ~ round(.x, 2))))
  lab <- setNames(paste0(kk$regime, " (σ = ", fr(kk$sd, 2), " %, kurtosis = ", fr(kk$k, 1), ")"), kk$regime)
  g5 <- ggplot(rp, aes(ret, color = regime)) +
    geom_density(adjust = 0.6, linewidth = 0.9) +
    scale_y_log10(limits = c(1e-5, 1), labels = label_number(drop0trailing = TRUE, decimal.mark = ",")) +
    scale_color_manual(values = c(calme = COL_N, volatil = COL_T), labels = lab, name = NULL) +
    coord_cartesian(xlim = xr) +
    labs(title = "Distribution des rendements selon le régime (étiquettes de l'étape 3, densité log)",
         subtitle = str_wrap("Le régime « calme » a un corps étroit mais des extrêmes isolés : sa kurtosis est plus forte. Les étiquettes se fondent sur l'écart-type réalisé, pas sur la gravité d'une crise.", 115),
         x = "Rendement journalier (%)", y = "Densité (échelle log)") + theme(legend.position = "bottom")
  save_fig(g5, "D5_distribution_by_regime.png")
}

# ==============================================================================
# D6 — Par annee
# ==============================================================================
yr <- dat %>% mutate(ret = log_return * 100, year = factor(year(Date)))
ytab <- yr %>% group_by(year) %>% summarise(n = n(), sd = sd(ret), skew = skew_f(ret), kurt = kurt_ex(ret), min = min(ret), max = max(ret), .groups = "drop")
cat("\n=== Moments par annee (n < 300 : annee partielle) ===\n"); print(ytab %>% mutate(across(where(is.numeric), ~ round(.x, 2))), n = 20)
g6 <- ggplot(yr, aes(year, ret)) +
  geom_boxplot(outlier.size = 0.7, outlier.alpha = 0.5, fill = "grey90", color = "grey35") +
  geom_text(data = ytab, aes(year, 22, label = paste0("K=", round(kurt, 1))), size = 3, color = COL_T) +
  coord_cartesian(ylim = c(-25, 25)) +
  labs(title = "Rendements journaliers par année : la volatilité baisse, les extrêmes restent",
       subtitle = str_wrap("K = kurtosis en excès de l'année (Normale = 0). Points = jours en dehors des moustaches ; les extrêmes subsistent même les années de faible volatilité."),
       x = NULL, y = "Rendement (%)", caption = paste0("Valeurs hors cadre (|rendement| > 25 %) : ", sum(abs(yr$ret) > 25), ". Années partielles : 2014 et 2026."))
save_fig(g6, "D6_returns_by_year.png")

# ==============================================================================
# D7 — Taille des depassements a 95 % (backtest)
# ==============================================================================
f_bt <- file.path(PROC, "btc_backtest_daily.csv")
if (file.exists(f_bt)) {
  bt <- read_csv(f_bt, col_types = cols(date = col_date())) %>% filter(breach95) %>%
    mutate(size = ifelse(ret < q_low95, q_low95 - ret, ret - q_high95), hw = (q_high95 - q_low95) / 2, rel = size / hw)
  cat("\n=== Depassements a 95 % : taille (points de rendement) et rapportee a la demi-largeur ===\n")
  print(tibble(n = nrow(bt), moy_pp = mean(bt$size), mediane_pp = median(bt$size), p90_pp = quantile(bt$size, .9), max_pp = max(bt$size),
               moy_rel = mean(bt$rel), mediane_rel = median(bt$rel), p90_rel = quantile(bt$rel, .9), max_rel = max(bt$rel),
               n_rel_gt_1 = sum(bt$rel > 1)) %>% mutate(across(where(is.numeric), ~ round(.x, 2))))
  g7 <- ggplot(bt, aes(rel)) +
    geom_histogram(bins = 40, fill = COL_T, alpha = 0.8, color = "white") +
    scale_x_log10(labels = label_number(decimal.mark = ",")) +
    geom_vline(xintercept = 1, linetype = "dashed") +
    labs(title = "Quand la bande à 95 % est dépassée, de combien ?",
         subtitle = str_wrap("Taille du dépassement rapportée à la demi-largeur de la bande (échelle log). À droite du pointillé, le rendement sort de plus d'une demi-largeur au-delà de la borne.", 110),
         x = "Dépassement / demi-largeur de la bande", y = "Nombre de jours",
         caption = paste0(nrow(bt), " dépassements ; le plus grand vaut ", fr(max(bt$rel), 1), " demi-largeurs (", fr(max(bt$size), 1), " points) le ", bt$date[which.max(bt$rel)], "."))
  save_fig(g7, "D7_breach_size.png", w = 9, h = 4.5)
}

# ==============================================================================
# Tableau : jours extremes observes vs attendus sous la Normale et sous la t ajustee
# ==============================================================================
ks_sig <- c(3, 4, 5, 6, 8, 10)
cmp <- tibble(k_sigma = ks_sig,
              observes = sapply(ks_sig, function(k) sum(abs(r - mu) > k * s)),
              attendus_normale = round(n * 2 * (1 - pnorm(ks_sig)), 2),
              attendus_t_ajustee = round(n * (pt_ls(tm - ks_sig * s) + 1 - pt_ls(tm + ks_sig * s)), 2))
cat("\n=== Jours a plus de k ecarts-types de la moyenne (sigma de l'echantillon) ===\n"); print(cmp)
cat("\nTermine — figures dans", OUT, "\n")
if (length(FAILED)) cat("FIGURES NON ECRITES :", paste(FAILED, collapse = ", "), "\n")