# Étape 3 — Markov-Switching GARCH (K=2) sur BTC-USD

*Option 2 (test de généralisation du pipeline EUR/USD). Structure calquée sur `Markov-Switching_Garch.md`. Cadre et critères : `summary_btc_option2.md` (4.3 et 4.6, fixés avant estimation).*

## 1. Objectif

Appliquer tel quel le MS-GARCH(K=2) du projet EUR/USD (spécification de Haas, Mittnik et Paolella, 2004a, via `MSGARCH`) aux log-rendements du BTC, et vérifier : (a) que le pipeline s'exécute et produit des diagnostics interprétables, (b) ce que la règle gelée 4.3 (« régime » ou « ère ») donne sur ces données.

## 2. Spécification et différences avec l'EUR/USD

Deux régimes GARCH(1,1) à innovations Student's t, probabilités de transition markoviennes (`do.mix = FALSE`). Script : `code/ms_garch_btc.R`.

| # | Différence déclarée | Raison |
|---|---|---|
| D1 | Rendements en % (×100) | Cohérence avec l'étape 2 ; optimisation mieux conditionnée. α, β, ν et P sont invariants à l'échelle |
| D2 | Benchmark GARCH-t à 1 régime estimé *dans* MSGARCH (moyenne nulle) | Comparaison K=1/K=2 à spécification de moyenne identique (limite du document EUR/USD, où la moyenne différait) |
| D3 | Règle 4.3 appliquée mécaniquement par le script | Pas de lecture à l'œil du résultat |
| D4 | Probabilités filtrées et chemin de Viterbi exportés | Manque signalé dans le document EUR/USD |
| D5 | Redémarrages multiples ; le meilleur optimum devient l'ajustement final | Voir section 3 |
| D6 | Verdicts : `ERE`, `PAS_ERE`, `AUCUN_JOUR_VOLATIL` | « Régime » laissait croire qu'un régime avait été trouvé |
| D7 | Départs « régimes persistants » et bruit en logit sur les probabilités de transition | Correction d'un défaut de conception (section 3) |

Comme sur l'EUR/USD, aucune équation de moyenne n'est estimée (rendements traités comme de moyenne nulle). Le régime « volatil » est défini, avant résultats, comme celui dont les jours dominants (probabilité lissée > 0,5) ont l'écart-type réalisé le plus élevé ; le σ de long terme ω/(1−α−β) n'est pas utilisé, il est peu fiable près de la frontière IGARCH.

## 3. Trouver l'optimum : trois exécutions

| Exécution | Départs | Meilleure LL | Structure trouvée |
|---|---|---|---|
| v1 | défaut + 5 perturbés | −10 713,36 | Micro-régimes : durées espérées ≈ 2 et 6 jours |
| v2 | défaut + 15 perturbés | −10 713,36 (4 fois sur 15) | Idem : 2,2 et 5,8 jours, 91 % de jours ambigus |
| v3 | défaut + 8 perturbés + 12 « régimes persistants » | **−10 708,78** (10 fois sur 12 départs persistants, 0 fois sur 8 départs perturbés) | **Régimes persistants : 72,8 et 35,9 jours** |

**Défaut de conception de la v2, corrigé en v3** : les redémarrages écrêtaient les probabilités de transition à [0,6 ; 0,995]. Tous les départs étaient donc des micro-régimes, et l'optimum à micro-régimes (−10 713,36) était pris pour l'optimum global alors qu'il est 4,58 points de log-vraisemblance en dessous. Seuls les départs « régimes persistants » ont trouvé la meilleure solution. Le point de départ par défaut de `MSGARCH` et le voisinage de son résultat n'y mènent pas.

Les 21 ajustements se répartissent ainsi : 10 sur l'optimum persistant (LL −10 708,78 pour 9 d'entre eux, −10 708,94 pour le dixième), 5 sur l'optimum à micro-régimes −10 713,36 (dont un départ « persistant »), 4 sur −10 714,83, le point par défaut (−10 716,45) et un ajustement isolé (−10 737,17). Le meilleur optimum est donc reproduit 10 fois ; l'optimalité globale n'est pas démontrée, seulement soutenue par cette répétition.

