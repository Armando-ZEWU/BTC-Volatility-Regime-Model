# graphs_ms_garch_btc.R  --  Graphiques de l'etape 3 (MS-GARCH K=2, BTC)  --  v2
# Entrees : data/processus/btc_msgarch_*.csv (produits par ms_garch_btc.R)
# Sortie  : graphs/MS_GARCH_PLOT/  (PNG 300 dpi ; dossier cree s'il n'existe pas)
# Emplacement : OPTION 2/code/graphs_ms_garch_btc.R  (working directory = code/ ou OPTION 2/)
#
# Aucun chiffre n'est ecrit en dur : tout est lu dans les CSV.
# v2 (apres lecture des 8 premieres figures) :
#   G2 : la statistique "premier franchissement de 50 %" etait trompeuse (elle renvoyait le 1er jour de
#        la fenetre) -> remplacee par P(volatil) la veille / le jour / +5 jours du choc.
#   G3 : axe de la persistance borne, etiquettes deplacees, "nu" ecrit en lettres (le glyphe grec
#        s'affichait "v" sous Windows).
#   G4 : les barres LL/AIC/BIC partaient de zero (differences invisibles) -> gains de K=2 sur K=1.
#   G6 : virgule decimale.   G8 : sous-titre coupe corrige, legendes en francais.
#   G9 (nouveau) : etiquette de regime vs ecart-type realise par annee.

library(ggplot2); library(readr); library(dplyr); library(tidyr)
library(scales);  library(stringr); library(forcats); library(lubridate)

# ---- 0. Chemins ---------------------------------------------------------------
wd   <- normalizePath(getwd(), winslash = "/")
ROOT <- if (basename(wd) == "code") dirname(wd) else wd
PROC <- file.path(ROOT, "data", "processus")
OUT  <- file.path(ROOT, "graphs", "MS_GARCH_PLOT")
stopifnot("Dossier data/processus introuvable : lancer depuis code/ ou OPTION 2/" = dir.exists(PROC))
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

theme_set(theme_bw(base_size = 12) +
            theme(plot.title = element_text(face = "bold", size = 13),
                  panel.grid.minor = element_blank()))
FAILED <- character(0)
# Ecriture robuste : 4 essais espaces de 3 s (un PNG verrouille par OneDrive ou par un apercu
# provoque "unable to start png() device") ; un echec ne bloque pas les autres figures.
save_fig <- function(p, f, w = 9, h = 4.5) {
  path <- file.path(OUT, f)
  for (i in 1:4) {
    ok <- tryCatch({ suppressWarnings(ggsave(path, p, width = w, height = h, dpi = 300, units = "in", bg = "white")); TRUE },
                   error = function(e) FALSE)
    if (ok) return(invisible(TRUE))
    Sys.sleep(3)
  }
  FAILED <<- c(FAILED, f)
  message("ECHEC d'ecriture apres 4 essais : ", path,
          "\n  (fichier verrouille ? ferme l'apercu / mets OneDrive en pause, puis relance)")
  invisible(FALSE)
}
COL_HV <- "firebrick"; COL_LV <- "steelblue3"

# ---- 1. Donnees -------------------------------------------------------------------
probs <- read_csv(file.path(PROC, "btc_msgarch_regime_probs.csv"), col_types = cols(Date = col_date()))
trans <- read_csv(file.path(PROC, "btc_msgarch_transition_matrix.csv"), col_types = cols()) %>% rename(from = 1)
pars  <- read_csv(file.path(PROC, "btc_msgarch_params_flags.csv"), col_types = cols())
ic    <- read_csv(file.path(PROC, "btc_msgarch_ic_comparison.csv"), col_types = cols()) %>% rename(model = 1)
rule  <- read_csv(file.path(PROC, "btc_msgarch_era_rule.csv"), col_types = cols())

verdict_strict <- rule$verdict[rule$version == "stricte"]
verdict_tol    <- rule$verdict[rule$version == "tolerante"]
rule_txt <- paste0("Règle 4.3 : ", verdict_strict, " (stricte) / ", verdict_tol, " (tolérante)")

