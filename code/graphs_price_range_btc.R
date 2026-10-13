# graphs_price_range_btc.R  --  Eventail de la fourchette de prix (etape 5, BTC)
# Entrees : data/processus/btc_msgarch_price_range_inputs.csv, btc_msgarch_fan_chart_inputs.csv,
#           btc_msgarch_regime_conditional_forecast.csv
# Sortie  : graphs/MS_GARCH_PLOT/10_fan_chart.png
# Emplacement : OPTION 2/code/graphs_price_range_btc.R  (working directory = code/ ou OPTION 2/)
library(ggplot2); library(readr); library(dplyr); library(tidyr); library(scales); library(stringr)

wd   <- normalizePath(getwd(), winslash = "/")
ROOT <- if (basename(wd) == "code") dirname(wd) else wd
PROC <- file.path(ROOT, "data", "processus")
OUT  <- file.path(ROOT, "graphs", "Price_Range_Plot")
stopifnot("Dossier data/processus introuvable" = dir.exists(PROC))
dir.create(OUT, showWarnings = FALSE, recursive = TRUE)

inp <- read_csv(file.path(PROC, "btc_msgarch_price_range_inputs.csv"), col_types = cols())
fan <- read_csv(file.path(PROC, "btc_msgarch_fan_chart_inputs.csv"), col_types = cols())
rc  <- read_csv(file.path(PROC, "btc_msgarch_regime_conditional_forecast.csv"), col_types = cols())
P0 <- inp$last_price

# Bandes du melange : quantiles EXACTS (btc_msgarch_mixture_check.csv) quand ils existent ; la grille de Risk()
# fausse les niveaux centraux (jusqu'a -9 % a 50 %, cf. btc2_05_price_range.md section 7).
mc_file <- file.path(PROC, "btc_msgarch_mixture_check.csv")
mix_src <- "Risk()"
if (file.exists(mc_file)) {
  mc <- read_csv(mc_file, col_types = cols())
  pick <- function(a) mc$exact[which.min(abs(mc$alpha - a))]
  fan <- fan %>% mutate(return_q_low = sapply((1 - confidence_level) / 2, pick),
                        return_q_high = sapply(1 - (1 - confidence_level) / 2, pick))
  mix_src <- "quantiles exacts"
}

bands <- bind_rows(
  fan %>% transmute(panel = "Mélange (opérationnel)", level = confidence_level, lo = return_q_low, hi = return_q_high),
  rc  %>% transmute(panel = paste0("Régime ", regime, " (certain)"), level = confidence_level, lo = return_q_low, hi = return_q_high)
) %>% mutate(lo = P0 * exp(lo / 100), hi = P0 * exp(hi / 100),
             level_lab = factor(paste0(round(level * 100), " %"),
                                levels = paste0(round(sort(unique(level), decreasing = TRUE) * 100), " %")))
bands$panel <- factor(bands$panel, levels = c("Mélange (opérationnel)", "Régime calme (certain)", "Régime volatil (certain)"))
bands <- bands %>% arrange(desc(level))   # dessiner la bande la plus large d'abord, les plus etroites par-dessus

pal <- c("#fee0d2", "#fcbba1", "#fb6a4a", "#cb181d", "#67000d")[seq_along(levels(bands$level_lab))]
names(pal) <- levels(bands$level_lab)        # niveaux 99 -> 20 : du plus clair (large) au plus fonce (etroit)
g <- ggplot(bands) +
  geom_rect(aes(xmin = 0.6, xmax = 1.4, ymin = lo, ymax = hi, fill = level_lab), color = "white", linewidth = 0.3) +
  geom_hline(yintercept = P0, linetype = "dashed") +
  facet_wrap(~panel) +
  scale_fill_manual(values = pal, name = "Niveau") +
  scale_y_continuous(labels = label_number(big.mark = " ", suffix = " $")) +
  scale_x_continuous(breaks = NULL) +
  labs(title = "Fourchette de prix BTC-USD pour le jour suivant : eventail par niveau de confiance",
       subtitle = str_wrap(paste0("Au ", inp$last_date, " (prix ", format(round(P0), big.mark = " "), " $, pointille) ; P(regime volatil demain) = ",
                                  percent(inp$prob_volatil_next, accuracy = 0.1),
                                  ". Melange : ", mix_src, ". Le niveau 99 % est un diagnostic, non un critere."), 100),
       x = NULL, y = NULL) +
  theme_bw(base_size = 12) +
  theme(plot.title = element_text(face = "bold", size = 12), panel.grid.minor = element_blank())
ok <- tryCatch({ suppressWarnings(ggsave(file.path(OUT, "10_fan_chart.png"), g, width = 11, height = 5, dpi = 300, bg = "white")); TRUE },
               error = function(e) { message("ECHEC d'ecriture : ", conditionMessage(e), " (fichier verrouille ?)"); FALSE })
if (ok) cat("Figure ecrite dans", OUT, "\n")