## 4. Résultats (ajustement final : `pers_9`)

| | Régime volatil (indice 1) | Régime calme (indice 2) |
|---|---|---|
| ω | 0,3780 (SE 0,131) | 0,1784 (SE 0,140) |
| α | 0,0835 (SE 0,058) | 0,0750 (SE 0,106) |
| β | 0,9044 (SE 0,0084) | 0,9240 (SE 0,0013) |
| ν | 3,95 (SE 0,39) | 2,30 (SE 0,068) |
| Persistance α + β | 0,988 | 0,99900 |
| Demi-vie intra-régime | 57 jours | ≈ 695 jours (non fiable) |
| Écart-type réalisé sur les jours dominants | 3,81 %/jour | 2,61 %/jour |
| Durée espérée 1/(1−P_kk) | 72,8 jours | 35,9 jours |
| Probabilité stationnaire | 67 % | 33 % |

Matrice de transition (volatil, calme) : P(volatil→volatil) = 0,9863 ; P(calme→calme) = 0,9722. LL = −10 708,78 ; AIC = 21 437,56 ; BIC = 21 501,44 (10 paramètres libres).

**Lecture des p-values** : la colonne `Pr(>|t|)` de `MSGARCH` est unilatérale ; le p bilatéral est le double. En bilatéral : ω du régime volatil p ≈ 0,004 ; α du régime volatil p ≈ 0,15 ; ω et α du régime calme p ≈ 0,20 et 0,48 (non significatifs) ; β et ν p ≈ 0.

## 5. Identification des régimes

