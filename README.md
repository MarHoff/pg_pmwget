# PostgreSQL Poor's Man Web GET

***This side project is published for pedagogical and/or inspirational purposes. You should not run this into production!***
*While the code is in english, the remaining of the readme is currently available only in french.*

***Ce projet personnel est publié à des fins pédagogiques et/ou pour servir d'inspiration, il n'est pas adapté à l'usage en production!***
*Le code utilise majoritairement l'anglais, mais la suite du readme est pour l'instant disponible uniquement en français.*

## Utilisation

pmwget est une implémentation très basique et imparfaite d'un connecteur web pour PostgreSQL qui permet de récupérer le contenu d'une ou plusieurs requêtes HTTP pour utiliser le résultat directement en SQL.

Un exemple de cas d'usage de pmwget peut-être d'appeler une API renvoyant des données au format json qui pourront facilement être traitées avec les fonctionnalités intégrées de PostgreSQL.

### Exemple: Récupération d'un enregistrement via l'API Sirene
Voir documentation: https://entreprise.data.gouv.fr/api_doc/sirene

Si on s'intéresse aux informations sur l'établissement possédant le SIRET "79184256000025" on peut faire la requête suivante qui va renvoyer un json.
https://entreprise.data.gouv.fr/api/sirene/v3/etablissements/79184256000025

