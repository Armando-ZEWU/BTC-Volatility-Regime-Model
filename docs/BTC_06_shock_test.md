# Étape 6 — Test de choc qualitatif : janvier-avril 2020

*Option 2 (test de généralisation du pipeline EUR/USD). Structure calquée sur `Covid_Robustness_Test.md`. Statut fixé avant exécution (Summary 4.5) : **qualitatif, hors critère de succès**.*

## 1. Objectif et design

Vérifier comment un modèle qui n'a jamais vu le choc se comporte pendant celui-ci. Le MS-GARCH(K=2) est **ré-estimé sur les données jusqu'au 2019-12-31** (1 931 rendements, 2014-09-18 → 2019-12-31), puis **gelé**. Prévision à 1 jour pour chacun des **121 jours du 2020-01-01 au 2020-04-30** (marché 7j/7 ; EUR/USD : 84 jours de bourse), avec l'historique étendu jour après jour. Scripts : `code/covid_shock_test_btc.R`, `code/msgarch_utils_btc.R`.

Différences déclarées avec l'EUR/USD : ajustement multi-départs (le départ par défaut ne trouve pas l'optimum global, étape 3) ; niveau 99 % rapporté ; repli sur le mélange exact si `Risk()` échoue ; diagnostic intrajournalier High/Low **de la même source** (yfinance), sans décalage inter-sources (l'EUR/USD comparait FRED à Pound Sterling Live).

## 2. Modèle pré-2020

Les 19 ajustements convergent vers **le même optimum** (LL = −4 814,95).

| | Régime volatil (indice 1) | Régime calme (indice 2) |
|---|---|---|
| ω / α / β | 1,325 / 0,138 / 0,826 | 0,0455 / 0,0588 / 0,9409 |
| Persistance | 0,9646 | 0,9996 (**drapeau > 0,999**) |
| ν (SE) | 5,09 (1,01) | 2,37 (0,080) (**ν ≤ 4**) |
| P(rester) | 0,9748 | 0,9759 |
| Écart-type réalisé (jours dominants) | 4,85 %/jour | 2,55 %/jour |

La structure est analogue à celle de l'échantillon complet (calme : ν = 2,30 et persistance 0,999 ; volatil : ν = 3,95 et 0,988) : elle existait avant le choc. Contrairement à l'EUR/USD, dont le ν du régime de stress n'était pas identifié avant 2020 (ν₂ = 71,7, SE = 202), les queues du BTC sont **bien identifiées** (SE(ν) = 0,08 pour le régime calme) : la décennie 2014-2019 contient assez d'extrêmes pour les estimer.

## 3. Couverture (121 prévisions, aucune manquante)

| | Dépassements | Attendus | Couverture | Binomial unilatéral | Kupiec | Christoffersen |
|---|---|---|---|---|---|---|
| 95 % | 5 | 6,05 | 95,87 % | p = 0,729 | LR = 0,203, p = 0,652 | p = 0,510 |
| 99 % (diagnostic) | 1 | 1,21 | 99,17 % | p = 0,704 | LR = 0,039, p = 0,843 | p = 0,897 |

Avec n = 121, la puissance est faible : une absence de rejet n'est pas une validation. Le résultat établit seulement qu'il n'y a pas d'effondrement de la couverture pendant un choc majeur (EUR/USD, mêmes dates : 91,7 % sur 84 jours, p = 0,127).

## 4. Les dépassements à 95 %

| Date | Rendement | Borne basse / haute | Direction | Dépassement | P(volatil) à la prévision |
|---|---|---|---|---|---|
| 2020-01-03 | +5,02 % | −4,86 / +4,86 | haut | 0,15 pt | 23,9 % |
| 2020-01-14 | +8,06 % | −6,70 / +6,65 | haut | 1,41 pt | 76,7 % |
| 2020-03-08 | −9,43 % | −6,32 / +6,26 | bas | 3,11 pt | 68,0 % |
| 2020-03-12 | **−46,47 %** | −7,07 / +7,07 | bas | **39,40 pt** | 50,2 % |
| 2020-04-29 | +11,98 % | −6,55 / +6,55 | haut | 5,44 pt | 23,3 % |

- La **fréquence** des dépassements est correcte ; l'**ampleur** du 12 mars (−46,5 % pour une borne à −7,1 %, soit 6,6 fois la borne) montre qu'aucune bande à 95 % ne contient un tel jour. La couverture ne mesure pas l'ampleur des dépassements.
- La veille du krach, P(volatil) = 50 % : le modèle hésitait entre les deux régimes, ce que confirme la figure 02 (le choc est attribué au régime calme, à queues très lourdes).
- Aucun dépassement n'a eu lieu avec P(volatil) > 95 %. Le groupe « régime déjà en stress » identifié sur l'EUR/USD n'a pas d'équivalent ici ; l'étiquette « volatil » ne désigne de toute façon pas « stress » (btc2_03, 5bis).

## 5. Le jour sans prévision de la première exécution : 2020-03-14

À la première exécution, `Risk()` a échoué ce jour-là (deux jours après le plus gros choc). La cause, consignée par la v2 du script : `Risk()` a renvoyé des quantiles **incohérents** (−37,74 ; −24,03 ; +26,48 ; +26,48), les deux bornes hautes à 95 % et 99 % étant **identiques** : saturation de la grille numérique à la borne supérieure de la grille, après un choc qui a porté la variance conditionnelle à un niveau extrême.

Repli sur le mélange exact (récursion de variance validée à l'étape 5) : bornes de ±25,28 % à 95 %. Rendement réalisé : −6,75 %, **dans la bande** (pas de dépassement). Le jour manquant n'a donc pas biaisé la couverture : 5 dépassements sur 120 (95,83 %) devenaient 5 sur 121 (95,87 %).

## 6. Diagnostic intrajournalier (95 %, non décisif)

Jours touchant hors de la bande (clôture, High ou Low) : **7 sur 121** (les 5 dépassements de clôture + 2), soit 5,8 %. EUR/USD : 19 sur 84 (22,6 %).

Sur un marché 7j/7, la clôture de minuit UTC est un instantané d'un marché qui n'a jamais fermé : le High et le Low du jour bordent la même trajectoire que le rendement de clôture à clôture, d'où un écart intrajournalier beaucoup plus faible que sur l'EUR/USD (où l'écart venait aussi du décalage entre le taux de midi de FRED et la clôture). Le rendement est mesuré par rapport à la clôture de la veille.

## 7. Limites

- Un seul choc, 121 jours : puissance faible. Test qualitatif, hors critère de succès (étape 7 pour le test à portée statistique).
- La couverture compte les dépassements, pas leur ampleur.
- La grille de `Risk()` sature dans les conditions extrêmes ; le repli exact traite ce cas, mais le contrôle de cohérence ne détecte que les quantiles non croissants.
- Les étiquettes « volatil » et « calme » ne désignent pas « crise » et « non-crise ».

## 8. Fichiers produits

- `code/covid_shock_test_btc.R`, `code/msgarch_utils_btc.R`
- `data/processus/btc_covid_result.csv`, `btc_covid_summary.csv`, `btc_covid_intraday.csv`, `btc_covid_pre2020_flags.csv`, `btc_covid_pre2020_par.rds` (valeurs numériques)