- Le régime volatil occupe ≈ 69 % des jours (étiquette à 0,5) ; le régime calme est minoritaire (≈ 31 %).
- 26 blocs volatils, 51 bascules sur 4 394 jours ; les plus longs blocs volatils : 2020-10-03 → 2022-08-09 (676 jours), 2017-04-21 → 2018-09-08 (506), 2024-06-16 → 2025-04-12 (301), 2014-09-18 → 2015-05-08 (233).
- Plus longs blocs calmes : 2023-06-23 → 2023-11-07 (138 jours), 2015-12-16 → 2016-04-18 (125), 2016-07-09 → 2016-10-24 (108), 2025-04-13 → 2025-07-29 (108).
- **Identification imparfaite** : 42,6 % des jours ont une probabilité lissée maximale inférieure à 0,9 (contre 90,7 % à l'optimum à micro-régimes).
- **Incertitude sur les durées** : l'erreur standard de P(volatil→volatil) est de 0,0108 pour une probabilité de sortie de 0,0137. La durée de 72,8 jours est très incertaine (plusieurs semaines à plusieurs mois, voire plus) ; l'intervalle de Wald n'est pas fiable près de cette borne.

## 5bis. Lecture des figures (première série de 8 figures)

Lectures graphiques, donc approximatives ; les chiffres exacts sont dans les CSV et, pour la figure 02, dans le sous-titre de la v2.

- **Fig. 01 (probabilité lissée)** : le régime volatil alterne avec le calme sur tout l'échantillon, sans marche unique. En fin d'échantillon, la probabilité du régime volatil est basse (≈ 10-15 %).
- **Fig. 02 (choc de mars 2020)** : la probabilité du régime volatil est élevée avant le choc, puis **baisse** le jour du choc (filtrée ≈ 50 %, lissée ≈ 35 %) et reste basse en avril. Le plus grand choc de l'échantillon (−46 %) est donc attribué au régime « calme », cohérent avec son ν = 2,30. La statistique « premier franchissement de 50 % » affichée en v1 était trompeuse (elle renvoyait le premier jour de la fenêtre) ; remplacée en v2 par les probabilités la veille, le jour et à +5 jours.
- **Fig. 07 (rendements par régime)** : les points calmes ont une dispersion étroite mais comportent des valeurs extrêmes isolées, dont le −46 %.
- **Fig. 05 (part de jours volatils par année)** : allers-retours (≈ 18 % en 2016, ≈ 100 % en 2021, ≈ 58 % en 2023), pas de marche unique, cohérent avec la règle 4.3.
- **Fig. 05 et écart-type annuel (étape 1)** : l'étiquette ne suit pas le niveau de volatilité réalisé. 2016 (σ ≈ 2,5 %/jour) compte ≈ 18 % de jours volatils, 2023 (σ ≈ 2,3 %) ≈ 58 % ; 2025 (σ ≈ 2,2 %) et 2015 (σ ≈ 3,7 %) comptent chacune ≈ 60 %. La figure 09 (v2) quantifie ce lien.
- **Fig. 08 (optima)** : deux bassins nets, micro-régimes (≈ 2 jours) et régimes persistants (≈ 36 jours), sans solution intermédiaire. Avec le même nombre de paramètres, la solution persistante gagne 4,58 de log-vraisemblance, soit ΔAIC = ΔBIC = −9,2.
- **Fig. 03, 04, 06** : lisibles mais corrigées en v2 (axe de la persistance, barres de la fig. 04 qui partaient de zéro et masquaient les écarts, virgule décimale).

**Conséquence pour la lecture** : les étiquettes « volatil » et « calme » sont définies, avant résultats, par l'écart-type réalisé sur les jours dominants. Elles ne désignent pas « crise » et « non-crise » : le régime calme combine une échelle plus basse et des queues extrêmes (ν = 2,30) et absorbe le plus grand choc ; le régime volatil a une échelle plus haute et des queues moins lourdes (ν = 3,95). Le verdict de la règle 4.3 ne dépend pas de ces étiquettes : il y a 51 bascules, et le plus long bloc calme (138 jours) est loin de 40 % de l'échantillon.

## 6. Règle 4.3 (gelée) : « régime » ou « ère » ?

| Version | Bascules | Blocs volatils | Plus long bloc | Part de l'échantillon (plus long bloc) | Verdict |
|---|---|---|---|---|---|
| Stricte (contraignante) | 51 | 26 | 676 jours | 15,4 % | **PAS_ERE** |
| Tolérante (runs < 10 jours fusionnés, sensibilité) | 45 | 23 | 749 jours | 17,0 % | **PAS_ERE** |

Les 10 ajustements à moins de 3 points de log-vraisemblance du meilleur donnent le même verdict. Ni la condition « bascule unique » ni la condition « bloc volatil unique > 40 % » n'est remplie : les régimes alternent sur tout l'échantillon.

La règle ne détecte que l'ère ; « PAS_ERE » ne dit pas que les régimes sont des « régimes de peur ». Elle n'est pas utilisée ici pour autre chose que ce qu'elle a été conçue pour tester. Le test de l'étape 4 (comparaison avant/après la coupure du 2020-09-22) reste à faire.

## 7. Comparaisons

**Avec le GARCH-t à 1 régime (même échelle, moyenne nulle)**

| | K=1 | K=2 |
|---|---|---|
| Paramètres libres | 4 | 10 |
| Log-vraisemblance | −10 755,49 | −10 708,78 (+46,71) |
| AIC | 21 518,99 | **21 437,56** (−81,4) |
| BIC | 21 544,54 | **21 501,44** (−43,1) |

AIC et BIC favorisent tous les deux K=2, contrairement à l'EUR/USD où ils divergeaient. Le test du rapport de vraisemblance K=1 contre K=2 n'est pas standard (paramètres non identifiés sous l'hypothèse nulle) : AIC et BIC sont des repères, pas des tests.

**Repères avec l'EUR/USD** (`Markov-Switching_Garch.md`) : contexte, pas un critère. Un résultat différent n'est ni un échec ni un succès ; les critères sont propres au BTC (Summary 4.1 et 4.3).

| | EUR/USD | BTC |
|---|---|---|
| Durée espérée du régime volatil | 160 jours de bourse | ≈ 73 jours (incertain) |
| Durée espérée du régime calme | 404 jours de bourse | ≈ 36 jours |
| Temps passé en régime volatil | ≈ 28 % | ≈ 67-69 % |
| Écart-type réalisé, régime volatil | 0,70 %/jour | 3,81 %/jour |
| Écart-type réalisé, régime calme | 0,44 %/jour | 2,61 %/jour |
| ν par régime | 7,07 et 22,0 | 3,95 et 2,30 |
| AIC / BIC pour K=2 | divergents | concordants |

## 8. Drapeaux et limites

- **ν ≤ 4 dans les deux régimes** (3,95 et 2,30) : le moment d'ordre 4 est infini ; le régime calme, avec ν = 2,30, est proche de la borne où la variance n'existe plus.
- **Persistance du régime calme à 0,99900**, à la limite du seuil de 0,999 ; la demi-vie de 695 jours n'est pas fiable.
- Les erreurs standard de α sont grandes (0,058 et 0,106) : la répartition entre α et β est mal déterminée, même si leur somme l'est mieux.
- Les σ de long terme ω/(1−α−β) ne sont pas rapportés (régime calme : dénominateur ≈ 0,001, valeur absurde).
- L'optimalité globale n'est pas démontrée (section 3).
- Les probabilités commentées sont lissées (ex post). Les probabilités filtrées, seules disponibles en temps réel, sont exportées pour l'étape 7.
- Les régimes sont identifiés par la volatilité réalisée ; la classification est ambiguë pour 42,6 % des jours.

## 9. Lecture dans le contexte du Bitcoin

Le BTC est un actif sans ancrage monétaire institutionnel (aucun émetteur, aucune convertibilité garantie) et très volatil. Conséquences pour la lecture des résultats :

- **« Calme » est relatif.** Le régime calme du BTC (≈ 2,6 %/jour) est plus volatil que le régime de stress de l'EUR/USD (0,70 %/jour), soit environ 3,7 fois plus. Les étiquettes « calme » et « volatil » ne se comparent pas en valeur absolue entre les deux projets.
- **Le régime volatil est l'état majoritaire** (≈ 69 % des jours) : pour cet actif, la forte volatilité est le cas courant, le calme l'exception.
- **Queues et persistance** : dans cette spécification, la persistance proche de 1 et ν ≈ 2,3 à 4 ne disparaissent pas quand on autorise deux régimes. Pour un actif sans ancrage, une volatilité très persistante et des queues très lourdes peuvent être des propriétés réelles et pas seulement des artefacts de spécification ; cette lecture est plausible, pas démontrée (le test de l'étape 4 reste à faire).
- **Ancrage monétaire et structure de marché sont deux choses.** L'absence d'ancrage monétaire n'exclut pas des changements de structure de marché (contrats à terme, produits cotés, entrée d'investisseurs institutionnels, cités dans `methodology_btc_option1.md`) qui pourraient produire un effet d'« ère ». Le résultat de la section 6 dit seulement que le MS-GARCH(K=2) n'isole pas une seule bascule.
- Ne pas transposer l'interprétation « peur du marché » de l'EUR/USD : ici, les régimes sont des états de volatilité, sans lecture comportementale établie.

## 10. Fichiers produits

- `code/ms_garch_btc.R` (v3) et `code/graphs_ms_garch_btc.R`
- `data/processus/` : `btc_msgarch_regime_probs.csv` (probabilités lissées et filtrées, Viterbi, étiquettes), `btc_msgarch_transition_matrix.csv`, `btc_msgarch_params_flags.csv`, `btc_msgarch_ic_comparison.csv`, `btc_msgarch_era_rule.csv`, `btc_msgarch_highvol_runs.csv`, `btc_msgarch_regime_descriptives.csv`, `btc_msgarch_restarts.csv`, `btc_msgarch_optima_sensitivity.csv`, `btc_msgarch_par.rds` (valeurs numériques uniquement)
- `graphs/MS_GARCH_PLOT/` : 9 figures ggplot2 (01 à 09 ; le script a été corrigé en v2 après examen des 8 premières)

## 11. Points ouverts

- Relancer le script de graphiques v2 et examiner les figures corrigées (02, 03, 04) et la nouvelle (09).
- Étape 4 : comparaison avant/après la coupure du 2020-09-22 (test du rapport de vraisemblance de type Chow, Summary 4.3).
- Décision O4 (moyenne dans la fourchette) : l'étape 3 est à μ = 0 par construction.