Grace à pmwget il est possible de récupérer directement ces informations au sein de PostgreSQL via la commande suivante:
```sql
SELECT wget_url FROM wget_url('https://entreprise.data.gouv.fr/api/sirene/v3/etablissements/79184256000025');
```
Résultat (visualisation d'une ligne):
|column |  value    |
|----|----------|
|wget_url | {"etablissement":{"id":1545310808,"siren":"791842560","nic":"00025","siret":"79184256000025" (...)


On peut aussi faire un "cast" du résultat vers le type jsonb pour l'exploiter avec les fonctions associées à ce type dans PostgreSQL.
```sql
SELECT
wget_url::jsonb #>> '{etablissement,siret}' siret,
wget_url::jsonb #>> '{etablissement,unite_legale,denomination}' denomination,
wget_url::jsonb #>> '{etablissement,date_dernier_traitement}' date_dernier_traitement
FROM wget_url('https://entreprise.data.gouv.fr/api/sirene/v3/etablissements/79184256000025');
```
Résultat:
|     siret      |     denomination     | date_dernier_traitement |
|----------------|----------------------|-------------------------|
| 79184256000025 | LA QUADRATURE DU NET | 2021-02-23T16:19:11|


Enfin on peut aussi utiliser une variante de la fonction qui accepte de multiples arguments en entrée pour agréger plusieurs appels à l'API et les paralléliser.
```sql
SELECT * 
FROM wget_urls('{
  https://entreprise.data.gouv.fr/api/sirene/v3/etablissements/79184256000025,
  https://entreprise.data.gouv.fr/api/sirene/v3/etablissements/11000012200033,
  https://entreprise.data.gouv.fr/api/sirene/v3/etablissements/50892929600046
}');
```
Résultat (visualisation d'une ligne):
|column |  value    |
|----|----------|
url            | https://entreprise.data.gouv.fr/api/sirene/v3/etablissements/79184256000025
payload        | {"etablissement":{"id":1545310808,"siren":"791842560","nic":"00025","siret":"79184256000025"  (...)
ts_end         | 2021-08-06 09:15:44.317855-04
duration       | 0.187239
batch          | 1
retries        | 0
batch_failrate | 0


Cette fonction fournie des colonnes de métadonnées qui nous informent plus spécifiquement sur les retry en cas d'échecs et la décomposition de l'appel en lots de taille adaptés aux appels à l'utilitaire wget.
L'ordre des résultats n'est pas garanti c'est pourquoi l'URL d'origine est la première colonne retournée.

Sur le même principe on peut ensuite manipuler les résultats avec un peu de SQL.
```sql
SELECT
payload::jsonb #>> '{etablissement,siret}' siret,
payload::jsonb #>> '{etablissement,unite_legale,denomination}' denomination,
payload::jsonb #>> '{etablissement,date_dernier_traitement}' date_dernier_traitement
FROM wget_urls('{
  https://entreprise.data.gouv.fr/api/sirene/v3/etablissements/79184256000025,
  https://entreprise.data.gouv.fr/api/sirene/v3/etablissements/11000012200033,
  https://entreprise.data.gouv.fr/api/sirene/v3/etablissements/50892929600046
}');
```
Résultat:
|     siret      |                      denomination                      | date_dernier_traitement |
|----------------|--------------------------------------------------------|-------------------------|
| 11000012200033 | COMMISSION NATIONALE DE L'INFORMATIQUE ET DES LIBERTES | 2020-08-25T10:13:00|
| 50892929600046 | OSGEO                                                  | 2021-02-23T15:14:49|
| 79184256000025 | LA QUADRATURE DU NET                                   | 2021-02-23T16:19:11|

## Comment ça fonctionne dans les grandes lignes?

Le projet est packagé sous forme d'une extension PostgreSQL contenant essentiellement des fonctions permettant d'organiser des appels à wget et de restituer ces réponse comme retour de ces fonctions.
Le lien est fait grâce à l'extension [plsh](https://github.com/petere/plsh) qui permet d'invoquer des commandes shell depuis PostgreSQL.
Le recours intermédiaire à [GNU Parallel](https://www.gnu.org/software/parallel/) permet de paralléliser ces appels.

## Pourquoi ne pas utiliser cela en production?

J'ai développé ce projet dans le cadre d'un projet personnel plus large [pg_hnranker](https://github.com/MarHoff/pg_hn_ranker).
Il est apparu en cours de développement que la partie du code concernant les appels HTTP méritait d'être séparée du reste car elle avait son intérêt propre.

Initialement j'imaginais d'ailleurs me reposer sur le plus sérieux [pgsql-http](https://github.com/pramsey/pgsql-http) de Paul Ramsey.
Néanmoins, sauf erreur de ma part, à l'époque cette extension ne permettait pas l’exécution en parallèle des requête http contrairement à pg_pmwget.
Le projet s'inspire et étend aussi le micro projet [pg_frapi](https://github.com/adauhr/pg_frapi) que j'avais développé dans un cadre professionnel.

Le lecteur attentif comprendra donc dans ces conditions que le code n'est absolument pas suffisamment sécurisé ou testé par rapport à des injections SQL ou à des utilisateurs malveillants.

Mon but était d'obtenir un prototype fonctionnel mais en aucun cas d'aboutir à un projet stabilisé et re-partageable.
D’où d'ailleurs le sobriquet "Poor's man", il s'agit d'un hack fait de bouts de ficelles qui m'a permis de développer mes compétences.
Mais ce projet a totalement vocation à être remplacé par un composant plus stable dès qu'un équivalent iso-fonctionnel sera disponible/identifié.

Comme ce projet est un fork basé sur des fonctions initialement développées au sein de [pg_hn_ranker](https://github.com/MarHoff/pg_hn_ranker) l'historique est ici très pauvre et il conviendra de se référer à cet autre projet si on veut mieux comprendre la genèse du code.

Pendant longtemps ce projet est d'ailleurs resté privé/masqué parce que je ne le trouvait pas assez abouti pour être présenté.
Mais en réalité il est sans doute toujours plus intéressant de partager ses projets inachevés car le chemin souvent tout aussi intéressant que le résultat.

## Installation

### Prérequis : paquets recommandés pour faire tourner la suite de test

(testé sous Debian et PostgreSQL 12)
```sh
postgresql-12
postgresql-contrib-12
postgresql-server-dev-12
postgresql-common
postgresql-12-pgtap
postgresql-12-plsh -- Indispensable pour permettre les appel a wget via le shell
libtap-parser-sourcehandler-pgtap-perl
git-core
git-gui
git-doc
build-essential
parallel -- Indispensable pour permettre les requête en parallèle
```

### Installation comme extension de PostgreSQL
```sh
git clone https://github.com/MarHoff/pg_pmwget.git
cd pg_pmwget
make build #Optionnel pour installer la version stable
make install
make test #Tente de faire tourner des test basiques avec pgtap

```

### Activation de l'extension dans PostgreSQL
```sql
CREATE EXTENSION pmwget CASCADE;
```