# ==============================================================================
# G1 — Probabilité lissée du régime volatil, période complète
# ==============================================================================
g1 <- ggplot(probs, aes(Date, prob_highvol_smoothed)) +
  geom_area(fill = COL_HV, alpha = 0.35) +
  geom_line(color = COL_HV, linewidth = 0.3) +
  geom_hline(yintercept = 0.5, linetype = "dashed", color = "grey40") +
  geom_vline(xintercept = as.Date(c("2017-12-31", "2020-09-22")), linetype = "dotted", color = "grey30") +
  annotate("text", x = as.Date("2017-12-31"), y = 1.04, label = "fin fenêtre initiale (2017-12-31)", hjust = 1.02, size = 3) +
  annotate("text", x = as.Date("2020-09-22"), y = 1.04, label = "coupure O1 (2020-09-22)", hjust = -0.02, size = 3) +
  scale_y_continuous(labels = percent, limits = c(0, 1.08), breaks = seq(0, 1, 0.25)) +
  labs(title = "Probabilité lissée du régime volatil — BTC-USD",
       subtitle = rule_txt, x = NULL, y = "P(régime volatil)",
       caption = "Lissée = ex post (utilise tout l'échantillon). Pointillé gris : seuil 50 % ; lignes verticales : dates fixées avant les résultats.")
save_fig(g1, "01_smoothed_prob_highvol_fullsample.png")

# ==============================================================================
# G2 — Choc de mars 2020 : lissée (rétrospective) vs filtrée (temps réel)
# ==============================================================================
cv <- probs %>% filter(Date >= as.Date("2020-01-01"), Date <= as.Date("2020-06-30"))
d_shock <- cv$Date[which.max(abs(cv$log_return))]
r_shock <- probs$log_return[probs$Date == d_shock] * 100
pv <- function(d, col) { x <- probs[[col]][probs$Date == d]; if (length(x)) percent(x, accuracy = 1) else "n.d." }
sub2 <- paste0("Plus grand |rendement| de la fenêtre : ", d_shock, " (", round(r_shock, 1), " % en log-rendement). ",
               "P(volatil) la veille / le jour / +5 jours — filtrée : ",
               pv(d_shock - 1, "prob_highvol_filtered"), " / ", pv(d_shock, "prob_highvol_filtered"), " / ",
               pv(d_shock + 5, "prob_highvol_filtered"), " ; lissée : ",
               pv(d_shock - 1, "prob_highvol_smoothed"), " / ", pv(d_shock, "prob_highvol_smoothed"), " / ",
               pv(d_shock + 5, "prob_highvol_smoothed"))
cv_long <- cv %>% select(Date, Lissée = prob_highvol_smoothed, `Filtrée (temps réel)` = prob_highvol_filtered) %>%
  pivot_longer(-Date, names_to = "type", values_to = "p")
g2 <- ggplot(cv_long, aes(Date, p, color = type)) +
  geom_line(linewidth = 0.8) +
  geom_hline(yintercept = 0.5, linetype = "dashed", color = "grey40") +
  geom_vline(xintercept = d_shock, linetype = "dotted") +
  scale_color_manual(values = c("Lissée" = COL_HV, "Filtrée (temps réel)" = "steelblue4")) +
  scale_y_continuous(labels = percent, limits = c(0, 1)) +
  labs(title = "Choc de mars 2020 — probabilité du régime volatil, rétrospective et temps réel",
       subtitle = str_wrap(sub2, 100), x = NULL, y = "P(régime volatil)", color = NULL,
       caption = "Test de choc qualitatif (hors critère de succès, cf. Summary 4.5). Pointillé vertical : jour du choc.") +
  theme(legend.position = "bottom")
save_fig(g2, "02_shock_2020_smoothed_vs_filtered.png")

# ==============================================================================
# G3 — Paramètres par régime : persistance et ν, avec les drapeaux
# ==============================================================================
pdat <- bind_rows(
  pars %>% transmute(regime, metrique = "Persistance (alpha + beta)", value = persistence, lo = NA_real_, hi = NA_real_),
  pars %>% transmute(regime, metrique = "nu (± 1 erreur standard)", value = nu, lo = nu - nu_se, hi = nu + nu_se)
) %>% mutate(regime = factor(regime, levels = c("calme", "volatil")))
href <- tibble(metrique = c("Persistance (alpha + beta)", "nu (± 1 erreur standard)"), y = c(0.999, 4), x = c(2, 1),
               lab = c("seuil 0,999 (IGARCH)", "nu = 4 (kurtosis infinie en dessous)"))
