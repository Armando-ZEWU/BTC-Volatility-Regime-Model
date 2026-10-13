# Vérifications complémentaires : ce que le backtest ne montrait pas

*Option 2, après l'étape 8. Script : `code/verification_btc.R`. **Statut : exploratoire.** Ces vérifications n'étaient pas au cadrage ; elles ne remettent pas en jeu le verdict 4.1 (PASS). Toutes les comparaisons sont déclarées ci-dessous ; aucun seuil n'a été ajusté après coup.*

## 1. Questions et design

Le backtest (étape 7) teste la couverture **inconditionnelle** à 95 % et l'indépendance des dépassements. Il ne dit pas : (A) si le MS-GARCH fait mieux qu'un modèle simple, (B) si la largeur de la bande varie à bon escient d'un jour à l'autre, (C) de combien les dépassements dépassent, (D) ce qu'il en est de la direction.

Mêmes 3 193 jours, mêmes folds, information jusqu'à la veille uniquement. Références :

| Modèle | Définition |
|---|---|
| EWMA Normale | RiskMetrics, λ = 0,94, bande Normale |
| EWMA + FHS | même volatilité, quantiles empiriques des 730 derniers rendements standardisés |
| Simulation historique | quantiles empiriques des 365 derniers rendements |
| GARCH-t (K=1) | un seul régime, ré-estimé chaque 1er janvier (α + β = 0,9973 à 0,9981 et ν = 3,20 à 3,45 selon les folds) |

Score d'intervalle (IS, Gneiting et Raftery) : largeur + pénalité proportionnelle aux dépassements ; plus bas = mieux. Test de Diebold-Mariano sur l'IS à 95 % (correction Newey-West ; queues lourdes, donc t indicatif). Comparaisons déclarées : 4 pour (A) ; 15 couvertures par tercile pour (B1) ; 3 tests pour (D).

## 2. (A) MS-GARCH contre des modèles simples

| Modèle | Dép. 95 % | Couv. 95 % | Kupiec p | Christ. p | Largeur 95 % | IS 95 % | Dép. 99 % | Couv. 99 % | Kupiec p (99) | IS 99 % | DM t (p) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| **MS-GARCH (K=2)** | 156 | 95,11 % | 0,766 | 0,610 | 13,46 | **18,54** | 27 | 99,15 % | 0,368 | **29,13** | |
| GARCH-t (K=1) | 213 | 93,33 % | **0,000** | 0,299 | 12,32 | 18,84 | 42 | 98,68 % | 0,088 | 30,12 | 2,19 (0,029) |
| EWMA Normale | 207 | 93,52 % | **0,000** | **0,000** | 12,22 | 18,85 | 109 | 96,59 % | **0,000** | 33,92 | 1,62 (0,105) |
| EWMA + FHS | 169 | 94,71 % | 0,452 | 0,177 | 13,43 | 18,98 | 42 | 98,68 % | 0,088 | 31,57 | 2,66 (0,008) |
| Simulation historique | 159 | 95,02 % | 0,958 | **0,003** | 14,18 | 19,35 | 40 | 98,75 % | 0,167 | 29,50 | 2,35 (0,019) |

Attendus : 159,7 dépassements à 95 %, 31,9 à 99 %. DM : t > 0 = le modèle est pire que le MS-GARCH.

