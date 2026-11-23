# Plan 01 — Socle & modèle de données

**Goal:** a WAR that deploys on **WildFly 42**, connects to PostgreSQL, maps all 15 tables
of `conception/telemedecine (1).sql` as JPA entities, and shows a shared JSF layout.

**Trello list:** "1. Socle & modèle de données"

**Done when:**

- `./mvnw clean package` builds `target/telemedicine.war`.
- Deployment on WildFly succeeds with `hibernate.hbm2ddl.auto=validate`
  (this proves that every entity matches the SQL schema).
- `GET /telemedicine/api/health` returns the row counts of the test data.
- `/telemedicine/index.xhtml` shows the shared layout (side menu + status badges).

---

## Why WildFly

WildFly is a full Jakarta EE 10 server. It already contains everything the design needs:
JAX-RS, CDI, JPA (Hibernate), JTA transactions, Bean Validation, JSF, Jakarta Security
and WebSocket. So:

- the WAR contains **only our code**: every Jakarta library is `provided`;
- transactions are just `@Transactional` (no manual `begin()/commit()`);
- the database connection is a **WildFly datasource**, not passwords in `persistence.xml`.

## Current state (starting point)

- WildFly is installed in `~/Documents/servers/wildfly-42.0.0.Final`.
- `pom.xml` uses `provided` APIs (CDI, JAX-RS, servlet), **but**:
  - `hibernate-core`, `hibernate-validator` and `jaxb-runtime` are in `compile` scope,
    so they end up inside the WAR. WildFly already has them → class conflicts. Remove them.
  - Java is still 8.
- `persistence.xml` exists but is empty (unit `default`).
- `src/main/java/com/auto/telemedicine/` holds `HelloApplication` and `HelloResource`.
- No `docker-compose.yml` and no datasource script yet (they exist in the first commit
  `618d581` and can be reused).
- Package to use for all code: `com.auto.telemedicine`.

## Target package layout

```text
com.auto.telemedicine
├── RestApplication.java        (@ApplicationPath("/api"))
├── entity/                     JPA entities
│   └── enums/                  the 6 enums
├── repository/                 generic repository + one per entity when needed
├── resource/                   JAX-RS resources (HealthResource for now)
└── web/                        JSF beans (later plans)
```

---

## Step 0 — Clean the project base

1. `pom.xml`:
   - Java **21**: replace `maven.compiler.source/target` 8 with `<maven.compiler.release>21</maven.compiler.release>`.
   - Replace **all** dependencies (cdi-api, ws.rs-api, servlet-api, hibernate-core,
     jaxb-runtime, hibernate-validator) with one:
     `jakarta.platform:jakarta.jakartaee-api:10.0.0`, scope `provided`.
   - Keep JUnit 5 (test scope).
   - Add `<finalName>telemedicine</finalName>` in `<build>` so the URL is `/telemedicine`.
2. Delete `HelloApplication.java` and `HelloResource.java`.
3. Create `RestApplication` (`@ApplicationPath("/api")`, empty body).
4. Create `resource/HealthResource`: `GET /health` returns `{"status":"ok"}`.
5. Move `beans.xml` to `src/main/webapp/WEB-INF/beans.xml`
   (with `bean-discovery-mode="annotated"`).

**Check:** start WildFly (`$WILDFLY_HOME/bin/standalone.sh`), deploy
(`cp target/telemedicine.war $WILDFLY_HOME/standalone/deployments/` or the IntelliJ run
configuration), then
`curl http://localhost:8080/telemedicine/api/health` → `{"status":"ok"}`.

**Commit:** `chore: clean pom for Jakarta EE 10 on WildFly`

## Step 1 — PostgreSQL with Docker

1. Copy the SQL script to `db/telemedicine.sql` (no spaces in the name).
2. Create `docker-compose.yml` (start from the one in commit `618d581`):
   - image `postgres:17`, database `telemedicine`, user `telemedicine`, port **5433** on the Mac (5432 is taken by the local PostgreSQL 18).
   - **add** a mount of `./db/telemedicine.sql` into `/docker-entrypoint-initdb.d/`
     so the schema **and** the test data load on first start.
   - a named volume for the data.