blank <- tibble(metrique = "Persistance (alpha + beta)", regime = factor("calme", levels = c("calme", "volatil")),
                value = c(0.98, 1.0))
g3 <- ggplot(pdat, aes(regime, value, color = regime)) +
  geom_blank(data = blank) +
  geom_point(size = 3.5) +
  geom_errorbar(aes(ymin = lo, ymax = hi), width = 0.12, na.rm = TRUE) +
  geom_hline(data = href, aes(yintercept = y), linetype = "dashed", color = "grey40") +
  geom_text(data = href, aes(x = x, y = y, label = lab), inherit.aes = FALSE, vjust = -0.8, size = 3) +
  facet_wrap(~metrique, scales = "free_y") +
  scale_color_manual(values = c(calme = COL_LV, volatil = COL_HV)) +
  labs(title = "MS-GARCH K=2 — persistance et queues par régime",
       subtitle = str_wrap("Barres : ± 1 erreur standard (approximation de Wald, peu fiable près des bornes). Attention : l'axe de la persistance est zoomé.", 95),
       x = NULL, y = NULL) +
  theme(legend.position = "none")
save_fig(g3, "03_params_by_regime.png", w = 9, h = 4.5)

# ==============================================================================
# G4 — Gains de MS-GARCH (K=2) sur GARCH-t à 1 régime (même échelle, moyenne nulle)
# ==============================================================================
k1 <- ic %>% filter(model == "K1"); k2 <- ic %>% filter(model == "K2")
lv <- c("Gain de log-vraisemblance", "Gain d'AIC (K=1 − K=2)", "Gain de BIC (K=1 − K=2)")
ic_d <- tibble(metrique = factor(lv, levels = lv),
               valeur = c(k2$LL - k1$LL, k1$AIC - k2$AIC, k1$BIC - k2$BIC))
g4 <- ggplot(ic_d, aes(metrique, valeur)) +
  geom_col(fill = COL_HV, width = 0.55) +
  geom_hline(yintercept = 0) +
  geom_text(aes(label = round(valeur, 1)), vjust = -0.5, size = 4) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
  labs(title = "Gain de MS-GARCH (K=2) sur GARCH-t à 1 régime",
       subtitle = str_wrap("Positif = K=2 meilleur. Même échelle, moyenne nulle, estimés dans MSGARCH. Le test LR est non standard : repères, pas tests.", 95),
       x = NULL, y = "Points de critère")
save_fig(g4, "04_model_comparison_gains.png", w = 9, h = 4)

# ==============================================================================
# G5 — % de jours en régime volatil par année
# ==============================================================================
yr <- probs %>% mutate(year = year(Date), hv = label_highvol_strict) %>%
  group_by(year) %>% summarise(pct = mean(hv) * 100, n = n(), .groups = "drop") %>%
  mutate(lab = paste0(year, ifelse(n < 300, "*", "")))
g5 <- ggplot(yr, aes(fct_inorder(lab), pct)) +
  geom_col(fill = COL_HV, alpha = 0.85) +
  geom_hline(yintercept = 50, linetype = "dotted", color = "grey50") +
  labs(title = "% de jours en régime volatil, par année",
       subtitle = "Une marche unique (haut puis bas) évoque une ère ; des allers-retours évoquent des régimes",
       x = NULL, y = "% des jours (prob. lissée > 50 %)", caption = "* année partielle") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
save_fig(g5, "05_yearly_highvol_pct.png")

# ==============================================================================
# G6 — Matrice de transition (heatmap)
# ==============================================================================
tl <- trans %>% pivot_longer(-from, names_to = "to", values_to = "prob") %>%
  mutate(from = factor(from, levels = c("calme", "volatil")),
         to = fct_rev(factor(to, levels = c("calme", "volatil"))))
