# Étape 2 — GARCH(1,1) sur BTC-USD : Normal vs Student's t

*Option 2 (test de généralisation du pipeline EUR/USD). Structure calquée sur `GARCH_1_1.md`. Cadre et critères : `summary_btc_option2.md` (section 4.6, fixée avant l'estimation).*

## 1. Objectif

Estimer un GARCH(1,1) sur les log-rendements journaliers du BTC (×100), comparer innovations Normal et Student's t, retenir la meilleure spécification par BIC (AIC rapporté), et documenter les diagnostics et les drapeaux, sans explorer d'autres spécifications (hors périmètre de l'Option 2).

## 2. Données et méthode

- 4 394 rendements (2014-09-18 → 2026-09-28), issus de `btc2_01_data.md`.
- Moyenne constante, GARCH(1,1), package `arch`, rendements ×100. Script : `code/garch_btc.py`.
- Diagnostics : Ljung-Box sur z² (lags 10 et 20), ARCH-LM sur résidus **standardisés** (`standardized=True`, leçon du bug documenté dans `GARCH_1_1.md`, section 5.1), kurtosis empirique, demi-vie, σ de long terme, ν et son erreur standard.

## 3. Résultats

| | Normal | Student's t |
|---|---|---|
| μ (%/jour) | 0,1455 (p = 0,001) | 0,1113 (p = 1,2e-4) |
| ω | 0,4995 (p = 5,5e-4) | 0,1906 (p = 0,0146) |
| α | 0,1267 (p = 2,6e-5) | 0,1074 (p = 1,1e-14) |
| β | 0,8431 (p ≈ 0) | 0,8926 (p ≈ 0) |
| ν | — | 3,1757 (SE 0,1224) |
| Log-vraisemblance | −11 294,8 | −10 752,9 |
| AIC | 22 597,7 | **21 515,8** |
| BIC | 22 623,2 | **21 547,7** |
| Persistance α + β | 0,9697 | **1,0000** (frontière) |
| Demi-vie | 22,5 jours | non définie |
| σ de long terme (%/jour) | 4,06 | non défini |
| Ljung-Box z², lag 10 / 20 (p) | 0,895 / 0,989 | 0,914 / 0,950 |
| ARCH-LM standardisé, 10 lags (p) | 0,895 | 0,916 |
| Kurtosis en excès empirique (z) | 11,56 | 12,83 |
| Kurtosis théorique 6/(ν−4) | — | infinie (ν ≤ 4) |

Les deux modèles convergent formellement. Pire choc standardisé (modèle t) : −12,92 le 2020-03-12 ; probabilité de ce niveau ou pire : 1,84e-38 sous la Normal, 7,86e-5 sous la t.

## 4. Sélection

**Student's t retenue** : BIC et AIC concordent. ΔAIC ≈ 1 082 et ΔBIC ≈ 1 076, contre ≈ 162 et ≈ 155 sur l'EUR/USD : l'écart est près de sept fois plus grand, ce qui est cohérent avec des queues bien plus épaisses.

## 5. Lecture des critères de la section 4.6 (fixés avant estimation)

| Critère | Résultat |
|---|---|
| BIC minimal | Student's t ✓ (AIC concordant) |
| Convergence | ✓ formellement, mais **à la frontière α + β = 1** (voir 6.1) |
| Résidus (Ljung-Box, ARCH-LM) | non rejetés sur z² (p > 0,9) ; **rejetés sur \|z\|** (p ≈ 0,01), test ajouté après coup (voir 6.2) : limite documentée |
| Si ν ≤ 4 : pas de comparaison de kurtosis | appliqué : ν = 3,18, kurtosis théorique infinie, la comparaison n'est pas faite |

**Drapeaux déclenchés** (Summary 4.2) : « persistance > 0,999 » et « ν ≤ 4 ». SE(ν) > ν : non (0,12 contre 3,18). Ce sont des drapeaux, pas des pass/fail.

## 6. Problèmes et limites

### 6.1 Frontière IGARCH : trois chiffres à ne pas citer

L'optimiseur de `arch` impose α + β ≤ 1. Ici α + β = 0,107385 + 0,892615 = 1,000000 : le maximum sous contrainte colle à la borne, ce qui suggère que le maximum de vraisemblance libre se situerait au-delà (α + β ≥ 1). Conséquences :
- **Demi-vie** (≈ 8·10¹⁰ jours) et **σ de long terme** (≈ 148 000 %) affichés par le script sont des artefacts numériques : la variance inconditionnelle n'est pas définie quand α + β = 1. Ils ne doivent pas être rapportés.
- **Les erreurs standard de α et β** reposent sur une normalité asymptotique qui ne tient pas à la frontière : à lire avec prudence.
- **ω** (p = 0,015) n'a plus d'interprétation de niveau de long terme.

### 6.2 ν ≈ 3,18 : kurtosis infinie et fiabilité des tests

Avec ν ≤ 4, le moment d'ordre 4 de l'innovation est infini. Deux conséquences :
- La kurtosis empirique (12,83) ne converge vers aucune valeur : elle ne peut pas servir de mesure d'ajustement. La vérification de la section 7.1 de `GARCH_1_1.md` (comparer à 6/(ν−4)) est **inapplicable** ici.
- Ljung-Box et ARCH-LM sur z² supposent que z² a une variance finie, ce qui est faux quand E[z⁴] est infini. Les p-values (> 0,9) sont donc **une preuve faible** d'absence d'ARCH résiduel, pas une preuve forte.

**Test complémentaire sur |z|** (ajouté après coup, pour une raison théorique connue : |z| a une variance finie même si ν ≤ 4, donc Ljung-Box y reste valide ; il n'était pas prévu en 4.6) : lag 10 : stat = 22,03, p = 0,0150 ; lag 20 : stat = 38,27, p = 0,0082. **La dépendance résiduelle est détectée** là où les tests sur z² ne voyaient rien. Conclusion révisée : le GARCH(1,1) t à un régime ne capture pas toute la dynamique de la volatilité, et l'absence de rejet sur z² reflétait un manque de puissance, pas un bon ajustement. La conclusion « pas d'ARCH résiduel » est retirée. Conformément à 4.6, le rejet est documenté comme limite, sans exploration d'autres spécifications. Ce résultat est compatible avec un changement de régime ou de niveau de volatilité (section 8), sans le démontrer : une asymétrie ou une mémoire longue produiraient aussi ce signal. Les p-values ne sont pas corrigées de l'estimation des paramètres.

### 6.3 μ significatif

μ̂ = 0,11 %/jour, p = 1,2e-4, alors que sur l'EUR/USD μ n'était pas significatif. Ce n'est **pas** un signe d'inefficience ou de prévisibilité : c'est la dérive réalisée d'un actif passé d'environ 457 $ à plus de 83 000 $ sur l'échantillon (biais de sélection ex post : le BTC est étudié après coup). La conséquence de conception (moyenne de la fourchette) est traitée en décision ouverte O4 du Summary.

## 7. Interprétation économique (prudente)

- **Persistance** : sous la Normal, un choc de volatilité perd la moitié de son intensité en ≈ 22 jours ; sous la t, il n'y a pas de retour à la moyenne (IGARCH). Comme sur l'EUR/USD (0,9945 → 0,9985), la persistance dépend fortement de l'hypothèse distributionnelle, ici de façon beaucoup plus marquée. On ne rapporte pas une demi-vie unique.
- **Queues** : le pire choc standardisé (−12,92, 12 mars 2020) est absurde sous la Normal (1,84e-38, sans commune mesure avec l'âge de l'univers, ≈ 5·10¹² jours) et plausible sous la t (7,86e-5, environ un jour sur 12 700, soit ≈ 35 ans). Sur 4 394 observations, environ 0,35 événement de ce type est attendu sous la t ; un est observé.

## 8. Hypothèse à tester (pas une conclusion)

Les ruptures de niveau de la variance inconditionnelle font remonter la persistance estimée vers 1 et gonflent les queues d'un GARCH à un seul régime (Lamoureux et Lastrapes, 1990). Le profil de l'écart-type par année (`btc2_01_data.md`) est compatible avec cela, mais ne le démontre pas.

**Prédiction, falsifiable** : si l'explication « ère » est juste, les estimations séparées avant/après la coupure du 2020-09-22 (Summary 4.3) devraient donner une persistance nettement inférieure à 1 et un ν plus élevé que 3,18. Si ce n'est pas le cas, l'hypothèse perd du soutien. La médiane étant une coupure à faible puissance (Summary 4.3), l'absence de confirmation ne l'invaliderait pas non plus définitivement. Le MS-GARCH (étape 3) est le test principal.

## 9. Limites de l'étape

- Spécification choisie sur l'échantillon complet (Normal vs t) : le choix est massif (ΔBIC ≈ 1 076), donc peu sensible au biais de rétrospection ; les paramètres du backtest sont, eux, ré-estimés sur fenêtre extensive.
- Les tests sur z² sont peu puissants (moment d'ordre 4 infini) ; le test sur |z| rejette (6.2).
- Le GARCH est à un seul régime : les résultats de persistance et de ν sont à lire à la lumière de l'étape 3.

## 10. Fichiers produits

- `code/garch_btc.py`
- `data/processus/btc_garch_shocks.csv` (résidus standardisés et volatilité conditionnelle, modèle t)
- `data/processus/btc_garch_step2_table.csv` (tableau comparatif)
- `docs/btc2_qqplot_std_residuals_normal.png`, `docs/btc2_qqplot_std_residuals_t.png` *(générés ; à examiner et à insérer)*

## 11. Points ouverts de cette étape

- Décision O4 (moyenne dans la fourchette), à trancher avant l'étape 5.
- Examiner les deux QQ-plots.
