# sigma_by_regime_by_fold.R -- sigma realise de chaque regime, par annee de test (fold)
# Entree : data/processus/btc_backtest_daily.csv  (colonnes utilisees : year, ret, p_volatil)
# Sorties: data/processus/btc_sigma_by_regime_by_fold.csv  et  graphs/Backest_Plot/18_sigma_by_regime_by_fold.png
# Emplacement : OPTION 2/code/  (working directory = code/ ou OPTION 2/)
#
# Question testee : le regime "volatil" de 2026 est-il aussi volatil, en valeur absolue, que celui de 2018 ?
#   - Si sigma_volatil ET sigma_calme baissent avec le temps : les etiquettes sont RELATIVES a chaque fold.
#   - Si elles restent stables : les etiquettes sont ABSOLUES (le modele classe plus de jours en "volatil"
#     alors que le marche se calme : c'est alors un point a expliquer).
#   - Si le ratio sigma_volatil / sigma_calme tend vers 1 : les deux regimes se ressemblent de plus en plus.
# Test hors echantillon : p_volatil est la probabilite prevue la veille, ret est le rendement du jour (en %).

library(dplyr); library(readr); library(tidyr); library(ggplot2)

wd   <- normalizePath(getwd(), winslash = "/")
ROOT <- if (basename(wd) == "code") dirname(wd) else wd
PROC <- file.path(ROOT, "data", "processus")
OUT  <- file.path(ROOT, "graphs", "Backest_Plot")
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

bt <- read_csv(file.path(PROC, "btc_backtest_daily.csv"), col_types = cols(date = col_date()))
stopifnot(all(c("year", "ret", "p_volatil") %in% names(bt)))

# ecart-type pondere : chaque jour compte pour sa probabilite d'appartenir au regime
wsd <- function(x, w) { m <- sum(w * x) / sum(w); sqrt(sum(w * (x - m)^2) / sum(w)) }

tab <- bt %>% group_by(year) %>% summarise(
  jours             = n(),
  jours_eff_volatil = sum(p_volatil),        # nombre effectif de jours dans chaque regime
  jours_eff_calme   = sum(1 - p_volatil),
  sigma_volatil     = wsd(ret, p_volatil),
  sigma_calme       = wsd(ret, 1 - p_volatil),
  sigma_tous        = sd(ret),
  # variante sans ponderation : seuil a 50 %
  sigma_volatil_seuil = sd(ret[p_volatil >  0.5]),
  sigma_calme_seuil   = sd(ret[p_volatil <= 0.5]),
  .groups = "drop") %>%
  mutate(ratio = sigma_volatil / sigma_calme)

print(as.data.frame(round(tab, 2)))
write_csv(tab, file.path(PROC, "btc_sigma_by_regime_by_fold.csv"))

pl <- tab %>% transmute(year, Volatil = sigma_volatil, Calme = sigma_calme, `Tous les jours` = sigma_tous) %>%
  pivot_longer(-year, names_to = "serie", values_to = "sigma")

g18 <- ggplot(pl, aes(year, sigma, color = serie)) +
  geom_line(linewidth = 0.8) + geom_point(size = 2.4) +
  scale_color_manual(values = c(Calme = "steelblue3", Volatil = "firebrick", `Tous les jours` = "grey30"), name = NULL) +
  scale_x_continuous(breaks = sort(unique(pl$year))) +
  labs(title = "σ réalisé de chaque régime, par année de test",
       subtitle = "Écart-type des rendements journaliers, pondéré par la probabilité de régime prévue la veille.",
       x = NULL, y = "σ journalier (%)",
       caption = "Les étiquettes calme/volatil sont propres à chaque fold. 2026 = année partielle.") +
  theme_bw(base_size = 12) +
  theme(plot.title = element_text(face = "bold", size = 13), panel.grid.minor = element_blank(), legend.position = "bottom")

ggsave(file.path(OUT, "18_sigma_by_regime_by_fold.png"), g18, width = 10, height = 5, dpi = 300, bg = "white")
cat("Terminé — tableau dans", file.path(PROC, "btc_sigma_by_regime_by_fold.csv"), "et figure dans", OUT, "\n")