g6 <- ggplot(tl, aes(from, to, fill = prob)) +
  geom_tile(color = "white", linewidth = 1) +
  geom_text(aes(label = percent(prob, accuracy = 0.01, decimal.mark = ",")), size = 4.5) +
  scale_fill_gradient(low = "white", high = COL_HV, labels = percent) +
  labs(title = "Matrice de transition — MS-GARCH (K=2)", x = "Régime au jour t", y = "Régime au jour t+1", fill = "Probabilité")
save_fig(g6, "06_transition_matrix.png", w = 7, h = 4.5)

# ==============================================================================
# G7 — Rendements journaliers colorés par régime
# ==============================================================================
g7 <- ggplot(probs, aes(Date, log_return * 100, color = label_highvol_strict)) +
  geom_point(size = 0.5, alpha = 0.6) +
  scale_color_manual(values = c(`FALSE` = COL_LV, `TRUE` = COL_HV), labels = c("calme", "volatil")) +
  labs(title = "Rendements journaliers BTC-USD par régime", x = NULL, y = "Rendement (%)", color = "Régime") +
  theme(legend.position = "bottom")
save_fig(g7, "07_returns_by_regime.png")

# ==============================================================================
# G8 — Tous les optima du MS-GARCH : vraisemblance vs durée du régime le plus court
# ==============================================================================
opt_file <- file.path(PROC, "btc_msgarch_optima_sensitivity.csv")
if (file.exists(opt_file)) {
  op <- read_csv(opt_file, col_types = cols()) %>%
    mutate(min_dur = pmin(dur_hv, dur_lv),
           start = recode(start, default = "défaut", pert = "départ perturbé", pers = "départ persistant"))
  g8 <- ggplot(op, aes(min_dur, LL, color = start, shape = near_opt)) +
    geom_vline(xintercept = 20, linetype = "dashed", color = "grey40") +
    geom_point(size = 3, alpha = 0.8) +
    scale_x_log10() +
    scale_shape_manual(values = c(`FALSE` = 16, `TRUE` = 17), labels = c("non", "oui")) +
    labs(title = "Optima du MS-GARCH : log-vraisemblance vs durée du régime le plus court",
         subtitle = str_wrap("Pointillé : 20 jours (seuil descriptif, non contraignant). Un point haut et à droite = régimes persistants bien soutenus.", 95),
         x = "Durée espérée du régime le plus court (jours, échelle log)", y = "Log-vraisemblance",
         color = "Type de départ", shape = "À moins de 3 LL du meilleur")
  save_fig(g8, "08_optima_ll_vs_duration.png")
}

# ==============================================================================
# G9 — Étiquette de régime vs niveau de volatilité réalisée, par année
# ==============================================================================
yr2 <- probs %>% mutate(year = year(Date)) %>% group_by(year) %>%
  summarise(sd_pct = sd(log_return) * 100, pct_hv = mean(label_highvol_strict) * 100, n = n(), .groups = "drop") %>%
  mutate(lab = ifelse(n < 300, paste0(year, "*"), as.character(year)))
rho <- cor(yr2$sd_pct, yr2$pct_hv)
g9 <- ggplot(yr2, aes(sd_pct, pct_hv, label = lab)) +
  geom_point(color = COL_HV, size = 3) +
  geom_text(vjust = -0.9, size = 3.2) +
  scale_y_continuous(limits = c(0, 108)) +
  labs(title = "Étiquette de régime vs volatilité réalisée, par année",
       subtitle = paste0("Corrélation de Pearson : ", round(rho, 2), " (", nrow(yr2), " années, descriptif)"),
       x = "Écart-type réalisé des rendements (%/jour)", y = "% de jours en régime « volatil »",
       caption = "* année partielle. Un lien faible signifie que l'étiquette ne se réduit pas au niveau de volatilité.")
save_fig(g9, "09_label_vs_realized_vol_by_year.png")

cat("Terminé —", length(list.files(OUT, pattern = "\\.png$")), "graphiques dans", OUT, "\n")
if (length(FAILED)) cat("FIGURES NON ECRITES :", paste(FAILED, collapse = ", "), "\n")