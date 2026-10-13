# Summary BTC Option 2 — Test de généralisation du pipeline EUR/USD sur le Bitcoin

*Document de travail — v3 (2026-10-13). Cadrage consolidé et état final : les huit étapes sont exécutées et le verdict est rendu (section 10). Les critères de succès ont été fixés avant toute estimation de modèle.*

*Papier : Zewu (2026), « Predicting a Bitcoin Price Range: An Out-of-Sample Test » (lien SSRN à ajouter). Dépôt : https://github.com/Armando-ZEWU/BTC-Volatility-Regime-Model. Projet compagnon : Zewu (2026), « Quantitative Modeling of EUR/USD Exchange Rate Volatility », SSRN Working Paper No. 7532760.*

*Numérotation : les sections 4.1 à 4.7 et les décisions O1 à O4 sont citées dans les figures et dans les notes d'étape. Ne pas les renuméroter.*

---

## 0. Conventions du projet

- **Destination** : dépôt GitHub (code, données, sorties, notes) et working paper en anglais. Ce document est le **résumé cumulatif** : il garde le cadrage, ses corrections et le résultat final.
- **Un document par étape**, rangés dans `docs/` (notes de travail en français). Le papier est la synthèse publiable.
- **Arborescence** : `code/` (scripts Python et R), `data/raw/` (téléchargement brut), `data/processus/` (séries et résultats dérivés), `docs/` (documents .md), `graphs/` (figures ggplot2, étiquettes en français).
- **Les erreurs et corrections sont documentées, pas effacées** (section 6). Le papier les reprend dans son annexe « Corrections log ».
- **Statut des décisions** : `[Validé]` = accepté explicitement ; `[Hérité]` = repris du projet EUR/USD. Plus aucune décision n'est ouverte.

## 1. Objectif