**Lecture**
- **Le MS-GARCH a le meilleur score à 95 % et à 99 %**, mais l'écart est **faible** à 95 % : 1,6 % face au GARCH-t et à l'EWMA Normale, 2,3 % face à EWMA + FHS, 4,2 % face à la simulation historique. À 99 %, de 1,3 % (simulation historique) à 14 % (EWMA Normale).
- **Solidité statistique** : avec 4 comparaisons (seuil de Bonferroni 0,0125), seul l'écart avec EWMA + FHS (p = 0,008) tient. Les p de 0,029 (K=1) et 0,019 (simulation historique) ne tiennent pas après correction.
- **Le critère 4.1 ne discrimine pas** : EWMA + FHS le passe aussi (Kupiec p = 0,452 ; Christoffersen p = 0,177), à largeur de bande quasi identique (13,43 contre 13,46). La simulation historique passe Kupiec mais échoue l'indépendance (p = 0,003) : ses dépassements se regroupent.
- **Ce que les références simples ratent** : le GARCH-t à un régime et l'EWMA Normale sous-couvrent à 95 % (93,3 % et 93,5 %, p = 0,000). L'EWMA Normale rate massivement les extrêmes à 99 % (109 dépassements pour 31,9 attendus). Les queues lourdes comptent : la Normale n'est pas défendable ici.
- **L'apport propre du MS-GARCH**, à l'issue de (A) : meilleure calibration que le GARCH-t à un régime (95,1 % contre 93,3 %), et à 99 % une couverture non rejetée (Kupiec p = 0,368) là où EWMA + FHS et K=1 sont à p = 0,088.

## 3. (B1) Couverture à 95 % par tercile de largeur de bande

| Modèle | Étroit | Moyen | Large |
|---|---|---|---|
| **MS-GARCH (K=2)** | 94,37 % (p = 0,35) | 94,64 % (p = 0,60) | 96,33 % (p = 0,036) |
| GARCH-t (K=1) | 91,92 % (p = 0,000) | 92,48 % (p = 0,000) | 95,58 % (p = 0,37) |
| EWMA Normale | 90,70 % (p = 0,000) | 94,45 % (p = 0,42) | 95,39 % (p = 0,55) |
| EWMA + FHS | 92,39 % (p = 0,000) | 94,74 % (p = 0,70) | 96,99 % (p = 0,001) |
| Simulation historique | 94,19 % (p = 0,24) | 94,26 % (p = 0,28) | 96,65 % (p = 0,009) |

Tous les modèles ont le même profil : la couverture augmente avec la largeur (bandes étroites un peu trop serrées, bandes larges un peu trop prudentes). **Le MS-GARCH est le plus uniforme** : aucun rejet dans les deux premiers terciles, et le seul écart (96,33 %, 39 dépassements pour 53 attendus) est du côté prudent. Les p non corrigés sur 15 tests : à lire comme indicatifs.

## 4. (B2) La largeur suit-elle l'ampleur du mouvement du jour ?

Régression de |rendement| sur la demi-largeur de la bande à 95 % :

| Modèle | Pente | t (HAC) | R² |
|---|---|---|---|
| MS-GARCH (K=2) | 0,297 | 15,7 | 0,085 |
| GARCH-t (K=1) | 0,271 | 11,2 | 0,083 |
| EWMA Normale | 0,283 | 11,9 | 0,088 |
| EWMA + FHS | 0,257 | 12,5 | 0,084 |
| Simulation historique | 0,234 | 6,8 | 0,031 |

La largeur de la bande du MS-GARCH suit bien l'ampleur du mouvement du jour (t = 15,7 ; une bande à largeur constante aurait R² = 0). Mais **le classement des jours risqués n'est pas meilleur que celui d'un EWMA simple** (R² de 0,085 contre 0,088) ; seule la simulation historique, qui s'adapte lentement, décroche (0,031). Le R² absolu est faible parce que |rendement| est un indicateur très bruité de la volatilité du jour : seule la comparaison entre modèles est parlante.

**Conséquence** : l'apport du MS-GARCH n'est pas de mieux repérer les jours risqués ; il est dans la **forme** de la distribution (calibration des queues), pas dans le **classement**.

## 5. (C) Taille des dépassements du MS-GARCH

