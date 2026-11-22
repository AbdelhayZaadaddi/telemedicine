# Télémédecine simplifiée

Projet EMSI — Programmation avancée. Application Jakarta EE 10 (JAX-RS, CDI, JPA/Hibernate, Bean Validation)
déployée sur WildFly avec une base PostgreSQL (Docker).

Fonctionnalités prévues : rendez-vous, salle d'attente, dossier patient.

## Prérequis

- JDK 21+
- Maven 3.9+
- WildFly (testé avec 42.0.0.Final)
- Docker (pour PostgreSQL)

## 1. Lancer PostgreSQL

```bash
docker compose up -d
```

Base `telemedicine`, utilisateur/mot de passe `telemedicine` / `telemedicine`, port `5432`.

## 2. Configurer la datasource dans WildFly (une seule fois)

Démarrer WildFly dans un terminal :

```bash
$WILDFLY_HOME/bin/standalone.sh
```

Puis, dans un autre terminal :

```bash
WILDFLY_HOME=~/Documents/servers/wildfly-42.0.0.Final ./wildfly/setup-datasource.sh
```

Ce script installe le driver JDBC PostgreSQL et crée la datasource `java:jboss/datasources/TelemedicineDS`
référencée dans `persistence.xml`.

## 3. Build

```bash
mvn clean package
```

Produit `target/telemedicine.war`.

## 4. Déploiement

```bash
cp target/telemedicine.war $WILDFLY_HOME/standalone/deployments/
```

Les tables sont créées automatiquement au déploiement (`hibernate.hbm2ddl.auto=update`).

## 5. Tester

```bash
curl http://localhost:8080/telemedicine/api/health
# {"status":"ok"}

curl -X POST http://localhost:8080/telemedicine/api/patients \
  -H "Content-Type: application/json" \
  -d '{"nom":"Alami","prenom":"Sara","email":"sara.alami@example.com","dateNaissance":"1995-04-12"}'

curl http://localhost:8080/telemedicine/api/patients
curl http://localhost:8080/telemedicine/api/patients/1
curl -X PUT http://localhost:8080/telemedicine/api/patients/1 \
  -H "Content-Type: application/json" \
  -d '{"nom":"Alami","prenom":"Sara","email":"sara.alami@example.com","dateNaissance":"1995-04-13"}'
curl -X DELETE http://localhost:8080/telemedicine/api/patients/1
```

Codes de retour : `201` création, `204` suppression, `400` données invalides, `404` patient introuvable,
`409` email déjà utilisé.

## Structure

```
com.emsi.telemedicine
├── RestApplication      @ApplicationPath("/api")
├── entity               entités JPA (Patient)
├── repository           accès aux données (EntityManager)
├── service              logique métier (CDI, @Transactional)
├── resource             endpoints JAX-RS (PatientResource, HealthResource)
├── dto                  objets échangés en JSON (PatientDTO, ErrorResponse)
└── exception            exceptions métier + ExceptionMappers JAX-RS
```