**Check:** `docker compose up -d`, then
`docker exec -it telemedicine-postgres psql -U telemedicine -c "select count(*) from utilisateur;"` → 5.

> To reset the database (needed if the old volume already exists):
> `docker compose down -v && docker compose up -d`.

**Commit:** `chore: add PostgreSQL docker setup with schema and test data`

## Step 2 — WildFly datasource + persistence.xml

1. Restore `wildfly/setup-datasource.sh` from commit `618d581`
   (`git checkout 618d581 -- wildfly/setup-datasource.sh`) and change the URL to:
   `jdbc:postgresql://localhost:5433/telemedicine?stringtype=unspecified`

   `stringtype=unspecified` is important: the SQL script uses PostgreSQL
   `ENUM` types. With this option, Java enums saved as text are accepted by
   PostgreSQL without any extra code.

   > If `TelemedicineDS` already exists in your WildFly from earlier, do not run the
   > script again: only update the URL with jboss-cli:
   > `/subsystem=datasources/data-source=TelemedicineDS:write-attribute(name=connection-url,value="jdbc:postgresql://localhost:5433/telemedicine?stringtype=unspecified")`
   > then `:reload`.
2. Fill `src/main/resources/META-INF/persistence.xml`:
   - unit `telemedicinePU`, `transaction-type="JTA"`,
     `<jta-data-source>java:jboss/datasources/TelemedicineDS</jta-data-source>`
   - `<exclude-unlisted-classes>false</exclude-unlisted-classes>`
   - `hibernate.hbm2ddl.auto` = `validate` (the SQL script owns the schema; Hibernate only checks it)
   - `hibernate.show_sql` = `true` while developing.

**Check:** redeploy, no error in the WildFly log
(`/subsystem=datasources/data-source=TelemedicineDS:test-connection-in-pool` → `true`).

**Commit:** `chore: add WildFly datasource and persistence unit`

## Step 3 — The 6 Java enums (card "Créer les 6 énumérations Java")

In `entity/enums/`, with the exact values of the SQL script:

| Enum               | Values                                                |
|--------------------|-------------------------------------------------------|
| `Role`             | PATIENT, MEDECIN, ADMIN                               |
| `Sexe`             | F, M                                                  |
| `StatutRdv`        | PLANIFIE, CONFIRME, EN_COURS, TERMINE, ANNULE, ABSENT |
| `StatutAttente`    | EN_ATTENTE, APPELE, EN_CONSULTATION, TERMINE, ABANDON |
| `StatutOrdonnance` | EMISE, ANNULEE                                        |
| `TypeDocument`     | ANALYSE, IMAGERIE, COMPTE_RENDU, AUTRE                |

Every enum field in an entity uses `@Enumerated(EnumType.STRING)`.

**Commit:** `feat: add domain enums`

## Step 4 — Users (card "Entités Utilisateur / Patient / Medecin + Specialite")

- `Utilisateur`: `@Inheritance(strategy = InheritanceType.JOINED)`, table `utilisateur`.
- `Patient extends Utilisateur` and `Medecin extends Utilisateur`, each with
  `@PrimaryKeyJoinColumn(name = "utilisateur_id")`.
- `Medecin` → `@ManyToOne Specialite` (column `specialite_id`).
- `Specialite`: id is `Integer` (SQL `SERIAL`).

Notes:

- No discriminator column exists in the SQL, and JOINED does not need one.
  The `role` column is a normal field.
- Use `LocalDate`, `LocalDateTime`, `LocalTime` and `BigDecimal` (for `tarif`).
- Use `@Column(name = "...")` whenever the Java name differs from the column
  (e.g. `motDePasseHash` → `mot_de_passe_hash`).

**Check:** redeploy → `validate` passes.
**Commit:** `feat: add user entities`

## Step 5 — Appointments (card "Entités Disponibilite, RendezVous, SalleAttente")

