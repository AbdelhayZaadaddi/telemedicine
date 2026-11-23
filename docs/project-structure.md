# Project structure

This page explains how the project folders are organized and what goes in each one.

## Overview

```text
telemedicine/
├── conception/
├── plans/
├── docs/
├── db/
├── wildfly/
└── src/
    ├── main/
    │   ├── java/com/auto/telemedicine/
    │   │   ├── entity/
    │   │   │   └── enums/
    │   │   ├── repository/
    │   │   ├── service/
    │   │   ├── resource/
    │   │   ├── web/
    │   │   ├── security/
    │   │   └── websocket/
    │   ├── resources/
    │   │   └── META-INF/
    │   └── webapp/
    │       ├── WEB-INF/
    │       │   └── templates/
    │       ├── resources/
    │       │   └── css/
    │       ├── patient/
    │       ├── medecin/
    │       └── admin/
    └── test/
        └── java/com/auto/telemedicine/
```

## Project root

| Folder        | Role                                                                                       |
|---------------|--------------------------------------------------------------------------------------------|
| `conception/` | Design documents: design report (docx), SQL script and screen mockups (PDF). This is the reference for everything else. |
| `plans/`      | Implementation plans, one per phase (they match the lists on the Trello board).            |
| `docs/`       | Project documentation (this page, setup guides, decisions).                                |
| `db/`         | SQL script that creates the tables and loads the test data. Docker runs it on first start. |
| `wildfly/`    | Scripts that configure WildFly (PostgreSQL driver and the `TelemedicineDS` datasource).    |

## Java code — `src/main/java/com/auto/telemedicine/`

| Package        | Role                                                                                                    | Examples                                     |
|----------------|---------------------------------------------------------------------------------------------------------|----------------------------------------------|
| `entity/`      | JPA entities: one class per database table.                                                             | `Patient`, `Medecin`, `RendezVous`           |
| `entity/enums/`| The enums used by the entities, with the same values as the SQL types.                                  | `Role`, `StatutRdv`, `StatutAttente`         |
| `repository/`  | Database access only: find, save, delete, queries. Uses the `EntityManager`.                            | `GenericRepository`, `PatientRepository`     |
| `service/`     | Business rules: checks and actions of the application. Calls the repositories.                          | `RendezVousService` (book a slot, cancel)    |
| `resource/`    | REST endpoints under `/api/...` (JAX-RS). Receive the request, call a service, return JSON.             | `HealthResource`, `RendezVousResource`       |
| `web/`         | JSF beans used by the `.xhtml` pages: hold the form data and call the services.                         | `PriseRdvBean`, `DossierBean`                |
| `security/`    | Login, password hashing and roles (PATIENT, MEDECIN, ADMIN).                                            | `LoginBean`, `PasswordHasher`                |
| `websocket/`   | Real-time updates for the virtual waiting room (the doctor calls the next patient).                     | `SalleAttenteSocket`                         |

The application root also holds `RestApplication.java` (`@ApplicationPath("/api")`).

### How the layers talk to each other

```text
 .xhtml page ──> web/ ───┐
                         ├──> service/ ──> repository/ ──> entity/ ──> database
 REST client ──> resource/┘
```

Each layer only calls the layer below it:

- `web/` and `resource/` never use the `EntityManager` directly: they go through `service/`.
- `service/` holds the rules (e.g. "a doctor cannot have two appointments at the same time").
- `repository/` only reads and writes data, without business rules.

## Configuration — `src/main/resources/`

| Folder      | Role                                                                        |
|-------------|-----------------------------------------------------------------------------|
| `META-INF/` | `persistence.xml`: the JPA unit `telemedicinePU` linked to `TelemedicineDS`. |

## Web pages — `src/main/webapp/`

| Folder                | Role                                                                                 |
|-----------------------|--------------------------------------------------------------------------------------|
| `WEB-INF/`            | Web configuration: `web.xml` (JSF), `beans.xml` (CDI). Its files cannot be opened from the browser. |
| `WEB-INF/templates/`  | `layout.xhtml`: the common layout (header, side menu) used by every page.            |
| `resources/css/`      | `app.css`: page style and status badges (PLANIFIE, CONFIRME, ANNULE...).             |
| `patient/`            | Pages for patients: book an appointment, my appointments, waiting room, my prescriptions. |
| `medecin/`            | Pages for doctors: schedule, waiting room queue, consultation, patient record, write a prescription. |
| `admin/`              | Pages for the admin: users, specialties, medicines.                                  |

The pages are split by role so that each folder can be protected for one role only
(e.g. `/medecin/*` reserved to MEDECIN).

## Tests — `src/test/java/com/auto/telemedicine/`

Unit tests (JUnit 5), with the same packages as the main code
(e.g. tests for `service/RendezVousService` go in `service/RendezVousServiceTest`).