La question posée est : **peut-on construire un price range à 1 jour pour le Bitcoin, calibré hors échantillon, et que peut en faire un analyste du marché ?** L'objet d'étude n'est pas « le Bitcoin en soi » mais **le pipeline lui-même** : le raisonnement établi sur l'EUR/USD (log-rendements, GARCH Student's t, MS-GARCH Haas et al., fourchette via `Risk()`, backtest en fenêtre extensive) produit-il un résultat **cohérent et statistiquement calibré** quand on l'applique à un actif très différent ?

Ce n'est ni un outil de gestion du risque, ni la recherche d'un nouveau modèle, ni une prétention de découverte. Les tests de couverture (Kupiec, Christoffersen) viennent de la littérature de backtesting parce qu'ils vérifient exactement la propriété voulue d'un intervalle : la part des jours où la clôture tombe à l'intérieur.

Un résultat différent de l'EUR/USD n'est ni un échec ni un succès : les critères de succès (4.1, 4.3) sont propres au BTC, et les comparaisons avec l'EUR/USD ne servent que de contexte.

**Limite assumée du design** : on suppose K=2 (choix tranché sur l'EUR/USD, pas sur le Bitcoin) tout en testant la généralisation. Si K=2 fonctionne, on ne saura pas totalement si c'est le pipeline qui généralise ou le K forcé. Cette limite est compensée par le test « régime vs ère » (section 4.3).

## 2. Ce qui est transposé, et ce qui ne l'est pas

**Repris tel quel `[Hérité]`** :
- Rendements log.
- GARCH(1,1), comparaison Normal vs Student's t par AIC/BIC, sans nouvelle exploration de distributions.
- MS-GARCH via `MSGARCH` (R), spécification Haas et al. (2004), **K=2 par défaut de départ**.
- Fourchette de prix via `Risk()`, mélange pondéré par les probabilités de régime.
- Design du backtest : fenêtre extensive (West, 1996), paramètres gelés entre deux ré-estimations annuelles, vérifications de convergence automatiques, seuils d'alerte déjà calibrés (persistance > 0,999 ; SE(ν) > ν).

**Volontairement non refait au départ** : régression sur la direction, régression sur la magnitude comme étape à part, HMM séparé de détection de régime. Ces résultats étaient traités comme des propriétés générales de marché.

**Ajouts après coup** (exploratoires, voir 4.4 et section 10) : comparaison à des modèles simples, calibration conditionnelle, taille des dépassements, et trois tests de direction (`btc2_08_verification.md`).

**Exception introduite** : le test de stabilité par sous-périodes, exclu du cadrage initial, est **réintégré sous forme ciblée** (section 4.3), car le risque « ère vs régime » le justifie.

## 3. Itinéraire

| # | Étape | Document | Statut |
|---|---|---|---|
| 1 | Données `BTC-USD` (yfinance), contrôle qualité, rendements log | `btc2_01_data.md` | exécutée |
| 2 | GARCH(1,1) Normal vs Student's t, meilleur par AIC/BIC | `btc2_02_garch.md` | exécutée |
| 3 | MS-GARCH K=2 (Haas et al.), diagnostics de convergence | `btc2_03_msgarch.md` | exécutée |
| 4 | Diagnostic « régime vs ère » (sous-périodes ciblées) | `btc2_04_regime_vs_era.md` | exécutée |
| 5 | Fourchette de prix opérationnelle (`Risk()`) | `btc2_05_price_range.md` | exécutée |
| 6 | Test de robustesse sur un choc (qualitatif) | `btc2_06_shock_test.md` | exécutée |
| 7 | Backtest complet en fenêtre extensive + tests de couverture | `btc2_07_backtest.md` | exécutée |
| 8 | Verdict vs critère de succès, conclusion | section 10 de ce Summary | rendu |
| + | Vérifications complémentaires (exploratoires) | `btc2_08_verification.md` | exécutées |
| + | Lecture économique | `Economics.md` | rédigée |

## 4. Critère de succès

### 4.1 Pass/fail — couverture et indépendance `[Validé]`

Fourchette nominale à **95 %**, prévisions à 1 jour, fenêtre extensive, paramètres gelés.

| Test | Règle | Seuil |
|---|---|---|
| Nombre de prévisions hors-échantillon | n ≥ 2500 | condition préalable |
| Couverture inconditionnelle | Kupiec (POF), **bilatéral** | non rejeté à 5 % |
| Indépendance des dépassements | Christoffersen | non rejeté à 5 % |
| Comparabilité avec l'EUR/USD | binomial **unilatéral** (sous-couverture), comme dans le papier EUR/USD | rapporté, non décisif |

Repère : sur l'EUR/USD, couverture 95,50 % (3270/3424), p binomial = 0,919. À n ≈ 3000, l'écart-type de la couverture est d'environ 0,4 point : le Kupiec à 5 % rejette hors de ~94,3 %–95,7 %. Une zone « ni succès ni échec » n'existe donc pas : **toute couverture rejetée par le test est un échec**.

**Coût assumé** : deux tests à 5 % donnent environ 10 % de risque de faux rejet sur un modèle parfaitement calibré. Ce risque est documenté, pas corrigé (la puissance vient de n, pas du seuil).

### 4.2 Diagnostics à drapeaux (pas de pass/fail)

- Persistance > 0,999 ; SE(ν) > ν ; ν par régime.
- Couverture par fold / par année.
- **Couverture à 99 %** rapportée à côté du 95 % `[Validé]` (sans pass/fail) : si ν est mal estimé (probable sur BTC), le 95 % peut passer alors que les queues sont fausses.

### 4.3 Interprétabilité : « régime » ou « ère » ? `[Validé — gelé le 2026-09-30]`

Risque identifié : la volatilité du BTC a baissé de façon séculaire (2014-2017 très différent d'aujourd'hui) et le marché a connu des ruptures structurelles. Un MS-GARCH K=2 peut alors séparer « vieille époque » et « époque récente » : convergence propre, diagnostics corrects, mais **aucun régime de peur**.

**Règle** (probabilités **lissées** de l'estimation sur l'échantillon complet, seuil 0,5, car on cherche la structure) : le résultat est classé **« ère »** si :
- il n'y a **qu'une seule bascule** de régime sur tout l'échantillon (bascule à sens unique), **ou**
- le régime volatil forme **un unique bloc continu couvrant plus de 40 %** de l'échantillon.

Un unique épisode de crise (entrée puis sortie) **n'est pas** une ère : c'est un régime légitime rare et collant. Le seuil de 40 % est arbitraire ; il est fixé avant toute estimation de modèle et **gelé le 2026-09-30**. La règle ne détecte que l'ère : « PAS_ERE » ne dit pas que les régimes sont des « régimes de peur ».

**Transparence** : l'écart-type de r par année (étape 1) a été observé *avant* ce gel. Il montre 2017-2022 entre 3,4 % et 4,9 %, contre 2,2 % à 2,8 % depuis 2023 ; 2017-2022 pèse ≈ 50 % de l'échantillon, donc au-dessus du seuil si un MS-GARCH K=2 sépare ces deux périodes. Le seuil n'a pas été ajusté en conséquence.

Dans le backtest, on utilise les probabilités **filtrées** (seules disponibles en temps réel).

**Vérification complémentaire `[Validé]`** : estimer le GARCH(1,1) Student's t séparément avant et après la **coupure du 2020-09-22** (médiane des 4 395 prix : 2 197 prix avant, 2 198 après, soit 2 196 et 2 198 rendements ; 2014-09-18 → 2020-09-21 et 2020-09-22 → 2026-09-28). Comparaison par un **test du rapport de vraisemblance de type Chow** sur les 5 paramètres (μ, ω, α, β, ν), χ²(5) à 5 %. Cette vérification est **corroborante, non décisive** : la médiane coupe à travers des années calmes et agitées et le test peut sur-rejeter quand la persistance est proche de 1 et ν bas. Elle ne peut pas modifier le verdict de la règle.

**Conséquence** : un verdict « ère » = **échec sur l'interprétabilité**, même si la couverture passe.

### 4.4 Règle de décision finale

L'Option 2 est **réussie** si : 4.1 passé (Kupiec et Christoffersen non rejetés, n ≥ 2500) **et** 4.3 non classé « ère ». Sinon : documenter pourquoi avant de basculer vers l'Option 1.

**Réserve établie après coup** : ce critère est **peu discriminant** (correction C13) : un modèle simple (EWMA + simulation historique filtrée) le passe aussi, à largeur de bande quasi identique.

### 4.5 Test de choc `[Validé]`

- Choc : **mars 2020**, qui contient le plus grand |rendement| de l'échantillon (−46,5 % en log-rendement le 2020-03-12), choisi avant l'estimation (estimation sur données strictement antérieures, paramètres gelés).
- **Statut : qualitatif, hors critère de succès.** Une fenêtre d'environ 120 jours n'a pas la puissance d'un test décisif.
- Fenêtre : 2020-01-01 → 2020-04-30 (121 jours, marché 7j/7), modèle ré-estimé sur les données jusqu'au 2019-12-31 (1 931 rendements) puis gelé.

### 4.6 Lecture de l'étape 2 (GARCH) `[Appliqué tel quel]`

Fixée avant toute estimation GARCH sur les données BTC. Aucun pass/fail supplémentaire : l'étape 2 alimente les drapeaux de 4.2.

- **Spécification retenue** : BIC minimal (AIC rapporté ; en cas de désaccord, les deux sont documentés et le BIC tranche).
- **Convergence** de l'optimiseur exigée ; sinon l'étape est refaite avant toute interprétation.
- **Résidus** : Ljung-Box sur z² (lags 10 et 20) et ARCH-LM standardisé (10 lags). Un rejet à 5 % est **documenté comme limite**, sans exploration d'autres spécifications.
- **Si ν̂ ≤ 4** : la kurtosis théorique 6/(ν − 4) est infinie ; la comparaison avec la kurtosis empirique n'est pas faite et on le documente.

### 4.7 Prédiction à falsifier (étape 4) `[Appliqué tel quel]`

Issue de `btc2_02_garch.md` (section 8) : si un changement de niveau de volatilité gonfle la persistance et les queues d'un GARCH à un seul régime, les estimations séparées avant/après la coupure du 2020-09-22 doivent donner, **dans les deux moitiés**, une persistance α + β **< 0,99** et un ν̂ **> 3,18** (valeur du plein échantillon). Seuils fixés avant exécution.

- Verdict « soutenue » seulement si les quatre conditions sont réunies ; sinon « non soutenue », avec la moitié et le critère en cause.
- Statut identique au test LR : corroborant, non décisif. Pour un actif sans ancrage institutionnel, ces propriétés peuvent être réelles ; « non soutenue » ne serait pas un échec.
- **Résultat : non soutenue** (persistance 1,0000 dans les deux moitiés ; `btc2_04_regime_vs_era.md`).

## 5. Décisions pratiques

- **Source** : `yfinance`, ticker `BTC-USD`. Clôture à minuit UTC.
- **Bougie du jour exclue** : la dernière observation (jour de téléchargement, incomplète) est retirée systématiquement. Le fichier brut (téléchargé le 2026-09-30 à 01:39 UTC) se termine par le 2026-09-28 puis une barre en cours du 2026-09-30 ; il n'y a pas de ligne pour le 2026-09-29. L'échantillon d'analyse s'arrête au 2026-09-28.
- **Historique** : ce que la source renvoie de façon fiable ; début effectif constaté le 2014-09-17.
- **Cotation 7j/7** : pas de gap de week-end ; annualisation sur 365 jours (pas 252). « Jour suivant » = jour calendaire suivant.
- **Unités** : tous les rendements sont des **log-rendements en %**. Le −46,5 % du 2020-03-12 est un log-rendement, soit une baisse de prix de 37,2 %.
- **Contrôle qualité (étape 1)** : zéro jour manquant, examen du top |r|, Ljung-Box sur r², écart-type par année.
- **Étape 3 (MS-GARCH)** : rendements ×100, moyenne nulle (`MSGARCH` n'estime pas de moyenne), benchmark K=1 estimé dans `MSGARCH`, ajustement final = meilleur optimum parmi 21 ajustements (défaut, 8 départs perturbés, 12 départs « régimes persistants »). Leçon : ni le point de départ par défaut ni son voisinage ne trouvent l'optimum global.
- **Source unique** : les prix n'ont pas été recoupés avec un second fournisseur.

## 6. Corrections apportées

| # | Problème repéré | Correction |
|---|---|---|
| C1 | **Raisonnement circulaire** : K=2 supposé tout en testant la généralisation | Limite assumée (section 1) + test « régime vs ère » (4.3) |
| C2 | **Critère de succès trop mou** : « pas 60 % » laissait une zone grise de 60 % à 94 % | Seuils chiffrés (4.1), aucune zone grise |
| C3 | **Binomial unilatéral** : ne détecte pas une fourchette trop large | Kupiec bilatéral ajouté |
| C4 | **Dépassements groupés** non testés formellement | Christoffersen ajouté |
| C5 | **Règle « ≤ 2 bascules = ère » fausse** : un épisode de crise unique fait 2 bascules et reste un régime légitime | Règle remplacée : bascule unique ou bloc unique > 40 % (4.3) |
| C6 | **Lissées vs filtrées** non distinguées | Lissées pour le diagnostic de structure, filtrées pour le backtest |
| C7 | **Test de choc présenté comme critère** alors que sa puissance est faible | Statut qualitatif, hors critère (4.5) |
| C8 | **Test de stabilité par sous-périodes exclu** du cadrage initial | Réintégré de façon ciblée (section 2) |
| C9 | **« Paramètres radicalement différents »** : critère flou | Test LR de type Chow, χ²(5) à 5 %, corroborant et non décisif (4.3) |
| C10 | **Redémarrages mal conçus (script v2)** : probabilités de transition écrêtées à [0,6 ; 0,995], donc seulement des départs de micro-régimes ; un optimum local pris pour global | Départs « régimes persistants » et bruit en logit (v3) : l'optimum global (−10 708,78) change la lecture (régimes de 36 et 73 jours au lieu de 2 et 6) |
| C11 | **Colonne `Pr(>|t|)` de `MSGARCH` unilatérale** lue comme bilatérale | p bilatéral = 2 × la valeur affichée |
| C12 | **Effectifs des moitiés mal comptés** : « 2 197 rendements de chaque côté » | Corrigé : 2 196 et 2 198 rendements (médiane des 4 395 prix) |
| C13 | **Le critère 4.1 ne discrimine pas** : EWMA + simulation historique filtrée le passe aussi (Kupiec p = 0,452 ; Christoffersen p = 0,177), à largeur quasi identique | Références simples ajoutées en vérification exploratoire (`btc2_08_verification.md`) ; la conclusion le dit |
| C14 | **Dernière ligne du fichier brut mal décrite** : la documentation plaçait la bougie incomplète au 2026-09-29 | Corrigé : le fichier se termine par le 2026-09-28 puis une barre en cours du 2026-09-30 (incohérente : clôture sous le plus bas) ; pas de ligne pour le 2026-09-29. L'échantillon est inchangé |
| C15 | **Unité du −46,5 %** non précisée | Précisé : log-rendement, soit −37,2 % en prix ; le dépassement de 39,4 « points » est en points de log-rendement |

## 7. Décisions

- **O1 `[Validé]`** : coupure au **2020-09-22** (médiane par nombre d'observations, choisie sans regarder les données pour éviter une coupure qui raconte une jolie histoire ; 2023 et les dates « narratives » écartées). Voir 4.3.
- **O2 `[Validé]`** : fenêtre initiale d'estimation du 2014-09-17 au 2017-12-31 (≈ 1 200 jours), premier test le 2018-01-01, soit 3 193 prévisions et 9 ré-estimations annuelles (2018-2026, la dernière partielle). Compromis assumé : la bulle de 2017 est dans l'estimation, pas dans le test, et le premier fold repose sur peu d'historique.
- **O3 `[Validé]`** : diagnostic de couverture à 99 % (rapporté, sans pass/fail) et mars 2020 comme choc qualitatif. La règle 4.3 est validée et gelée.
- **O4 `[Validé]`** : traitement de la moyenne dans la fourchette. μ̂ est significatif sur BTC (≈ 0,11 %/jour sur l'échantillon complet, ≈ 0,29 %/jour sur la fenêtre initiale 2014-2017), contrairement à l'EUR/USD. `MSGARCH` n'estime pas de moyenne : l'étape 3 est à μ = 0 par construction ; on ne change rien, comme sur l'EUR/USD. Décalage d'environ 0,075 σ par jour sur la fenêtre initiale : effet négligeable sur la couverture à 1 jour.

## 8. Suivi d'avancement

- [x] Cadrage initial et révision du critère de succès
- [x] Consolidation de ce Summary
- [x] Étape 1 — données et contrôle qualité (`btc2_01_data.md`)
- [x] Étape 2 — GARCH(1,1) (`btc2_02_garch.md`)
- [x] Étape 3 — MS-GARCH K=2 (`btc2_03_msgarch.md`)
- [x] Étape 4 — régime vs ère (`btc2_04_regime_vs_era.md`) : règle 4.3 PAS_ERE ; test LR p = 0,0013 (corroborant) ; prédiction 4.7 non soutenue
- [x] Étape 5 — fourchette de prix (`btc2_05_price_range.md`)
- [x] Étape 6 — test de choc, qualitatif (`btc2_06_shock_test.md`)
- [x] Étape 7 — backtest (`btc2_07_backtest.md`) : verdict 4.1 PASS
- [x] Étape 8 — verdict vs critère : Option 2 réussie au sens de 4.4 (section 10)
- [x] Vérifications complémentaires exploratoires (`btc2_08_verification.md`, `verification_btc.R`, `backtest_stats_btc.py`)
- [x] Analyse de la distribution (`graphs_distribution_btc.R`) et lecture économique (`Economics.md`)
- [x] Papier rédigé en anglais ; README du dépôt

## 9. Journal

- **2026-09-29** — Cadrage initial relu de façon critique ; corrections C1 à C8 ; critère de succès chiffré ; règle « régime vs ère » définie.
- **Étape 1** — 4 395 prix du 2014-09-17 au 2026-09-28, aucun jour manquant, aucun prix ≤ 0, un rendement nul (2017-02-28) ; prix non stationnaire, rendements stationnaires ; effets ARCH très significatifs.
- **2026-09-30** — Validation de O1 et O2 ; gel de la règle 4.3 (avec mention que l'écart-type par année avait été vu avant) ; test LR de type Chow à la place du critère flou « radicalement » (C9).
- **Étape 2** — GARCH(1,1) sur 4 394 rendements. Student's t retenu (ΔAIC ≈ 1 082, ΔBIC ≈ 1 076). ν̂ = 3,18 (SE 0,12) ; α + β = 1,0000 (frontière IGARCH) ; drapeaux « persistance > 0,999 » et « ν ≤ 4 » ; pas d'ARCH résiduel sur z² (tests peu puissants, moment d'ordre 4 infini) mais dépendance résiduelle sur |z| (p ≈ 0,015 au lag 10, 0,008 au lag 20 ; test ajouté après coup).
- **Étape 3** — MS-GARCH K=2. Les deux premières exécutions ne trouvaient que des micro-régimes (optimum local à −10 713,36, durées de 2 et 6 jours) ; défaut de conception corrigé en v3 (C10). Optimum retenu : LL = −10 708,78, retrouvé 10 fois sur 12 départs « persistants » ; régimes de 73 et 36 jours (volatil ≈ 69 % des jours, σ réalisé 3,81 %/jour, ν = 3,95 ; calme σ réalisé 2,61 %/jour, ν = 2,30, persistance 0,99900). K=2 devant K=1 (ΔAIC ≈ −81, ΔBIC ≈ −43). Règle 4.3 : PAS_ERE (51 bascules, plus long bloc volatil 676 jours, 15,4 %). 42,6 % de jours ambigus. Le choc de mars 2020 est attribué au régime « calme ».
- **Étape 4** — LR de type Chow : 19,91, χ²(5), p = 0,0013 (rejet à 5 %, avec réserve de sur-rejet près de la frontière). Persistance 1,0000 dans les deux moitiés ; ν = 3,16 et 3,28. Après 2020 : α deux fois plus faible, β plus élevé. Prédiction 4.7 non soutenue. Règle 4.3 inchangée.
- **Étape 5** — Prévision pour le 2026-09-29 (dernier prix 83 502,61 $) : P(volatil) = 14,8 % ; volatilité prévue 2,694 %/jour ; **fourchette à 95 % = [80 139 $ ; 86 997 $]** (largeur 8,21 %) ; 99 % : [76 974 $ ; 90 574 $]. Récursion de variance validée contre `predict()`. `Risk()` contre quantiles exacts : écart ≤ 0,5 % à 95 % et 99 %, jusqu'à −9 % à 50 %.
- **Étape 6** — Modèle pré-2020 (LL −4 814,95, 19 ajustements au même optimum) ; 121 prévisions. Couverture 95,87 % (5 dépassements pour 6,05 ; Kupiec p = 0,652 ; Christoffersen p = 0,510) ; 99 % : 99,17 %. Le jour 2020-03-14 est traité par repli sur le mélange exact (`Risk()` saturait ; la première exécution l'avait laissé sans prévision). Dépassement du 2020-03-12 : −46,5 % (log-rendement) pour une borne à −7,1 %.
- **Étape 7** — 3 193 prévisions, 9 folds, 1 repli exact. **Couverture 95,11 %** (156 dépassements pour 159,7 ; Wilson 94,3 %–95,8 %) : **Kupiec p = 0,766, Christoffersen p = 0,610**, binomial unilatéral p = 0,628 ; **verdict 4.1 : PASS**. 99 % : 99,15 %, 27 dépassements pour 31,9. Dépassements 72 bas / 84 haut. Persistance du régime calme > 0,999 dans les 9 folds. Variation par année non distinguable du bruit.
- **Étape 8** — Critère 4.4 : 4.1 passé et 4.3 non classé « ère » : **Option 2 réussie** (section 10).
- **Compléments** — (A) MS-GARCH meilleur score d'intervalle des cinq modèles, de peu à 95 % (1,6 % à 4,2 %), seul l'écart avec EWMA + FHS survit à Bonferroni (p = 0,008) ; GARCH-t K=1 et EWMA Normale sous-couvrent ; la simulation historique échoue l'indépendance. (B) Couverture la plus uniforme par tercile de largeur, mais classement des jours risqués pas meilleur qu'un EWMA (R² 0,085 contre 0,088). (C) Dépassements à 95 % : médiane 1,45 point, 17 sur 156 au-delà d'une demi-largeur, maximum 5,6 demi-largeurs. (D) Direction : persistance du signe à 1 jour 48,1 % (p = 0,011), tendance sur 20 jours 50,6 % (p = 0,50).
- **Papier et dépôt** — Papier en anglais, README du dépôt, script `backtest_stats_btc.py` pour les statistiques complémentaires, corrections C14 et C15.

## 10. Conclusion finale

**Verdict.** Critère 4.4 : **Option 2 réussie**. Le critère 4.1 est passé (n = 3 193 ≥ 2 500 ; Kupiec p = 0,766 ; Christoffersen p = 0,610) et la règle 4.3 ne classe pas le résultat en « ère » (PAS_ERE, appliquée à l'optimum global ; les dix ajustements à moins de 3 points de log-vraisemblance donnent le même verdict).

**Ce que le résultat montre.** Appliqué au BTC avec trois adaptations déclarées (ajustement multi-départs, repli exact quand `Risk()` sature, lecture prudente des étiquettes de régime), le pipeline construit sur l'EUR/USD produit des fourchettes à 95 % à 1 jour calibrées hors échantillon : couverture de 95,11 % (intervalle 94,3 % à 95,8 %), dépassements indépendants, sans effondrement lors du choc de mars 2020 (95,87 % sur 121 jours, test qualitatif). La fourchette sert de **jauge de l'ampleur d'une journée ordinaire** (environ ± 4 % en fin d'échantillon).

**Ce qu'il ne montre pas.**
- L'**ampleur** des dépassements et les queues au-delà de 99 % : le 12 mars 2020 (−46,5 % en log-rendement, soit −37,2 % en prix, pour une borne à −7,1 %) compte pour un seul dépassement ; le 99 % est rapporté sans pass/fail (99,15 %, 27 dépassements pour 31,9, dont aucun en 2024-2025, observation faite après coup).
- Une calibration plus fine que ± 0,76 point, et le risque de faux rejet d'environ 10 % lié aux deux tests à 5 %.
- L'utilité des **probabilités de régime** : les étiquettes « volatil » et « calme » ne désignent pas « crise » et « non-crise », sont relatives à chaque ré-estimation, et 43 % des jours restent ambigus à l'optimum final ; la probabilité de régime ne classe pas mieux les jours risqués qu'un EWMA.
- Une lecture structurelle solide : ν ≤ 4 dans les deux régimes, persistance du régime calme à la frontière dans les 9 folds ; l'hypothèse « ère » n'est pas soutenue (étape 4), mais ce test est corroborant, non décisif. L'indice de queue n'est pas identifié (Hill sans plateau).
- Plus d'un actif, d'un découpage en folds ou d'une exécution.
- Que le MS-GARCH soit **nécessaire** : le critère 4.1 est aussi passé par EWMA + simulation historique filtrée. Le MS-GARCH reste le meilleur au score d'intervalle (de 1,6 % à 4,2 % à 95 %, solide statistiquement face à EWMA + FHS seulement) ; son apport est la calibration des queues et l'uniformité de la couverture, non le classement des jours risqués.
- La direction : rien d'exploitable avec les trois signaux testés ; ce n'est pas une preuve d'imprévisibilité.

**Repères avec l'EUR/USD (contexte, pas un critère).** Durées espérées des régimes d'environ 73 et 36 jours (contre 160 et 404 jours de bourse) ; ν de 2,3 à 4 (contre 7 à 22) ; couverture de 95,11 % (contre 95,50 %).

**Corrections en route.** Quinze corrections sont consignées en section 6. La plus lourde de conséquences : un optimum local du MS-GARCH pris pour l'optimum global (C10), qui aurait donné des régimes de 2 et 6 jours au lieu de 73 et 36.

**Pistes ultérieures** (à tester, non à présumer) :
- pourquoi le MS-GARCH(K=2) sépare échelle et queues plutôt que calme et crise (tester K ≥ 3 ou d'autres définitions de régime) ;
- la sur-couverture à 99 % en 2024-2025, et la dérive vers le conservatisme : une fenêtre glissante s'adapterait-elle mieux qu'une fenêtre extensive ?
- ruptures multiples ou mémoire longue face à la persistance à la frontière, et la dépendance résiduelle dans |z| ;
- la direction, avec des contrôles propres au BTC ;
- pourquoi le classement des jours risqués n'est pas meilleur que celui d'un EWMA simple ;
- un recoupement des prix avec un second fournisseur, et des horizons de plus d'un jour par simulation multi-pas.

## 11. Livrables

- **Papier** : Zewu (2026), « Predicting a Bitcoin Price Range: An Out-of-Sample Test » (anglais, LaTeX).
- **Dépôt** : https://github.com/Armando-ZEWU/BTC-Volatility-Regime-Model — `README.md` (reproduction, ordre des scripts, environnement logiciel), `code/`, `data/`, `docs/`, `graphs/`.
- **Traçabilité** : l'annexe B du papier relie chaque bloc de résultats à ses fichiers de sortie et à son script.