- `Disponibilite` → `@ManyToOne Medecin`.
- `RendezVous` → `@ManyToOne Patient`, `@ManyToOne Medecin`, `StatutRdv statut`.
- `SalleAttente` → `@OneToOne RendezVous` (column `rendez_vous_id`).

**Check:** redeploy → `validate` passes. **Commit:** `feat: add appointment entities`

## Step 6 — Medical record (card "Entités DossierMedical, Consultation, DocumentMedical")

- `DossierMedical` → `@OneToOne Patient` (column `patient_id`).
- `Consultation` → `@OneToOne RendezVous`, `@ManyToOne DossierMedical` (column `dossier_id`).
- `DocumentMedical` → `@ManyToOne DossierMedical`, `@ManyToOne Consultation` (nullable).

**Check:** redeploy → `validate` passes. **Commit:** `feat: add medical record entities`

## Step 7 — Prescriptions (card "Entités Medicament, Ordonnance, LigneOrdonnance")

- `Medicament`: id is `Integer` (SQL `SERIAL`).
- `Ordonnance` → `@ManyToOne Consultation`,
  `@OneToMany(mappedBy = "ordonnance", cascade = ALL) List<LigneOrdonnance> lignes`.
- `LigneOrdonnance` → `@ManyToOne Ordonnance`, `@ManyToOne Medicament`.

**Check:** redeploy → `validate` passes. **Commit:** `feat: add prescription entities`

### Relations rules (all steps)

- Default every `@ManyToOne` / `@OneToOne` to `fetch = FetchType.LAZY`.
- Only add the reverse side (`@OneToMany`) when a screen needs it.
  For now only `Ordonnance.lignes`.

## Step 8 — Repositories + test data (card "Repositories génériques + chargement du jeu de test")

1. `repository/GenericRepository<T, ID>` (abstract class):
   - `@PersistenceContext EntityManager em` (WildFly injects it).
   - `findById`, `findAll`, `save` (persist or merge), `delete`, `count`.
2. One small class per entity that needs it, e.g.
   `@ApplicationScoped @Transactional public class PatientRepository extends GenericRepository<Patient, Long>`.
   `@Transactional` is enough: WildFly opens and commits the transaction.
   Start with the ones used by the health check: `PatientRepository`, `MedecinRepository`, `RendezVousRepository`.
3. Test data: already loaded by the SQL script (Step 1), nothing to code.
   Extend `HealthResource` to return counts, e.g.
   `{"status":"ok","patients":2,"medecins":2,"rendezVous":3}`.

**Check:** `curl .../api/health` shows those counts.
**Commit:** `feat: add generic repository and health counts`

## Step 9 — Shared JSF layout (card "Mise en page JSF commune")

JSF is built into WildFly: no dependency to add.

1. `src/main/webapp/WEB-INF/web.xml`: map the `FacesServlet` to `*.xhtml`,
   set `jakarta.faces.PROJECT_STAGE` to `Development`.
2. `src/main/webapp/WEB-INF/templates/layout.xhtml`: header, side menu
   (Rendez-vous, Salle d'attente, Dossier, Ordonnances, Admin) and a
   `ui:insert name="content"` area — follow the mockups PDF.
3. `src/main/webapp/resources/css/app.css`: layout + status badges
   (`.badge-planifie`, `.badge-confirme`, `.badge-en-cours`, `.badge-termine`,
   `.badge-annule`, `.badge-absent`, `.badge-en-attente`...).
4. `src/main/webapp/index.xhtml` uses the template and shows a few badges.

**Check:** open `http://localhost:8080/telemedicine/index.xhtml`.
**Commit:** `feat: add shared JSF layout`

## Step 10 — Close the phase

- Write a short `README.md` (prerequisites: JDK 21, WildFly 42, Docker; how to start
  the database, set up the datasource, build, deploy, URLs).
- Move all cards of list 1 to "Terminé".
- Next: Plan 02 — Sécurité & utilisateurs (Jakarta Security, `@RolesAllowed`,
  BCrypt hashes to replace `hash_demo`).
