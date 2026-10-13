# Summary BTC Option 2 — Test de généralisation du pipeline EUR/USD sur le Bitcoin

*Document de travail — v2 (2026-09-30). Cadrage consolidé : remplace `methodology_btc_option2.md`. **Seule l'étape 1 (données) est exécutée** ; aucun résultat de modèle à ce stade. Les critères de succès ont été fixés avant toute estimation de modèle.*

---

## 0. Conventions du projet

- **Destination** : dépôt GitHub, projet de portfolio étudiant. Ce document est le **résumé cumulatif** : il sera mis à jour à chaque étape jusqu'à la conclusion finale.
- **Un document par étape**, comme sur le projet EUR/USD (voir `Methodology.md`), rangés dans `docs/`. Ce Summary les résume et renvoie vers eux.
- **Arborescence** (noms réels) : `BITCOIN/OPTION 2/` contenant `code/` (scripts), `data/raw/` (téléchargements bruts), `data/processus/` (séries et résultats dérivés), `docs/` (documents .md), `graphs/MS_GARCH_PLOT/` (figures ggplot2 de l'étape 3). Les documents citent ces noms réels ; `src/` et `processed/` seraient les conventions usuelles, à renommer avant publication si souhaité.
- **Les erreurs et corrections sont documentées, pas effacées** (voir section 6) : c'est la rigueur du projet EUR/USD, reprise ici.
- **Statut des décisions** : `[Validé]` = accepté explicitement ; `[À confirmer]` = proposé et retenu par défaut, en attente de confirmation ; `[Ouvert]` = à trancher (section 7) ; `[Hérité]` = repris de l'EUR/USD.

## 1. Objectif

L'objet d'étude n'est pas « le Bitcoin en soi » mais **le pipeline lui-même** : le raisonnement établi sur l'EUR/USD (log-rendements, GARCH Student's t, MS-GARCH Haas et al., fourchette via `Risk()`, backtest en fenêtre extensive) produit-il un résultat **cohérent et statistiquement calibré** quand on l'applique tel quel à un actif très différent ?

C'est un test de robustesse du projet, pas une nouvelle recherche exploratoire sur le Bitcoin (celle-ci relève de l'Option 1, exécutée après). Un résultat différent de l'EUR/USD n'est ni un échec ni un succès : les critères de succès (4.1, 4.3) sont propres au BTC, et les comparaisons avec l'EUR/USD ne servent que de contexte.

**Limite assumée du design** : on suppose K=2 (choix tranché sur l'EUR/USD, pas sur le Bitcoin) tout en testant la généralisation. Si K=2 fonctionne, on ne saura pas totalement si c'est le pipeline qui généralise ou le K forcé. Cette limite est compensée par le test « régime vs ère » (section 4.3).

## 2. Ce qui est transposé, et ce qui ne l'est pas

**Repris tel quel `[Hérité]`** :
- Rendements log (justification théorique de non-stationnarité générale).
- GARCH(1,1), comparaison Normal vs Student's t par AIC/BIC, sans nouvelle exploration de distributions.
- MS-GARCH via `MSGARCH` (R), spécification Haas et al. (2004a), **K=2 par défaut de départ** ; ajustement seulement si échec net (non-convergence, régimes non séparés).
- Fourchette de prix via `Risk()`, mélange pondéré par les probabilités de régime.
- Design du backtest : fenêtre extensive (West, 1996), paramètres gelés entre deux ré-estimations (ré-estimation annuelle comme sur l'EUR/USD), vérifications de convergence automatiques, seuils d'alerte déjà calibrés (persistance > 0,999 ; SE(ν) > ν).

**Volontairement non refait** : régression sur la direction, régression sur la magnitude comme étape à part, HMM séparé de détection de régime. Ces résultats sont traités comme des propriétés générales de marché ; s'ils sont faux sur le Bitcoin, cela doit apparaître en aval (diagnostics GARCH, backtest).

**Exception introduite** : le test de stabilité par sous-périodes, exclu du cadrage initial, est **réintégré sous forme ciblée** (section 4.3), car le risque « ère vs régime » le justifie.

## 3. Itinéraire

Un document par étape (noms prévus, `docs/`) :

| # | Étape | Document prévu |
|---|---|---|
| 1 | Données `BTC-USD` (yfinance), contrôle qualité, rendements log | `btc2_01_data.md` |
| 2 | GARCH(1,1) Normal vs Student's t, meilleur par AIC/BIC | `btc2_02_garch.md` |
| 3 | MS-GARCH K=2 (Haas et al.), diagnostics de convergence | `btc2_03_msgarch.md` |
| 4 | Diagnostic « régime vs ère » (sous-périodes ciblées) | `btc2_04_regime_vs_era.md` |
| 5 | Fourchette de prix opérationnelle (`Risk()`) | `btc2_05_price_range.md` |
| 6 | Test de robustesse sur un choc (qualitatif) | `btc2_06_shock_test.md` |
| 7 | Backtest complet en fenêtre extensive + tests de couverture | `btc2_07_backtest.md` |
| 8 | Verdict vs critère de succès, conclusion | (section 9 de ce Summary) |

## 4. Critère de succès (révisé)

### 4.1 Pass/fail — couverture et indépendance `[Validé]`

Fourchette nominale à **95 %**, prévisions à 1 jour, fenêtre extensive, paramètres gelés.

| Test | Règle | Seuil |
|---|---|---|
| Nombre de prévisions hors-échantillon | n ≥ 2500 | condition préalable |
| Couverture inconditionnelle | Kupiec (POF), **bilatéral** | non rejeté à 5 % |
| Indépendance des dépassements | Christoffersen | non rejeté à 5 % |
| Comparabilité avec l'EUR/USD | binomial **unilatéral** (sous-couverture), comme dans `full_backtest.md` | rapporté, non décisif |

Repère : sur l'EUR/USD, couverture 95,50 % (3270/3424), p = 0,919. À n ≈ 3000, l'écart-type de la couverture est d'environ 0,4 point : le Kupiec à 5 % rejette hors de ~94,3 %–95,7 %. Une zone « ni succès ni échec » n'existe donc pas : **toute couverture rejetée par le test est un échec**.

**Coût assumé** : deux tests à 5 % donnent environ 10 % de risque de faux rejet sur un modèle parfaitement calibré. Ce risque est documenté, pas corrigé (la puissance vient de n, pas du seuil).

### 4.2 Diagnostics à drapeaux (pas de pass/fail)

- Persistance > 0,999 ; SE(ν) > ν ; ν par régime.
- Couverture par fold / par année.
- **Couverture à 99 %** rapportée à côté du 95 % `[Validé]` (rapportée, sans pass/fail) : si ν est mal estimé (probable sur BTC), le 95 % peut passer alors que les queues sont fausses.

### 4.3 Interprétabilité : « régime » ou « ère » ? `[Validé — gelé le 2026-09-30]`

Risque identifié : la volatilité du BTC a baissé de façon séculaire (2014-2017 très différent d'aujourd'hui) et le marché a connu des ruptures structurelles. Un MS-GARCH K=2 peut alors séparer « vieille époque » et « époque récente » : convergence propre, diagnostics corrects, mais **aucun régime de peur**.

**Règle** (probabilités **lissées** de l'estimation sur l'échantillon complet, seuil 0,5, car on cherche la structure) : le résultat est classé **« ère »** si :
- il n'y a **qu'une seule bascule** de régime sur tout l'échantillon (bascule à sens unique), **ou**
- le régime volatil forme **un unique bloc continu couvrant plus de 40 %** de l'échantillon.

Un unique épisode de crise (entrée puis sortie) **n'est pas** une ère : c'est un régime légitime rare et collant, comme le régime 2 de l'EUR/USD. Le seuil de 40 % est arbitraire ; il est fixé avant toute estimation de modèle et **gelé le 2026-09-30**.

**Transparence** : l'écart-type de r par année (étape 1) a été observé *avant* ce gel. Il montre 2017-2022 entre 3,4 % et 4,9 %, contre 2,2 % à 2,8 % depuis 2023 ; 2017-2022 pèse ≈ 50 % de l'échantillon, donc au-dessus du seuil si un MS-GARCH K=2 sépare ces deux périodes. Le seuil n'a pas été ajusté en conséquence.

Dans le backtest, on utilise les probabilités **filtrées** (seules disponibles en temps réel).

**Vérification complémentaire `[Validé]`** : estimer le GARCH(1,1) Student's t séparément avant et après la **coupure du 2020-09-22** (médiane des 4 395 prix : 2 197 prix avant, 2 198 après, soit 2 196 et 2 198 rendements ; 2014-09-18 → 2020-09-21 et 2020-09-22 → 2026-09-28; aucun degré de liberté). Comparaison par un **test du rapport de vraisemblance de type Chow** sur les 5 paramètres (μ, ω, α, β, ν), χ²(5) à 5 %, avec σ de long terme, persistance et ν rapportés pour chaque moitié. Cette vérification est **corroborante, non décisive** : la médiane coupe à travers des années calmes et agitées (puissance faible face à une rupture vers 2022-2023) et le test peut sur-rejeter quand la persistance est proche de 1 et ν bas. Elle ne peut pas modifier le verdict de la règle ci-dessus. Complément gratuit : trajectoire des paramètres fold par fold dans le backtest.

**Conséquence** : un verdict « ère » = **échec sur l'interprétabilité**, même si la couverture passe.

### 4.4 Règle de décision finale

L'Option 2 est **réussie** si : 4.1 passé (Kupiec et Christoffersen non rejetés, n ≥ 2500) **et** 4.3 non classé « ère ». Sinon : documenter pourquoi avant de basculer vers l'Option 1 (procédure du cadrage initial).

### 4.5 Test de choc `[Validé]`

- Choc proposé : **mars 2020**, seul choc directement comparable au test COVID de l'EUR/USD (estimation sur données strictement antérieures, paramètres gelés).
- **Statut : qualitatif, hors critère de succès.** Sur l'EUR/USD, 84 jours ont donné p = 0,127 (ni validation ni invalidation) : ce type de fenêtre n'a pas la puissance d'un test décisif.
- Fenêtre : 2020-01-01 → 2020-04-30 (121 jours, marché 7j/7 ; EUR/USD : 84 jours de bourse sur la même période), modèle ré-estimé sur les données jusqu'au 2019-12-31 (1 931 rendements) puis gelé, comme sur l'EUR/USD `[Retenu par défaut, non contesté]`.

### 4.6 Lecture de l'étape 2 (GARCH) `[Appliqué tel quel, non contesté]`

Fixée avant toute estimation GARCH sur les données BTC. Aucun pass/fail supplémentaire : l'étape 2 alimente les drapeaux de 4.2.

- **Spécification retenue** : BIC minimal (AIC rapporté ; en cas de désaccord, les deux sont documentés et le BIC tranche).
- **Convergence** de l'optimiseur exigée ; sinon l'étape est refaite avant toute interprétation.
- **Résidus** : Ljung-Box sur z² (lags 10 et 20) et ARCH-LM standardisé (10 lags). Un rejet à 5 % est **documenté comme limite** (GARCH(1,1) insuffisant), sans exploration d'autres spécifications (hors périmètre de l'Option 2).
- **Si ν̂ ≤ 4** : la kurtosis théorique 6/(ν − 4) est infinie ; la comparaison avec la kurtosis empirique n'est pas faite et on le documente.

### 4.7 Prédiction à falsifier (étape 4) `[Retenu par défaut, non contesté]`

Issue de l'hypothèse de `btc2_02_garch.md` (section 8) : si un changement de niveau de volatilité gonfle la persistance et les queues d'un GARCH à un seul régime, les estimations séparées avant/après la coupure du 2020-09-22 doivent donner, **dans les deux moitiés**, une persistance α + β **< 0,99** et un ν̂ **> 3,18** (valeur du plein échantillon, étape 2). Seuils fixés avant exécution.

- Verdict « soutenue » seulement si les quatre conditions sont réunies ; sinon « non soutenue », avec la moitié et le critère en cause.
- Statut identique au test LR : corroborant, non décisif. Le MS-GARCH (étape 3) n'a pas isolé de bascule unique ; ce test ne peut pas inverser le verdict de 4.3.
- Contexte : c'est une explication possible parmi d'autres du constat de l'étape 2 (persistance proche de 1, ν ≈ 3). Pour un actif sans ancrage institutionnel, ces propriétés peuvent être réelles ; « non soutenue » ne serait pas un échec. **Résultat : non soutenue** (persistance 1,0000 dans les deux moitiés ; voir `btc2_04_regime_vs_era.md`).

## 5. Décisions pratiques

- **Source** `[Hérité du cadrage]` : `yfinance`, ticker `BTC-USD` ; si échec, bascule immédiate vers CoinGecko sans diagnostic approfondi.
- **Clôture** : minuit UTC.
- **Bougie du jour exclue** : la dernière observation (jour en cours, incomplète avant minuit UTC) est retirée systématiquement.
- **Historique** : ce que la source renvoie de façon fiable ; la date de début effective sera constatée, pas supposée.
- **Cotation 7j/7** : pas de gap de week-end ; annualisation sur 365 jours si utilisée (pas 252).
- **Contrôle qualité (étape 1)** : zéro jour manquant attendu (sinon source douteuse), examen du top |r|, Ljung-Box sur r² (un GARCH n'a rien à modéliser s'il n'est pas significatif), écart-type par année (découpe mécanique).
- **Étape 3 (MS-GARCH)** : rendements ×100, moyenne nulle (MSGARCH n'estime pas de moyenne, comme sur l'EUR/USD), benchmark K=1 estimé dans MSGARCH, ajustement final = meilleur optimum parmi 21 ajustements (défaut, départs perturbés, départs « régimes persistants »). Leçon : ni le point de départ par défaut ni son voisinage n'ont trouvé l'optimum global (voir `btc2_03_msgarch.md`).

## 6. Corrections apportées au cadrage initial

| # | Problème repéré | Correction |
|---|---|---|
| C1 | **Raisonnement circulaire** : K=2 supposé (tranché sur l'EUR/USD) tout en testant la généralisation | Limite assumée (section 1) + test « régime vs ère » (4.3) |
| C2 | **Critère de succès trop mou** : « pas 60 % » laissait une zone grise de 60 % à 94 %, tranchée après coup ; plus laxiste que le test EUR/USD | Seuils chiffrés (4.1), aucune zone grise |
| C3 | **Binomial EUR/USD unilatéral** : ne détecte pas une fourchette trop large | Kupiec bilatéral ajouté |
| C4 | **Dépassements groupés** non testés formellement | Christoffersen ajouté |
| C5 | **Règle « ≤ 2 bascules = ère » fausse** : un épisode de crise unique fait 2 bascules et reste un régime légitime | Règle remplacée : bascule unique ou bloc unique > 40 % (4.3) |
| C6 | **Lissées vs filtrées** non distinguées | Lissées pour le diagnostic de structure, filtrées pour le backtest |
| C7 | **Test de choc présenté comme critère** alors que sa puissance est faible | Statut qualitatif, hors critère (4.5) |
| C8 | **Test de stabilité par sous-périodes exclu** du cadrage initial | Réintégré de façon ciblée, avec justification (section 2) |
| C9 | **« Paramètres radicalement différents »** (vérification avant/après) : critère flou, même défaut que le « pas 60 % » | Test LR de type Chow, χ²(5) à 5 %, statut corroborant et non décisif (4.3) |
| C10 | **Redémarrages mal conçus (script v2)** : probabilités de transition écrêtées à [0,6 ; 0,995], donc seulement des départs de micro-régimes ; un optimum local a été pris pour global | Départs « régimes persistants » et bruit en logit (v3) : l'optimum global (−10 708,78) change la lecture (régimes de 36 et 73 jours au lieu de 2 et 6) |
| C11 | **Colonne `Pr(>|t|)` de MSGARCH unilatérale** lue comme bilatérale (y compris dans le document EUR/USD) | p bilatéral = 2 × la valeur affichée |
| C12 | **Effectifs des moitiés mal comptés** : « 2 197 rendements de chaque côté », alors que la coupure est la médiane des 4 395 prix (2 197 et 2 198 prix), donc 2 196 et 2 198 rendements | Texte corrigé ; le script de l'étape 4 affiche les effectifs réels |
| C13 | **Le critère 4.1 ne discrimine pas** entre le MS-GARCH et un modèle simple : EWMA + simulation historique filtrée le passe aussi (Kupiec p = 0,452 ; Christoffersen p = 0,177), à largeur de bande quasi identique | Références simples ajoutées en vérification exploratoire (`btc2_08_verification.md`) ; la conclusion le dit |

## 7. Décisions ouvertes

- **O1 `[Validé]`** : coupure au **2020-09-22** (médiane par nombre d'observations, choisie sans regarder les données pour éviter une coupure qui raconte une jolie histoire ; 2023 et les dates « narratives » écartées). Voir 4.3.
- **O2 `[Validé]`** : fenêtre initiale d'estimation du 2014-09-17 au 2017-12-31 (≈ 1 200 jours), premier test le 2018-01-01, soit ≈ 3 190 prévisions et 9 ré-estimations annuelles (2018-2026, la dernière partielle). Compromis assumé : la bulle de 2017 est dans l'estimation, pas dans le test, et le premier fold repose sur peu d'historique.
- **O3 `[Validé]`** : diagnostic de couverture à 99 % (rapporté, sans pass/fail) et mars 2020 comme choc qualitatif. (La règle 4.3 est validée et gelée.)
- **O4 `[Validé]`** : traitement de la moyenne dans la fourchette (étape 5). μ̂ est significatif sur BTC (≈ 0,11 %/jour sur l'échantillon complet, ≈ 0,29 %/jour sur la fenêtre initiale 2014-2017), contrairement à l'EUR/USD. Choix : μ estimé ou μ = 0. **MSGARCH n'estime pas de moyenne** (comme sur l'EUR/USD) : l'étape 3 est donc à μ = 0 par construction ; validé : on ne change rien (μ = 0 par construction, comme sur l'EUR/USD ; les résultats BTC se comparent à l'EUR/USD avec des nuances si nécessaire). Décalage d'environ 0,075 σ par jour sur la fenêtre initiale : effet négligeable sur la couverture à 1 jour, mais décision de principe à figer avant l'étape 5.

## 8. Suivi d'avancement

- [x] Cadrage initial (`methodology_btc_option2.md`)
- [x] Révision du critère de succès (2026-09-29)
- [x] Consolidation de ce Summary (v1)
- [x] Étape 1 — données et contrôle qualité (voir `btc2_01_data.md`) *(fichiers de sortie produits)*
- [x] Étape 2 — GARCH(1,1) (voir `btc2_02_garch.md`)
- [x] Étape 3 — MS-GARCH K=2 (voir `btc2_03_msgarch.md`)
- [x] Étape 4 — diagnostic régime vs ère (voir `btc2_04_regime_vs_era.md`) : règle 4.3 PAS_ERE ; test LR p = 0,0013 (corroborant) ; prédiction 4.7 non soutenue
- [x] Étape 5 — fourchette de prix (voir `btc2_05_price_range.md`)
- [x] Étape 6 — test de choc (qualitatif) (voir `btc2_06_shock_test.md`)
- [x] Étape 7 — backtest et tests de couverture (voir `btc2_07_backtest.md`) : verdict 4.1 PASS
- [x] Étape 8 — verdict vs critère de succès (voir section 10, v1 à relire) : Option 2 réussie au sens de 4.4

## 9. Journal

- **2026-09-29** — Cadrage initial relu de façon critique ; huit corrections (section 6) ; critère de succès chiffré ; règle « régime vs ère » définie ; consolidation dans ce Summary.
- **Étape 1** — Données `BTC-USD` chargées : 4 395 observations du 2014-09-17 au 2026-09-28, aucun jour manquant, aucun prix ≤ 0, 1 rendement nul (2017-02-28, sans conséquence) ; prix non stationnaire, rendements stationnaires ; effets ARCH très significatifs. Détail dans `btc2_01_data.md`.
- **2026-09-30** — Validation de O2 (estimation jusqu'en 2017, test à partir de 2018) et gel de la règle 4.3 (« ère » = bascule unique ou bloc volatil > 40 %), avec mention explicite que l'écart-type par année avait été vu avant le gel.
- **2026-09-30** — Rendement nul identifié (2017-02-28, sans conséquence). Validation de O1 (coupure 2020-09-22) et remplacement du critère flou « radicalement » par un test LR de type Chow, non décisif (correction C9).
- **Étape 2** — GARCH(1,1) sur 4 394 rendements. Student's t retenu (ΔAIC ≈ 1 082, ΔBIC ≈ 1 076 face à la Normal). ν̂ = 3,18 (SE 0,12) ; α + β = 1,0000 (frontière IGARCH : demi-vie et σ de long terme non définis) ; drapeaux « persistance > 0,999 » et « ν ≤ 4 » déclenchés ; pas d'ARCH résiduel sur z² (Ljung-Box et ARCH-LM, p > 0,9, tests peu puissants car moment d'ordre 4 infini) mais **dépendance résiduelle détectée sur |z|** (p ≈ 0,015 au lag 10 et ≈ 0,008 au lag 20, test ajouté après coup pour raison théorique). Détail dans `btc2_02_garch.md`.
- **Étape 3, première exécution** — MS-GARCH K=2 en R. Les 5 redémarrages montrent que l'optimum par défaut **n'est pas l'optimum** (+3,09 de log-vraisemblance ; au moins 4 optima distincts) : résultats **provisoires**, étape à relancer (v2 du script : le meilleur de 16 points de départ devient l'ajustement final). Structure observée sur l'optimum local : régime « volatil » de ≈ 2 jours (durée espérée 1,9 j, β ≈ 0) et régime dominant à ν ≈ 3,07, persistance ≈ 0,9999 ; durée du régime dominant ≈ 8 jours (contre 404 et 160 jours sur l'EUR/USD). Règle 4.3 : 268 bascules, 134 blocs volatils, plus long bloc 8 jours (0,2 % de l'échantillon) → pas d'ère, mais pas non plus de régime persistant. K=2 devant K=1 sur AIC et BIC (contrairement à l'EUR/USD).
- **Étape 3, deuxième exécution (v2 du script)** — Meilleur optimum : LL = −10 713,36, retrouvé 4 fois sur 15 départs (le défaut était à −10 716,45). K=2 vs K=1 : ΔAIC ≈ −72, ΔBIC ≈ −34. Régime calme (72 % du temps) : persistance 0,9999, ν = 2,80 (SE 0,14), durée espérée 5,8 jours ; régime volatil (28 %) : ω = 2,25, persistance 0,963, ν = 8,05 (SE 3,2), durée espérée 2,2 jours. 90,7 % des jours ont une probabilité de régime lissée maximale < 0,9. Règle 4.3 : PAS_ERE sur tous les optima à moins de 3 LL du meilleur. **Défaut de conception du script** : les redémarrages écrêtaient les probabilités de transition à [0,6 ; 0,995] et ne partaient donc que de micro-régimes ; l'absence de régimes persistants parmi ces optima n'était pas concluante. Corrigé en v3 (départs « régimes persistants » ajoutés, bruit en logit).
- **Étape 3, troisième exécution (v3)** — Meilleur optimum : LL = −10 708,78, retrouvé 10 fois sur 12 départs « persistants » (0 sur 8 départs perturbés). Régimes persistants : volatil (≈ 69 % des jours, écart-type réalisé 3,81 %/jour, durée espérée 72,8 j, ν = 3,95) et calme (2,61 %/jour, 35,9 j, ν = 2,30, persistance 0,99900). K=2 vs K=1 : ΔAIC ≈ −81, ΔBIC ≈ −43. Règle 4.3 : **PAS_ERE** (stricte et tolérante, et sur les 10 optima proches) : 51 bascules, 26 blocs volatils, plus long bloc 676 jours (15,4 %). Drapeaux : ν ≤ 4 dans les deux régimes, persistance du régime calme à la limite de 0,999 ; 42,6 % de jours ambigus. Détail dans `btc2_03_msgarch.md`.
- **Étape 3, examen des 8 figures** — Le choc de mars 2020 (−46 %) est attribué au régime « calme » (ν = 2,30) : la probabilité du régime volatil baisse le jour du choc. L'étiquette « volatil » ne suit pas le niveau de volatilité réalisé par année (ex. 2016 : σ ≈ 2,5 % et ≈ 18 % de jours volatils ; 2023 : σ ≈ 2,3 % et ≈ 58 %). Script de graphiques corrigé en v2 (statistique trompeuse de la figure 02, barres de la figure 04, axes, figure 09 ajoutée).
- **Étape 4, préparation** — Script `chow_garch_btc.py` prêt et testé sur série synthétique (pas encore exécuté sur les données BTC) ; seuils de la prédiction fixés en 4.7 ; effectifs des moitiés corrigés (C12).
- **Étape 4, résultats** — GARCH-t estimé sur 2 196 (avant) et 2 198 (après) rendements. Test LR de type Chow : LR = 19,91, χ²(5), p = 0,0013 (rejet à 5 %, avec réserve de sur-rejet près de la frontière). Persistance α + β = 1,0000 dans les deux moitiés ; ν = 3,16 (SE 0,15) et 3,28 (SE 0,22). Après 2020 : α ≈ deux fois plus faible (0,128 → 0,062), β plus élevé (0,872 → 0,938), ω et μ plus faibles. Prédiction 4.7 **non soutenue** (échec sur la persistance dans les deux moitiés ; le critère sur ν est dans le bruit). Règle 4.3 inchangée : PAS_ERE. Détail dans `btc2_04_regime_vs_era.md`.
- **Étape 5, préparation** — O3 et O4 validés. Documents EUR/USD relus (`Price_Range.md`, `Full_Backtest.md`, `Covid_Robustness_Test.md`, `price_range.py`). Scripts prêts : `ms_garch_forecast_btc.R` (fourchette à 1 jour, niveaux 20/50/80/95 + 99 % en diagnostic, recursion par régime validée contre `predict()`, quantiles exacts du mélange comparés à `Risk()`), `price_range_btc.py`, `graphs_price_range_btc.R`. Pas encore exécutés sur les données BTC ; les scripts R de l'EUR/USD (`ms_garch_forecast.R` etc.) n'ayant pas été fournis, la logique est reconstruite à partir des documents.
- **Étape 5, résultats** — Prévision pour le 2026-09-29 (dernier prix 83 502,61 $) : P(volatil) = 14,8 % ; volatilité prévue 2,694 %/jour (≈ 51 % annualisée) ; **fourchette à 95 % = [80 139 $ ; 86 997 $]** (largeur 8,21 %) ; diagnostic à 99 % : [76 974 $ ; 90 574 $] (16,29 %, soit 1,98 × la bande à 95 % contre 1,31 pour une Normale). Récursion de variance validée : écart nul avec `predict()$vol` (l'initialisation est sans effet, β^T ≈ 0). À cette date les σ conditionnels des deux régimes sont presque égaux (2,834 contre 2,669 %/jour) : les largeurs par régime diffèrent surtout par les queues (ν = 3,95 contre 2,30). Bande à 95 % de 1,53 σ, plus étroite que la Normale (1,96 σ). `Risk()` contre quantiles exacts : écart ≤ 0,5 % aux niveaux 95 % et 99 % (sans incidence), jusqu'à −9 % à 50 %. Détail dans `btc2_05_price_range.md`.
- **Étape 6, préparation** — Scripts `msgarch_utils_btc.R` (ajustement multi-départs, prévision à 1 jour, tests de Kupiec et Christoffersen validés contre une implémentation de référence) et `covid_shock_test_btc.R` (modèle ré-estimé jusqu'au 2019-12-31 puis gelé ; 121 jours du 2020-01-01 au 2020-04-30 ; couverture à 95 % et 99 %, binomial unilatéral, Kupiec, Christoffersen si calculable, diagnostic intrajournalier High/Low de la même source). Logique testée avec des doublures de MSGARCH sur données synthétiques ; les appels MSGARCH n'ont pas pu être testés ici.
- **Étape 6, première exécution** — Modèle pré-2020 (1 931 rendements) : les 19 ajustements convergent vers le même optimum (LL −4 814,95) ; régime calme ν = 2,37 (SE 0,08), persistance 0,9996 ; régime volatil ν = 5,09 (SE 1,01), persistance 0,965 ; structure analogue à celle de l'échantillon complet. 120 prévisions sur 121 : **2020-03-14 sans prévision** (échec de `Risk()` ; la v1 du script n'en consignait pas la cause). Sur les 120 jours : couverture à 95 % = 95,83 % (5 dépassements pour 6,0 attendus ; binomial unilatéral p = 0,72 ; Kupiec p = 0,67 ; Christoffersen p = 0,51) ; à 99 % = 99,17 % (1 dépassement pour 1,2 attendu). Dépassements à 95 % : 2020-01-03, 01-14, 03-08, 03-12 (−46,5 % pour une borne de −7,1 %), 04-29, avec P(volatil) de 23 % à 77 % au moment de la prévision (50 % le 12 mars). Intrajournalier (même source) : 7 jours sur 120 touchent hors de la bande (les 5 clôtures + 2). Le jour manquant est un jour de crise : l'exclure peut biaiser la couverture à la hausse (avec 6 ou 7 dépassements sur 121 le binomial unilatéral resterait à p = 0,57 ou 0,40). Script corrigé en v2 : repli sur le mélange exact avec la raison consignée ; relance requise pour compléter.
- **Étape 7, préparation** — Script `full_backtest_btc.R` prêt : 9 folds (2018-2026), ≈ 3 193 prévisions, paramètres gelés par année, ré-estimation multi-départs avec départ chaud, repli exact si `Risk()` échoue, sauvegarde incrémentale par fold avec reprise, critère 4.1 appliqué mécaniquement (n ≥ 2500, Kupiec et Christoffersen à 5 %), couverture à 99 % rapportée sans pass/fail. Logique testée avec des doublures de MSGARCH (les chiffres de ce test n'ont aucune signification) ; appels MSGARCH non testés ici.
- **Étape 6, résultats finaux (v2)** — Les 121 jours sont couverts : le 2020-03-14, `Risk()` renvoyait des quantiles incohérents (−37,74 ; −24,03 ; +26,48 ; +26,48, saturation de la grille) ; repli exact, bornes ±25,3 %, rendement −6,75 % dans la bande. Couverture à 95 % = 95,87 % (5 dépassements pour 6,05 ; binomial unilatéral p = 0,729 ; Kupiec p = 0,652 ; Christoffersen p = 0,510) ; à 99 % = 99,17 % (1 dépassement ; Kupiec p = 0,843). Intrajournalier : 7 jours sur 121 hors bande (EUR/USD : 19 sur 84). Détail dans `btc2_06_shock_test.md`.
- **Étape 7, résultats** — 3 193 prévisions sur 9 folds (2018-2026), 0 échec, 1 repli exact. **Couverture à 95 % = 95,11 %** (156 dépassements pour 159,7 ; IC à 95 % de la couverture : 94,3 % à 95,8 %) : **Kupiec p = 0,766, Christoffersen p = 0,610**, binomial unilatéral p = 0,628 ; **verdict 4.1 : PASS**. À 99 % (sans pass/fail) : 99,15 %, 27 dépassements pour 31,9, Kupiec p = 0,368. Dépassements 72 bas / 84 haut (symétrie : p = 0,38). Persistance du régime calme > 0,999 dans les 9 folds, ν du régime calme stable (2,32 à 2,38), ν du régime volatil de 5,3 à 4,0. Variation par année non distinguable du bruit (homogénéité : p = 0,69 à 95 % ; p = 0,11 à 99 %) ; 0 dépassement à 99 % en 2024-2025 observé après coup. Détail dans `btc2_07_backtest.md`.
- **Étape 8** — Critère 4.4 : 4.1 passé et 4.3 non classé « ère » (PAS_ERE) : **Option 2 réussie** ; conclusion rédigée en section 10 (v1, à relire).
- **Compléments, préparation (après l'étape 8)** — À la demande de l'utilisateur : `graphs_backtest_btc.R` (figures 11 à 16 : bougies de mars 2020, rendements contre bande, couverture par année avec intervalles de Wilson, dépassements cumulés moins attendus, largeur de bande et probabilité de régime, paramètres par fold) ; `graphs_distribution_btc.R` (D1 à D7 : densité log, QQ-plots, probabilité de dépasser x, Hill, distribution par régime et par année, taille des dépassements) ; `verification_btc.R` (A : benchmarks simples EWMA, EWMA + simulation historique filtrée, simulation historique 365 jours, GARCH-t à un régime, avec score d'intervalle ; B : calibration conditionnelle par tercile de largeur et régression de |rendement| sur la demi-largeur ; C : taille des dépassements ; D : direction, 3 tests déclarés). Testés sur données synthétiques (les chiffres de ces tests n'ont aucune signification). Document `Economics.md` proposé : interprétations économiques seules.
- **Compléments, vérifications (`verification_btc.R`)** — Détail dans `btc2_08_verification.md`. (A) Sur les mêmes 3 193 jours, le MS-GARCH a le meilleur score d'intervalle (IS 18,54 à 95 % ; 29,13 à 99 %), mais de **peu** à 95 % : 1,6 % face au GARCH-t à un régime et à l'EWMA Normale, 2,3 % face à EWMA + FHS, 4,2 % face à la simulation historique ; seul l'écart avec EWMA + FHS survit à la correction de Bonferroni (p = 0,008). GARCH-t K=1 (93,3 %) et EWMA Normale (93,5 %) sous-couvrent à 95 % (Kupiec p = 0,000) ; EWMA + FHS (94,7 %) passe Kupiec et Christoffersen ; la simulation historique échoue l'indépendance (p = 0,003). (B) Couverture par tercile de largeur : le MS-GARCH est le plus uniforme (94,4 / 94,6 / 96,3 %) ; la régression de |rendement| sur la demi-largeur donne R² = 0,085 contre 0,088 pour l'EWMA : le classement des jours risqués n'est pas meilleur. (C) Dépassements à 95 % : médiane 1,45 point, 17 sur 156 au-delà d'une demi-largeur, maximum 5,6 demi-largeurs (12 mars 2020). (D) Direction : persistance du signe à 1 jour de 48,1 % (p = 0,011, sous le seuil de Bonferroni 0,0167 mais écart de 1,9 point) ; tendance sur 20 jours : 50,6 % (p = 0,50) ; Ljung-Box sur les rendements p = 0,029 (lag 10) ; témoin |rendements| : regroupement massif.

## 10. Conclusion finale

**Verdict (v1, à relire).** Critère 4.4 : **Option 2 réussie**. Le critère 4.1 est passé (n = 3 193 ≥ 2 500 ; Kupiec p = 0,766 ; Christoffersen p = 0,610) et la règle 4.3 ne classe pas le résultat en « ère » (PAS_ERE, règle gelée appliquée à l'optimum global, inchangée sur les optima proches et si l'on inverse les étiquettes). Conformément au cadrage initial, l'Option 2 est close ; l'approfondissement revient à l'Option 1. Des vérifications complémentaires exploratoires sont consignées dans `btc2_08_verification.md` ; l'analyse de la distribution (`graphs_distribution_btc.R`) et un document `Economics.md` (interprétations économiques seules) restent à produire avant la clôture définitive ; elles ne remettent pas en jeu le critère 4.1.

**Ce que le résultat montre.** Appliqué au BTC avec trois adaptations déclarées (ajustement multi-départs, repli exact quand `Risk()` sature, lecture prudente des étiquettes de régime), le pipeline construit sur l'EUR/USD produit des fourchettes à 95 % à 1 jour calibrées hors échantillon : couverture de 95,11 % (intervalle à 95 % : 94,3 % à 95,8 %), dépassements indépendants, sans effondrement lors du choc de mars 2020 (95,87 % sur 121 jours, test qualitatif).

**Ce qu'il ne montre pas.**
- L'**ampleur** des dépassements et les queues au-delà de 99 % : le 12 mars 2020 (−46,5 % pour une borne à −7,1 %) compte pour un seul dépassement ; le 99 % est rapporté sans pass/fail (99,15 %, 27 dépassements pour 31,9, dont aucun en 2024-2025, observation faite après coup).
- Une calibration plus fine que ± 0,76 point, et le risque de faux rejet d'environ 10 % lié aux deux tests à 5 %.
- L'utilité des **probabilités de régime** : les étiquettes « volatil » et « calme » ne désignent pas « crise » et « non-crise » (le choc de mars 2020 est attribué au régime à queues très lourdes), et 43 % des jours restent ambigus à l'optimum final.
- Une lecture structurelle solide : ν ≤ 4 dans les deux régimes, persistance du régime calme à la frontière dans les 9 folds ; l'hypothèse « ère » n'est pas soutenue (étape 4), mais ce test est corroborant, non décisif.
- Plus d'un actif, d'un découpage en folds ou d'une exécution : aucune spécification n'a été ajustée après avoir vu les résultats du backtest.
- Que le MS-GARCH soit **nécessaire** : le critère 4.1 est aussi passé par EWMA + simulation historique filtrée. Le MS-GARCH reste le meilleur au score d'intervalle (de 1,6 % à 4,2 % à 95 %, solide statistiquement face à EWMA + FHS seulement) ; son apport est la calibration des queues et l'uniformité de la couverture, non le classement des jours risqués (btc2_08).

**Repères avec l'EUR/USD (contexte, pas un critère).** Durées espérées des régimes d'environ 73 et 36 jours (contre 160 et 404 jours de bourse) ; ν de 2,3 à 4 (contre 7 à 22) ; couverture de 95,11 % (contre 95,50 %).

**Corrections en route.** Douze corrections sont consignées en section 6. La plus lourde de conséquences : un optimum local du MS-GARCH pris pour l'optimum global (C10), qui aurait donné des régimes de 2 et 6 jours au lieu de 73 et 36.

**Pistes pour l'Option 1** (nées de l'Option 2, à tester et non à présumer) : pourquoi le MS-GARCH(K=2) sépare échelle et queues plutôt que calme et crise (tester K ≥ 3 ou d'autres définitions de régime) ; la sur-couverture à 99 % en 2024-2025 ; ruptures multiples ou mémoire longue face à la persistance à la frontière ; la dépendance résiduelle dans |z| (étape 2) ; la direction, avec des contrôles propres au BTC (trois signaux simples testés en vérification : rien d'exploitable) ; pourquoi le classement des jours risqués n'est pas meilleur que celui d'un EWMA simple.
