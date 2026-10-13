# Étape 7 — Backtest en fenêtre extensive : le pass/fail de l'Option 2

*Option 2 (test de généralisation du pipeline EUR/USD). Structure calquée sur `Full_Backtest.md`. Critères fixés avant toute estimation (Summary 4.1).*

## 1. Objectif et critères

Mesurer si les fourchettes à 95 % à 1 jour du MS-GARCH(K=2) sont **calibrées** sur le BTC, hors échantillon. Critère 4.1 (appliqué mécaniquement par le script) :

| Condition | Seuil |
|---|---|
| Prévisions hors-échantillon | n ≥ 2 500 |
| Couverture inconditionnelle | Kupiec bilatéral non rejeté à 5 % |
| Indépendance des dépassements | Christoffersen non rejeté à 5 % |

Rapportés sans pass/fail : couverture à 99 % (O3) et binomial unilatéral (comparabilité avec l'EUR/USD). Risque connu : deux tests à 5 % donnent environ 10 % de faux rejet sur un modèle parfaitement calibré (documenté, non corrigé).

## 2. Design

- Estimation initiale 2014-09-18 → 2017-12-31 (1 201 rendements) ; test annuel 2018 → 2026 (2026 partielle, jusqu'au 2026-09-28) : **9 folds, 3 193 prévisions**.
- Chaque 1er janvier : ré-estimation sur **tout l'historique antérieur**, puis paramètres **gelés** pendant l'année ; chaque jour, filtre et prévision avec l'historique jusqu'à la veille. Aucune information future : vérifié dans le code (`dates < 1er janvier` pour l'estimation ; `ret[1:(d−1)]` pour la prévision).
- Script : `code/full_backtest_btc.R` (+ `code/msgarch_utils_btc.R`). Durée : ≈ 12 minutes.
- Différences déclarées avec l'EUR/USD : rendements en %, moyenne nulle (O4) ; ajustement par fold en multi-départs avec départ chaud (fold précédent), 9 à 10 ajustements par fold ; repli sur le mélange exact si `Risk()` échoue ; niveau 99 % calculé en parallèle ; sauvegarde par fold avec reprise.

## 3. Résultats

| | Dépassements | Attendus | Couverture | Binomial unilatéral | Kupiec | Christoffersen |
|---|---|---|---|---|---|---|
| **95 %** | 156 | 159,7 | **95,11 %** | p = 0,628 | LR = 0,088, p = **0,766** | LR = 0,261, p = **0,610** |
| 99 % (diagnostic) | 27 | 31,9 | 99,15 % | p = 0,833 | LR = 0,811, p = 0,368 | LR = 1,455, p = 0,228 |

- 3 193 prévisions, 0 échec, **1 repli exact** (2020-03-14).
- Dépassements à 95 % : 72 par le bas, 84 par le haut (test de symétrie : p = 0,38).
- **Verdict 4.1 : PASS** (n = 3 193 ≥ 2 500 ; Kupiec p = 0,766 ; Christoffersen p = 0,610).
- Précision : l'intervalle de Wilson à 95 % du taux de dépassement est [4,19 % ; 5,69 %], soit une couverture dans [94,3 % ; 95,8 %]. Le test de Kupiec ne rejette qu'en dehors d'environ [94,2 % ; 95,8 %] ; il ne distingue pas 95,0 % de 94,5 % ou 95,7 %.

## 4. Résultats par fold

| Année | n | Dép. 95 % | Couv. 95 % | Dép. 99 % | Couv. 99 % | Persistance (volatil / calme) | ν (volatil / calme) |
|---|---|---|---|---|---|---|---|
| 2018 | 365 | 24 | 93,42 % | 4 | 98,90 % | 0,9663 / 0,9995 | 5,32 / 2,38 |
| 2019 | 365 | 17 | 95,34 % | 5 | 98,63 % | 0,9728 / 0,9997 | 5,03 / 2,38 |
| 2020 | 366 | 16 | 95,63 % | 3 | 99,18 % | 0,9646 / 0,9996 | 5,09 / 2,37 |
| 2021 | 365 | 19 | 94,79 % | 3 | 99,18 % | 0,9701 / 0,9995 | 4,40 / 2,36 |
| 2022 | 365 | 20 | 94,52 % | 8 | 97,81 % | 0,9703 / 0,9994 | 4,52 / 2,35 |
| 2023 | 365 | 19 | 94,79 % | 2 | 99,45 % | 0,9700 / 0,9995 | 4,18 / 2,38 |
| 2024 | 366 | 18 | 95,08 % | 0 | 100,00 % | 0,9754 / 0,9993 | 4,10 / 2,35 |
| 2025 | 365 | 10 | 97,26 % | 0 | 100,00 % | 0,9798 / 0,9994 | 3,95 / 2,34 |
| 2026* | 271 | 13 | 95,20 % | 2 | 99,26 % | 0,9837 / 0,9991 | 4,07 / 2,32 |

Drapeaux : la persistance du régime calme dépasse 0,999 dans **les 9 folds** (0,9991 à 0,9997) ; aucun drapeau SE(ν) > ν. Le meilleur ajustement vient tantôt du départ chaud (2021, 2024, 2025), tantôt d'un départ « persistant » (2018, 2019, 2020, 2023, 2026), tantôt du départ par défaut (2022) : aucun départ ne suffit seul.

## 5. Ce qu'on voit par sous-période (exploratoire, non corrigé des comparaisons multiples)

- **2018 : sous-couverture modérée** (24 dépassements pour 18,2 ; Kupiec p = 0,19, non significatif). Fold estimé sur 1 201 rendements seulement.
- **2025 : sur-couverture à 95 %** (10 pour 18,2 ; Kupiec p = 0,031 non corrigé, soit non significatif après correction sur 9 folds).
- **2022 : 8 dépassements à 99 % pour 3,6 attendus** (p unilatéral = 0,032, non corrigé).
- **2024-2025 : 0 dépassement à 99 % sur 731 jours** pour 7,3 attendus. Probabilité sous le modèle : 0,0006 (regroupement choisi après coup ; ordre de grandeur de ≈ 0,006 en tenant compte des regroupements possibles). Les bandes à 99 % paraissent trop larges dans cette période de volatilité réalisée basse (écart-type annuel de 2,2 à 2,8 %).
- **Ces écarts sont-ils plus que du bruit ?** Test d'homogénéité du taux de dépassement entre les 9 folds : à 95 %, χ²(9) = 6,5, p = 0,69 (l'écart-type observé des couvertures annuelles, 1,0 point, ne dépasse pas le bruit binomial attendu pour 365 jours, 1,14 point) ; à 99 %, χ²(9) = 14,3, p = 0,11 (approximation grossière : effectifs attendus de 3 à 4 par fold). Les écarts par année **ne sont donc pas établis comme autre chose que du bruit d'échantillonnage**. Le seul motif qui mérite un suivi est l'absence de dépassement à 99 % en 2024-2025, observée après coup. Aucune de ces observations n'était prévue au cadrage ; elles relèvent de l'Option 1.

## 6. Évolution des paramètres entre folds

- Régime calme : ν stable (2,32 à 2,38), persistance entre 0,9991 et 0,9997 (frontière) à chaque fold.
- Régime volatil : ν passe de 5,3 (2018) à 4,0-4,1 (2025-2026) ; persistance de 0,966 à 0,984. Les queues s'alourdissent et la mémoire s'allonge au fil des ré-estimations.

## 7. Le jour de repli

2020-03-14 : `Risk()` renvoie des quantiles incohérents (saturation de la grille après le choc du 12 mars) ; repli sur le mélange exact (bornes de ±25,3 %). Le contrôle de cohérence (`diff(quantiles) > 0`) ne détecte que les ties ; une saturation sur un seul quantile extrême (par exemple 99,5 %) pourrait passer inaperçue. L'impact sur le 95 % serait nul, sur le 99 % marginal (27 contre 31,9).

## 8. Repères avec l'EUR/USD (contexte, pas un critère)

| | EUR/USD | BTC |
|---|---|---|
| Prévisions | 3 424 | 3 193 |
| Folds | 14 | 9 |
| Couverture à 95 % | 95,50 % | 95,11 % |
| Binomial unilatéral | p = 0,919 | p = 0,628 |
| Couverture annuelle | 95,2 % à 95,6 % | 93,4 % à 97,3 % |

Les deux projets passent le contrôle de sous-couverture. La couverture annuelle du BTC est plus dispersée que celle de l'EUR/USD, mais cette dispersion (écart-type de 1,0 point) correspond au bruit binomial attendu pour 365 jours par an (1,14 point) ; celle de l'EUR/USD (95,2 % à 95,6 % sur ≈ 250 jours, bruit attendu de 1,4 point) est au contraire plus resserrée que le hasard ne le laisserait attendre, sans que cela invalide son résultat.

## 9. Ce que le PASS ne dit pas

- Il porte sur la **couverture inconditionnelle et l'indépendance à 95 %**, rien d'autre : ni l'ampleur des dépassements (le 12 mars 2020 reste un dépassement de 39 points), ni la justesse des queues au-delà de 99 %, ni l'utilité des probabilités de régime.
- Il ne distingue pas 95,0 % de 94,5 % ou 95,7 % (puissance de ± 0,76 point).
- Variation par année (section 5) : compatible avec le bruit d'échantillonnage (tests d'homogénéité non significatifs) ; les écarts de signe opposé se compensent dans le total, et la puissance par fold est faible.
- Un seul actif, un seul découpage en folds, une seule exécution : aucune spécification n'a été ajustée après avoir vu les résultats.

## 10. Fichiers produits

- `code/full_backtest_btc.R`, `code/msgarch_utils_btc.R`
- `data/processus/btc_backtest_daily.csv` (prévision, bornes, dépassements, méthode, jour par jour), `btc_backtest_summary.csv`, `btc_backtest_fold_summary.csv`, `btc_backtest_params.csv`, `btc_backtest_fold_YYYY.csv` et `btc_backtest_par_YYYY.csv` (un couple par fold)
