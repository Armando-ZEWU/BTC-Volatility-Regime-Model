# Economics — Lecture économique du modèle Bitcoin (Option 2)

> Ce document ne contient que des **interprétations économiques**. Les chiffres cités viennent des étapes 1 à 7 et du complément exploratoire `verification_btc.R`. Toute valeur qui ne vient pas du modèle est signalée comme telle.

---

## 1. Ce que le modèle mesure vraiment

Le modèle mesure **le risque de variation du prix en un jour** (la volatilité et sa fourchette), pas la valeur du Bitcoin ni sa direction.

| Question économique | Le modèle répond ? |
|---|---|
| De combien le prix peut-il bouger demain ? | **Oui** (fourchette à 95 %) |
| Le risque est-il élevé ou faible en ce moment ? | **Oui** (état volatil / calme, volatilité prévue) |
| Le prix va-t-il monter ou baisser ? | **Non** (direction non prévisible : voir §5) |
| Combien vaut le Bitcoin ? | **Non** (aucun fondamental dans le modèle) |
| Pourquoi le risque change-t-il ? | **Non** (aucune variable explicative) |

Exemple chiffré (étape 5) : pour le 2026-09-29, à partir de 83 502,61 $, la fourchette à 95 % est [80 139 $ ; 86 997 $], soit environ **±4 %** autour du dernier prix, pour une volatilité prévue de 2,69 %/jour (≈ 51 % annualisée, calcul simple 2,69 × √365).

---

## 2. Deux actifs, deux natures économiques

### EUR/USD : une monnaie avec ancrage institutionnel

- Deux banques centrales (BCE, Fed) poursuivent des objectifs d'inflation explicites et ajustent leurs taux en conséquence.
- Le prix est **rappelé** vers des niveaux compatibles avec les fondamentaux (écarts de taux, inflation relative, balance des paiements), même si ce rappel est lent et imparfait.
- La volatilité y a un **niveau « normal »** autour duquel elle fluctue : les chocs finissent par s'estomper.
- Le risque principal : un choc macro ou une surprise de politique monétaire, dans un cadre où quelqu'un a le mandat et les moyens d'intervenir.

### Bitcoin : un actif sans ancrage institutionnel

