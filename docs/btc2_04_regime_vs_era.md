# Étape 4 — « Régime » ou « ère » : comparaison avant/après la coupure du 2020-09-22

*Option 2 (test de généralisation du pipeline EUR/USD). Cadre : `summary_btc_option2.md`, sections 4.3 (règle gelée et vérification complémentaire) et 4.7 (prédiction à falsifier, seuils fixés avant exécution).*

## 1. Objectif

Compléter la règle 4.3 (appliquée à l'étape 3 : PAS_ERE) par une vérification indépendante de l'étape 3 : les paramètres d'un GARCH(1,1) Student's t à un seul régime changent-ils entre la première et la seconde moitié de l'échantillon, et la persistance proche de 1 observée à l'étape 2 disparaît-elle quand on estime chaque moitié séparément ? Cette vérification est **corroborante et non décisive** : elle ne peut pas modifier le verdict de la règle 4.3.

## 2. Données et méthode

- Coupure : 2020-09-22, médiane du nombre d'observations de prix (décision O1, validée). **Avant** : 2014-09-18 → 2020-09-21, 2 196 rendements. **Après** : 2020-09-22 → 2026-09-28, 2 198 rendements.
- Modèle : GARCH(1,1) à innovations Student's t, moyenne constante (comme l'étape 2), package `arch`, rendements ×100. Script : `code/chow_garch_btc.py`.
- Test du rapport de vraisemblance de type Chow sur les 5 paramètres (μ, ω, α, β, ν) : LR = 2·(LL_avant + LL_après − LL_complet), comparé à un χ²(5) à 5 %.
- Prédiction (4.7), seuils fixés avant exécution : persistance α + β < 0,99 **et** ν̂ > 3,18 dans les **deux** moitiés.

## 3. Résultats

| | Complet | Avant | Après |
|---|---|---|---|
| Observations | 4 394 | 2 196 | 2 198 |
| Convergence | oui | oui | oui |
| Log-vraisemblance | −10 752,9 | −5 518,99 | −5 223,94 |
| μ (%/jour) | 0,1113 | 0,1583 | 0,0611 |
| ω | 0,1906 | 0,1736 | 0,1047 |
| α | 0,1074 | 0,1276 | 0,0619 |
| β | 0,8926 | 0,8724 | 0,9381 |
| ν (SE) | 3,176 (0,122) | 3,161 (0,148) | 3,275 (0,217) |
| Persistance α + β | 1,0000 | 1,0000 | 1,0000 |
| Demi-vie, σ de long terme | non définis | non définis | non définis |

Les trois estimations sont à la frontière α + β = 1 (contrainte de `arch`) : demi-vie et σ de long terme ne sont pas définis, comme à l'étape 2.

## 4. Test LR de type Chow

LR = 19,91 ; χ²(5) ; p = 0,0013 ; rejet à 5 %.

Réserves : à la frontière α + β = 1 et avec ν ≈ 3 (moment d'ordre 4 infini), la loi χ² n'est pas la loi exacte sous l'hypothèse nulle, et le test peut sur-rejeter. Un p-value calibré par bootstrap paramétrique sous H0 est possible mais n'a pas été fait (voir 8).

## 5. Prédiction 4.7

| Moitié | Persistance < 0,99 | ν̂ > 3,18 |
|---|---|---|
| Avant | **non** (1,0000) | **non** (3,161) |
| Après | **non** (1,0000) | oui (3,275) |

**Verdict : non soutenue.** Le critère décisif est la persistance, à 1,0000 dans les deux moitiés. Le critère sur ν est peu informatif : l'écart au seuil est de 0,02 (avant) et 0,10 (après), très inférieur aux erreurs standard (0,148 et 0,217).

## 6. Drapeaux

Moitiés avant et après : persistance > 0,999 et ν ≤ 4 (aucun drapeau SE(ν) > ν).

## 7. Interprétation

- **La persistance proche de 1 n'est pas expliquée par un seul décalage de niveau entre les deux moitiés.** Elle reste à la frontière dans chacune, et ν reste voisin de 3,2. Ce résultat est cohérent avec celui de l'étape 3 (persistances de 0,988 et 0,999 à l'intérieur des régimes du MS-GARCH).
- **Les paramètres diffèrent pourtant** (p = 0,0013, avec la réserve du 4) : après 2020, α est environ deux fois plus faible (0,128 → 0,062), β plus élevé (0,872 → 0,938), ω plus faible (0,174 → 0,105) et μ plus faible (0,158 → 0,061). À persistance constante, la volatilité réagit moins vivement au choc de la veille et garde plus de mémoire. Les queues (ν) ne changent pas de façon distinguable.
- **Lecture** : une évolution de la dynamique, sans que la persistance ni les queues baissent. Ce n'est pas le profil prédit par l'hypothèse « artefact d'un changement de niveau ». Pour un actif sans ancrage institutionnel, une volatilité très persistante et des queues très lourdes peuvent être des propriétés réelles ; cette lecture est cohérente avec les données mais ne les démontre pas.
- **Conclusion pour l'Option 2** : la règle 4.3 reste **PAS_ERE** ; la vérification complémentaire ne la contredit pas.

## 8. Limites et points ouverts

- **La coupure à la médiane ne capture pas des ruptures à l'intérieur des moitiés** : le MS-GARCH alterne plusieurs fois entre régimes sur l'échantillon, donc chaque moitié contient des changements de niveau. La persistance proche de 1 à l'intérieur des moitiés peut encore refléter de la structure non modélisée (ruptures multiples, mémoire longue) ; ce test ne les distingue pas.
- **À la frontière α + β = 1, la répartition entre α et β est mal déterminée** : les écarts de α et β entre moitiés sont à lire avec prudence (les erreurs standard de α, β, ω et μ ne sont pas affichées par le script).
- **P-value par bootstrap paramétrique** (simuler sous H0 à partir du GARCH-t du plein échantillon, recalculer le LR avec la même coupure) : non fait ; optionnel.
- **Une seule coupure** : conformément à O1, aucune autre date n'a été essayée (une coupure choisie après coup donnerait le résultat attendu).

## 9. Fichiers produits

- `code/chow_garch_btc.py`
- `data/processus/btc_chow_garch_table.csv` (paramètres des trois estimations)
- `data/processus/btc_chow_garch_lr.csv` (LR, p-value, seuils, verdict de la prédiction)