| Niveau | Dépassements | Moyenne | Médiane | 90ᵉ centile | Maximum | Moyenne / demi-largeur | Maximum / demi-largeur | Jours > 1 demi-largeur |
|---|---|---|---|---|---|---|---|---|
| 95 % | 156 | 2,60 pt | 1,45 pt | 5,74 pt | 39,40 pt | 0,47 | 5,57 | 17 |
| 99 % | 27 | 3,69 pt | 1,97 pt | 5,52 pt | 34,76 pt | 0,40 | 2,92 | 3 |

La plupart des dépassements sont **marginaux** (médiane de 1,45 point à 95 %), mais la distribution des tailles est à queue lourde : 17 dépassements sur 156 (11 %) sortent de plus d'une demi-largeur au-delà de la borne. Le maximum, le 12 mars 2020 (−46,5 %), vaut 5,6 demi-largeurs au-delà de la borne à 95 % et 2,9 au-delà de la borne à 99 %.

## 6. (D) Direction

| Test | Résultat | Seuil de Bonferroni (3 tests) : 0,0167 |
|---|---|---|
| 1. Ljung-Box sur les rendements, lag 10 / lag 20 | p = 0,029 / 0,075 | non significatif |
| 2. Persistance du signe à 1 jour | 2 111 / 4 391 = 48,1 % ; binomial p = 0,011 | significatif |
| 3. Tendance sur 20 jours → signe du lendemain (jours du backtest) | 1 616 / 3 193 = 50,6 % ; p = 0,50 | non significatif |
| Témoin : Ljung-Box sur \|rendements\| | p ≈ 0 (lag 10 et 20) | regroupement de volatilité massif |

Part de jours haussiers : 50,9 % ; rendement moyen du backtest : 0,056 %/jour (dérive réalisée, non une prévision).

**Lecture**
- **La volatilité est prévisible, la direction presque pas** : le témoin (|rendements|) rejette massivement l'absence de dépendance, les rendements eux-mêmes à peine.
- **Un seul signal ressort** : après un jour haussier, le lendemain est un peu plus souvent baissier (et inversement), avec 48,1 % de jours de même signe contre 50 %. Il franchit le seuil de Bonferroni (p = 0,011 < 0,0167) mais l'**écart est de 1,9 point**, avant tout coût de transaction : économiquement négligeable. Le test de signe est robuste aux queues lourdes (il ne dépend pas des moments) ; le Ljung-Box ne l'est pas (ν ≈ 3 : moment d'ordre 4 infini).
- **Aucune utilité opérationnelle visible** pour la direction avec ces signaux. Ce n'est pas une preuve d'imprévisibilité : seuls trois signaux simples ont été essayés.

## 7. Ce qu'on retient

1. La conclusion « Option 2 réussie » tient, mais **le critère 4.1 est peu discriminant** : un modèle simple (EWMA + FHS) le passe aussi.
2. Le MS-GARCH est le meilleur des cinq modèles aux scores d'intervalle, de **peu** à 95 % et solidement seulement face à EWMA + FHS.
3. Son apport est la **calibration des queues et l'uniformité de la couverture**, pas le classement des jours risqués.
4. Les dépassements sont le plus souvent marginaux ; la queue des tailles est lourde et dominée par le 12 mars 2020.
5. Direction : rien d'exploitable avec les signaux testés.

## 8. Limites

- Exploratoire : jamais prévu au cadrage, jamais corrigé des comparaisons au-delà de ce qui est dit ; les p sont indicatifs.
- Les références simples ont des réglages fixés d'avance (λ = 0,94 ; fenêtres 365 et 730 jours), non optimisés : un réglage différent pourrait changer l'écart.
- Le score d'intervalle est testé à 95 % seulement.
- Une seule exécution, un seul actif.

## 9. Fichiers produits

- `code/verification_btc.R`
- `data/processus/btc_verif_benchmarks.csv`, `btc_verif_conditional_terciles.csv`, `btc_verif_mincer_zarnowitz.csv`, `btc_verif_breach_size.csv`, `btc_verif_direction.csv`