- Aucune autorité ne défend un niveau de prix, ne fixe un objectif ou ne joue le prêteur en dernier ressort.
- L'offre est **règle-fixée** (algorithmique) et donc parfaitement inélastique à court terme : toute variation de la demande passe **entièrement par le prix**. Il n'y a pas d'amortisseur de quantité.
- La valeur repose sur la **croyance collective** et sur la liquidité des plateformes : une grande partie du prix est auto-référentielle (on achète parce que d'autres achèteront).
- Marché ouvert 24 h/24, 7 j/7 : pas de pause pour absorber l'information, pas de clôture qui interrompt une spirale.

**Conséquence directe pour la lecture des résultats :** comparer les deux actifs revient à comparer un prix *ancré* à un prix *flottant sans ancre*. Les différences de résultats ne sont pas un défaut du modèle, elles sont l'information.

---

## 3. Ce que chaque résultat dit économiquement

### 3.1 Queues très lourdes (Student's t, ν ≈ 3,18)

- Les queues sont lourdes : c'est solide (QQ-plots : la Normale est rejetée nettement, les résidus du GARCH-t suivent bien la t). Mais **la valeur précise de l'indice de queue n'est pas identifiée** : ν = 3,18 (GARCH-t, conditionnel), ν = 2,23 (t inconditionnelle sur les rendements bruts), et l'estimateur de Hill n'a pas de plateau (α̂ entre 4-5 pour k petit et ≈ 2-2,5 pour k = 400). Ne pas écrire « ν ≈ 3 » comme une constante du marché.
- Le kurtosis excès global (11,98) mélange des niveaux de volatilité différents selon les années et un seul jour extrême : par année, il vaut 1,5 à 4,6 pour la plupart des années, ≈ 10 en 2015-2016 et 50,9 en 2020 (dominé par le 12 mars). Les extrêmes existent chaque année, mais leur intensité varie beaucoup.
- Les pertes ont une queue plus lourde que les gains (Hill, log-log, asymétrie −0,7), alors que le GARCH-t est symétrique : le risque baissier est probablement un peu sous-estimé par la fourchette, test à faire (répartition des dépassements bas/haut).
- Économiquement : les grands mouvements viennent d'un marché où l'information, la panique et les liquidations forcées (effets de levier) arrivent par grappes, sans mécanisme public qui les freine.

### 3.2 Persistance à la frontière (α + β = 1,0000, type IGARCH)

- Lecture économique naïve : « les chocs de volatilité ne s'estompent jamais, il n'y a pas de niveau normal de risque ». Cela serait cohérent avec l'absence d'ancrage.
- **Réserve importante :** une persistance égale à 1 est aussi le symptôme classique de **ruptures structurelles non modélisées**. Or le test de type Chow rejette la stabilité entre les deux moitiés de l'échantillon (LR = 19,91, p = 0,0013). Les deux lectures (« pas d'ancre » vs « artefact de changements d'époque ») ne sont **pas départagées** par ce modèle seul. Il faut garder les deux sur la table.

### 3.3 Régimes (MS-GARCH, K = 2)

- Régime volatil ≈ 69 % des jours, durée espérée 72,8 jours ; régime calme durée espérée 35,9 jours. Ces chiffres viennent de la matrice de transition **de l'échantillon complet** (calme→calme 97,22 %, volatil→volatil 98,63 %). Les ré-estimations annuelles du backtest (figure 17) confirment des régimes persistants dans chacune des 9 années : durée espérée de 34 à 42 jours pour le calme et de 36 à 65 jours pour le volatil, la durée du volatil s'allongeant à partir de 2022. La probabilité de régime du graphique 15 oscille vite parce que le filtre réagit aux rendements, pas parce que les régimes seraient courts.
- Réserve sur les étiquettes : le régime dit « calme » n'est pas calme en absolu (σ = 2,61 %/jour, soit ≈ 50 % annualisé, contre 3,81 % pour le volatil) et son kurtosis (82,8) trahit des sauts isolés, probablement le 12 mars 2020 (à vérifier). Ses paramètres sont extrêmes dans toutes les ré-estimations (ν ≈ 2,3 ; persistance ≈ 0,999). Lecture prudente : « calme » = jours tranquilles ponctués de sauts ; « volatil » = volatilité élevée plus soutenue (ν de 5 vers 4, persistance de 0,965 vers 0,984 de 2018 à 2026). Test réalisé (graphique 18) : le σ réalisé du régime volatil passe de 4,54 %/jour en 2018 à 2,49 % en 2026, et celui du calme de 3,88 % à 2,31 %. Le « volatil » de 2025 (2,33 %, ≈ 45 % annualisé) est moins volatil que le « calme » de 2018 (3,88 %, ≈ 74 % annualisé). **Les étiquettes sont donc relatives à chaque ré-estimation**, jamais absolues : « volatil » ne veut pas dire risque élevé en soi, et on ne compare pas les régimes d'une année à l'autre.
- Économiquement : sur le Bitcoin, **le régime « volatil » est l'état ordinaire et le calme est l'exception**. Pour l'EUR/USD, la logique est inverse (le calme est la norme, la crise l'exception).
- Ces régimes sont **statistiques, pas économiques** : le modèle ne sait pas si un régime correspond à un cycle de halving, à une phase de levier, à un durcissement monétaire, etc. Toute étiquette de ce type serait une hypothèse à tester séparément.
- Règle « ère vs régime » : PAS_ERE (plus long bloc volatil 676 jours, 26 blocs volatils). Lecture : la volatilité alterne en phases répétées, elle n'a pas basculé une fois pour toutes vers un nouveau niveau permanent.
- Tension à assumer : le test de Chow détecte pourtant une différence entre les deux moitiés. Décision gelée : ce test est corroborant et non décisif, donc il ne change pas le verdict. L'économie dit « les deux phénomènes coexistent probablement » ; le modèle n'a pas été conçu pour trancher.

