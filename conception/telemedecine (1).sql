-- =====================================================================
-- Télémédecine simplifiée — Script SQL (PostgreSQL 14+)
-- Modules : rendez-vous, salle d'attente virtuelle, dossier patient,
--           ordonnance numérique
-- Usage : psql -U postgres -c "CREATE DATABASE telemedecine;"
--         psql -U postgres -d telemedecine -f telemedecine.sql
-- =====================================================================

DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;

-- ---------------------------------------------------------------------
-- 1. Types énumérés (mappés par @Enumerated(EnumType.STRING) côté JPA)
-- ---------------------------------------------------------------------
CREATE TYPE role_utilisateur AS ENUM ('PATIENT', 'MEDECIN', 'ADMIN');
CREATE TYPE sexe_type AS ENUM ('F', 'M');
CREATE TYPE statut_rdv AS ENUM ('PLANIFIE', 'CONFIRME', 'EN_COURS', 'TERMINE', 'ANNULE', 'ABSENT');
CREATE TYPE statut_attente AS ENUM ('EN_ATTENTE', 'APPELE', 'EN_CONSULTATION', 'TERMINE', 'ABANDON');
CREATE TYPE statut_ordonnance AS ENUM ('EMISE', 'ANNULEE');
CREATE TYPE type_document AS ENUM ('ANALYSE', 'IMAGERIE', 'COMPTE_RENDU', 'AUTRE');

-- ---------------------------------------------------------------------
-- 2. Utilisateurs (héritage JOINED : utilisateur -> patient / medecin)
-- ---------------------------------------------------------------------
CREATE TABLE utilisateur
(
    id                BIGSERIAL PRIMARY KEY,
    nom               VARCHAR(80)      NOT NULL,
    prenom            VARCHAR(80)      NOT NULL,
    email             VARCHAR(150)     NOT NULL UNIQUE,
    mot_de_passe_hash VARCHAR(255)     NOT NULL,
    telephone         VARCHAR(20),
    role              role_utilisateur NOT NULL,
    actif             BOOLEAN          NOT NULL DEFAULT TRUE,
    date_creation     TIMESTAMP        NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE specialite
(
    id      SERIAL PRIMARY KEY,
    libelle VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE patient
(
    utilisateur_id BIGINT PRIMARY KEY
        REFERENCES utilisateur (id) ON DELETE CASCADE,
    date_naissance DATE      NOT NULL,
    sexe           sexe_type NOT NULL,
    adresse        VARCHAR(255),
    ville          VARCHAR(80)
);

CREATE TABLE medecin
(
    utilisateur_id BIGINT PRIMARY KEY
        REFERENCES utilisateur (id) ON DELETE CASCADE,
    numero_ordre   VARCHAR(30)   NOT NULL UNIQUE,
    specialite_id  INT           NOT NULL REFERENCES specialite (id),
    tarif          NUMERIC(8, 2) NOT NULL CHECK (tarif >= 0),
    biographie     TEXT
);

-- ---------------------------------------------------------------------
-- 3. Rendez-vous
-- ---------------------------------------------------------------------
CREATE TABLE disponibilite
(
    id           BIGSERIAL PRIMARY KEY,
    medecin_id   BIGINT   NOT NULL REFERENCES medecin (utilisateur_id) ON DELETE CASCADE,
    jour_semaine SMALLINT NOT NULL CHECK (jour_semaine BETWEEN 1 AND 7), -- 1 = lundi
    heure_debut  TIME     NOT NULL,
    heure_fin    TIME     NOT NULL,
    CHECK (heure_fin > heure_debut)
);

CREATE TABLE rendez_vous
(
    id            BIGSERIAL PRIMARY KEY,
    patient_id    BIGINT     NOT NULL REFERENCES patient (utilisateur_id),
    medecin_id    BIGINT     NOT NULL REFERENCES medecin (utilisateur_id),
    date_heure    TIMESTAMP  NOT NULL,
    duree_min     SMALLINT   NOT NULL DEFAULT 20 CHECK (duree_min > 0),
    motif         VARCHAR(255),
    statut        statut_rdv NOT NULL DEFAULT 'PLANIFIE',
    lien_visio    VARCHAR(255),
    date_creation TIMESTAMP  NOT NULL DEFAULT CURRENT_TIMESTAMP,
    -- un médecin ne peut pas avoir deux rendez-vous au même instant
    CONSTRAINT uq_rdv_medecin_creneau UNIQUE (medecin_id, date_heure)
);
CREATE INDEX idx_rdv_patient ON rendez_vous (patient_id, date_heure);
CREATE INDEX idx_rdv_medecin ON rendez_vous (medecin_id, date_heure);

-- ---------------------------------------------------------------------
-- 4. Salle d'attente virtuelle (une entrée par rendez-vous)
-- ---------------------------------------------------------------------
CREATE TABLE salle_attente
(
    id             BIGSERIAL PRIMARY KEY,
    rendez_vous_id BIGINT         NOT NULL UNIQUE
        REFERENCES rendez_vous (id) ON DELETE CASCADE,
    heure_arrivee  TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    heure_appel    TIMESTAMP,
    statut         statut_attente NOT NULL DEFAULT 'EN_ATTENTE',
    CHECK (heure_appel IS NULL OR heure_appel >= heure_arrivee)
);
CREATE INDEX idx_attente_statut ON salle_attente (statut, heure_arrivee);

-- ---------------------------------------------------------------------
-- 5. Dossier patient
-- ---------------------------------------------------------------------
CREATE TABLE dossier_medical
(
    id                   BIGSERIAL PRIMARY KEY,
    patient_id           BIGINT    NOT NULL UNIQUE
        REFERENCES patient (utilisateur_id) ON DELETE CASCADE,
    groupe_sanguin       VARCHAR(3) CHECK (groupe_sanguin IN ('A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-')),
    antecedents          TEXT,
    allergies            TEXT,
    traitements_en_cours TEXT,
    date_creation        TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE consultation
(
    id             BIGSERIAL PRIMARY KEY,
    rendez_vous_id BIGINT    NOT NULL UNIQUE REFERENCES rendez_vous (id),
    dossier_id     BIGINT    NOT NULL REFERENCES dossier_medical (id),
    debut          TIMESTAMP NOT NULL,
    fin            TIMESTAMP,
    diagnostic     TEXT,
    compte_rendu   TEXT,
    CHECK (fin IS NULL OR fin >= debut)
);
CREATE INDEX idx_consultation_dossier ON consultation (dossier_id, debut DESC);

CREATE TABLE document_medical
(
    id              BIGSERIAL PRIMARY KEY,
    dossier_id      BIGINT        NOT NULL REFERENCES dossier_medical (id) ON DELETE CASCADE,
    consultation_id BIGINT        REFERENCES consultation (id) ON DELETE SET NULL,
    type            type_document NOT NULL DEFAULT 'AUTRE',
    nom_fichier     VARCHAR(200)  NOT NULL,
    chemin          VARCHAR(400)  NOT NULL,
    date_ajout      TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------------
-- 6. Ordonnance numérique
-- ---------------------------------------------------------------------
CREATE TABLE medicament
(
    id           SERIAL PRIMARY KEY,
    denomination VARCHAR(150) NOT NULL,
    forme        VARCHAR(50),
    dosage       VARCHAR(50),
    UNIQUE (denomination, forme, dosage)
);

CREATE TABLE ordonnance
(
    id              BIGSERIAL PRIMARY KEY,
    numero          VARCHAR(30)       NOT NULL UNIQUE,
    consultation_id BIGINT            NOT NULL REFERENCES consultation (id),
    date_emission   DATE              NOT NULL DEFAULT CURRENT_DATE,
    date_validite   DATE              NOT NULL,
    statut          statut_ordonnance NOT NULL DEFAULT 'EMISE',
    signature_hash  VARCHAR(128)      NOT NULL, -- empreinte SHA-256 du contenu signé
    CHECK (date_validite >= date_emission)
);

CREATE TABLE ligne_ordonnance
(
    id            BIGSERIAL PRIMARY KEY,
    ordonnance_id BIGINT       NOT NULL REFERENCES ordonnance (id) ON DELETE CASCADE,
    medicament_id INT          NOT NULL REFERENCES medicament (id),
    posologie     VARCHAR(200) NOT NULL,
    duree_jours   SMALLINT     NOT NULL CHECK (duree_jours > 0),
    quantite      SMALLINT     NOT NULL DEFAULT 1 CHECK (quantite > 0),
    instructions  VARCHAR(255)
);

-- ---------------------------------------------------------------------
-- 7. Vue utile : file d'attente d'un médecin (ordre d'arrivée)
-- ---------------------------------------------------------------------
CREATE VIEW v_file_attente AS
SELECT sa.id                      AS attente_id,
       rv.medecin_id,
       rv.id                      AS rendez_vous_id,
       up.nom || ' ' || up.prenom AS patient,
       rv.date_heure,
       sa.heure_arrivee,
       sa.statut,
       ROW_NUMBER()                  OVER (PARTITION BY rv.medecin_id ORDER BY sa.heure_arrivee) AS position
FROM salle_attente sa
JOIN rendez_vous rv ON rv.id = sa.rendez_vous_id
JOIN utilisateur up ON up.id = rv.patient_id
WHERE sa.statut = 'EN_ATTENTE';

-- ---------------------------------------------------------------------
-- 8. Jeu de données de test
-- (mots de passe factices : à remplacer par un hash BCrypt côté application)
-- ---------------------------------------------------------------------
INSERT INTO specialite (libelle)
VALUES ('Médecine générale'),
       ('Cardiologie'),
       ('Dermatologie'),
       ('Pédiatrie');

INSERT INTO utilisateur (nom, prenom, email, mot_de_passe_hash, telephone, role)
VALUES ('Benali', 'Karim', 'k.benali@telemed.ma', 'hash_demo', '0600000001', 'MEDECIN'),
       ('Alaoui', 'Salma', 's.alaoui@telemed.ma', 'hash_demo', '0600000002', 'MEDECIN'),
       ('Idrissi', 'Yassine', 'y.idrissi@mail.com', 'hash_demo', '0600000011', 'PATIENT'),
       ('Tazi', 'Imane', 'i.tazi@mail.com', 'hash_demo', '0600000012', 'PATIENT'),
       ('Admin', 'Systeme', 'admin@telemed.ma', 'hash_demo', NULL, 'ADMIN');

INSERT INTO medecin (utilisateur_id, numero_ordre, specialite_id, tarif, biographie)
VALUES (1, 'ORD-MA-1001', 1, 150.00, 'Médecin généraliste, 10 ans d''expérience.'),
       (2, 'ORD-MA-1002', 2, 300.00, 'Cardiologue, suivi des maladies chroniques.');

INSERT INTO patient (utilisateur_id, date_naissance, sexe, adresse, ville)
VALUES (3, '1995-04-12', 'M', '12 rue des Orangers', 'Marrakech'),
       (4, '1988-09-30', 'F', '5 avenue Mohammed V', 'Marrakech');

INSERT INTO dossier_medical (patient_id, groupe_sanguin, antecedents, allergies, traitements_en_cours)
VALUES (3, 'O+', 'Asthme léger dans l''enfance', 'Pénicilline', NULL),
       (4, 'A-', NULL, NULL, 'Levothyroxine 50 µg');

INSERT INTO disponibilite (medecin_id, jour_semaine, heure_debut, heure_fin)
VALUES (1, 1, '09:00', '12:00'),
       (1, 3, '14:00', '17:00'),
       (2, 2, '10:00', '13:00'),
       (2, 4, '10:00', '13:00');

INSERT INTO rendez_vous (patient_id, medecin_id, date_heure, duree_min, motif, statut, lien_visio)
VALUES (3, 1, '2026-11-16 09:00', 20, 'Toux persistante', 'TERMINE', 'https://visio.telemed.ma/r/abc123'),
       (4, 1, '2026-11-16 09:20', 20, 'Renouvellement', 'CONFIRME', 'https://visio.telemed.ma/r/abc124'),
       (3, 2, '2026-11-17 10:00', 30, 'Contrôle tension', 'PLANIFIE', 'https://visio.telemed.ma/r/abc125');

INSERT INTO salle_attente (rendez_vous_id, heure_arrivee, heure_appel, statut)
VALUES (1, '2026-11-16 08:55', '2026-11-16 09:01', 'TERMINE'),
       (2, '2026-11-16 09:15', NULL, 'EN_ATTENTE');

INSERT INTO consultation (rendez_vous_id, dossier_id, debut, fin, diagnostic, compte_rendu)
VALUES (1, 1, '2026-11-16 09:01', '2026-11-16 09:18', 'Bronchite aiguë',
        'Toux productive depuis 5 jours, pas de fièvre.');

INSERT INTO document_medical (dossier_id, consultation_id, type, nom_fichier, chemin)
VALUES (1, 1, 'COMPTE_RENDU', 'cr_2026-11-16.pdf', '/data/documents/1/cr_2026-11-16.pdf');

INSERT INTO medicament (denomination, forme, dosage)
VALUES ('Paracétamol', 'Comprimé', '1 g'),
       ('Amoxicilline', 'Gélule', '500 mg'),
       ('Ambroxol', 'Sirop', '30 mg/5 ml');

INSERT INTO ordonnance (numero, consultation_id, date_emission, date_validite, signature_hash)
VALUES ('ORD-2026-000001', 1, '2026-11-16', '2026-12-16',
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855');

INSERT INTO ligne_ordonnance (ordonnance_id, medicament_id, posologie, duree_jours, quantite, instructions)
VALUES (1, 1, '1 comprimé 3 fois par jour si douleur', 5, 1, 'Ne pas dépasser 3 g par jour'),
       (1, 3, '10 ml 3 fois par jour', 7, 1, 'À prendre pendant les repas');