### 3.4 Rendement moyen (μ ≈ 0,11 %/jour, significatif)

- Une dérive en échantillon élevée reflète **l'histoire de l'adoption** (un actif qui passe d'inconnu à mainstream), pas un rendement futur attendu. Elle porte un fort biais de rétrospection : l'échantillon commence en 2014 et inclut les phases de découverte du prix.
- Un acheteur ne doit **pas** l'extrapoler.

---

## 4. Point de vue de l'acheteur / de l'entreprise

### 4.1 Entreprise qui accepte ou paie en Bitcoin

- La fourchette de ≈ ±4 %/jour signifie qu'un prix affiché en BTC peut s'écarter de plusieurs pourcents de sa valeur en monnaie légale entre la commande et le règlement. Pour comparaison, **ordre de grandeur de connaissance générale, non issu de ce modèle** : l'EUR/USD bouge typiquement de l'ordre de quelques dixièmes de pourcent par jour.
- Cela fait du BTC une **mauvaise unité de compte** et un médiocre moyen de paiement différé : les marges de beaucoup d'activités sont inférieures à la volatilité d'une seule journée.
- Choix économique logique : conversion immédiate en monnaie légale (le risque est transféré à un intermédiaire, qui facture une prime) plutôt que détention.

### 4.2 Entreprise qui détient du Bitcoin en trésorerie

- La fourchette quotidienne est une **mesure de risque de marché** utile pour dimensionner une réserve de fonds propres ou un plafond de position.
- Mais l'horizon du modèle est **un jour**. Le risque sur un mois ne se déduit pas en multipliant : avec persistance et régimes, la variance ne s'additionne pas proprement. Pour un horizon de gestion réaliste, il faut une simulation multi-pas, non réalisée ici.
- Le coût économique du risque n'est pas seulement la volatilité moyenne : c'est aussi **le moment** où elle survient (appels de marge, covenants, besoin de cash). Un risque élevé en période de stress a une valeur économique plus lourde qu'en période calme.

### 4.3 Acheteur individuel / investisseur

- Le modèle permet de calibrer **la taille** d'une position (combien je risque par jour), pas **le moment** ni **la direction**.
- La question économique centrale n'est pas « combien bouge-t-il ? » mais « qu'est-ce qui me rémunère pour supporter ce risque ? ». Sans flux de revenus, ni coupon, ni dividende, ni valeur d'usage garantie, **le seul rendement est la revente à quelqu'un d'autre** : le rendement attendu dépend donc de la croyance et de la liquidité futures, deux choses que le modèle ne mesure pas.

---

## 5. Direction : ce que montre le test, et son poids économique

| Test (`verification_btc.R`) | Résultat | Lecture |
|---|---|---|
| Persistance du signe à 1 jour | 48,1 % (p = 0,011) | Légère tendance au retournement, statistiquement détectable |
| Tendance sur 20 jours | 50,6 % (p = 0,50) | Aucun signal |

- 48,1 % contre 50 % est un écart de moins de 2 points. **Statistiquement significatif ne veut pas dire économiquement exploitable** : frais de transaction, spread et glissement absorbent facilement un tel avantage. Sans test net de coûts, ce résultat ne justifie aucune stratégie.
- Lecture cohérente avec un marché très liquide et très surveillé : la direction n'est pas prévisible à partir du seul historique de prix.

---

## 6. Ce que le modèle ne montre PAS (limites économiques)

1. **Les causes.** Aucune variable macro (taux, dollar, liquidité mondiale, inflation, aversion au risque), aucune donnée de volume, de levier, de flux d'échange. Le modèle décrit *comment* le prix bouge, pas *pourquoi*.
2. **La magnitude des pertes extrêmes.** La couverture à 95 % (95,11 %, Kupiec p = 0,766, Christoffersen p = 0,610) compte la **fréquence** des dépassements, pas leur **taille**. Exemple frappant : le 2020-03-12, rendement de −46,5 % pour une borne à −7,1 %, soit environ 6,5 fois la borne. Pour une entreprise, c'est la taille de cette perte qui menace la solvabilité, et le test de couverture ne la voit pas.
3. **Le risque de contrepartie et de plateforme.** Faillite d'une bourse, gel de retraits, piratage : des risques économiques majeurs, absents d'une série de prix de clôture.
4. **Le risque réglementaire.** Interdictions, fiscalité, régimes de licence : des chocs d'offre/demande légaux que le modèle ne distingue pas d'un choc de marché.
5. **L'intra-journalier.** Une clôture à minuit UTC cache l'amplitude réelle sur 24 h ; un appel de marge peut se déclencher dans la journée sans apparaître dans la série.
6. **Les horizons longs.** La fourchette vaut pour demain, pas pour un trimestre.
7. **La valeur fondamentale.** Le modèle est silencieux sur la question de savoir si le prix est « juste ».
8. **La causalité des régimes.** Les états calme/volatil sont des étiquettes statistiques.
9. **Un avantage net du modèle sophistiqué.** Le MS-GARCH a le meilleur score d'intervalle à 95 % (18,54) mais devant des alternatives bien plus simples (18,84 à 19,35 : GARCH-t K=1, EWMA normale, EWMA + FHS, simulation historique 365 jours), et EWMA + FHS passe aussi le critère 4.1. **Économiquement, un praticien peut obtenir l'essentiel du résultat avec un outil beaucoup plus simple.** La valeur du MS-GARCH est la lecture en régimes, pas un gain de précision net.
10. **La couverture à 99 %.** Rapportée (99,15 %, 27 dépassements) sans critère pass/fail : elle ne doit pas être présentée comme validée au même titre que le 95 %.
11. **Une dérive récente vers le conservatisme.** Sur l'ensemble : 156 dépassements observés contre 159,65 attendus à 95 % (−3,65) et 27 contre 31,9 à 99 % (−4,9). Le cumul est resté dans l'enveloppe, mais il baisse de façon continue depuis 2024 et la couverture 2025 atteint 97,3 %. Les bandes semblent devenir trop larges pendant que la volatilité réalisée baisse (σ journalier tous jours confondus : 4,29 % en 2018, 2,43 % en 2026). Piste à tester, non démontrée : une fenêtre d'estimation qui s'allonge garde en mémoire les années 2018-2022, plus agitées, alors qu'une fenêtre glissante s'adapterait plus vite. À surveiller, pas à conclure.
12. **Une fourchette qui réagit après le choc, pas avant.** Largeur maximale en mars 2020 (≈ 50 points de log-rendement) après le crash du 12 mars : le modèle élargit, il n'anticipe pas.

---

## 7. Réponse type à « Ce modèle peut-il servir d'outil d'analyse du marché du Bitcoin ? »

**Oui, comme outil d'analyse du risque ; non, comme outil de prévision de prix ni d'explication.**

- Il fournit une fourchette de variation à un jour, bien calibrée en fréquence sur 3 193 prévisions (2018-2026), et il décrit le Bitcoin comme un actif où le régime volatil est dominant et les chocs extrêmes fréquents.
- Il ne dit rien de la direction, des causes, des pertes extrêmes en taille, ni de la valeur de l'actif.
- Son usage économique légitime : **dimensionner le risque** (taille de position, réserve, marge de sécurité de prix) et **mettre en évidence ce qui distingue le Bitcoin d'une monnaie ancrée**.

---

## 8. Cohérence avec l'objectif de l'étude

L'étude ne cherche pas à reproduire les résultats de l'EUR/USD. Elle teste si une méthode validée sur un actif ancré **se généralise** à un actif sans ancre. Le résultat est nuancé : la méthode fonctionne **statistiquement** (couverture, indépendance), mais l'**interprétation économique** diffère profondément : persistance maximale, queues plus lourdes, régime volatil dominant, risque de lecture biaisée par les changements d'époque. Cette différence est le résultat scientifique principal de l'Option 2.
