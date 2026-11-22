#!/usr/bin/env bash
# Installe le driver JDBC PostgreSQL dans WildFly et crée la datasource
# java:jboss/datasources/TelemedicineDS (utilisée par persistence.xml).
#
# Prérequis : WildFly démarré (bin/standalone.sh) et le conteneur Postgres lancé.
# Usage     : WILDFLY_HOME=~/Documents/servers/wildfly-42.0.0.Final ./wildfly/setup-datasource.sh
set -euo pipefail

: "${WILDFLY_HOME:?Définir WILDFLY_HOME (dossier d'installation de WildFly)}"
PG_VERSION="${PG_VERSION:-42.7.14}"
DB_URL="${DB_URL:-jdbc:postgresql://localhost:5432/telemedicine}"
DB_USER="${DB_USER:-telemedicine}"
DB_PASSWORD="${DB_PASSWORD:-telemedicine}"

JAR="$(mktemp -d)/postgresql-${PG_VERSION}.jar"
echo ">> Téléchargement du driver PostgreSQL ${PG_VERSION}"
curl -fsSL -o "$JAR" "https://repo1.maven.org/maven2/org/postgresql/postgresql/${PG_VERSION}/postgresql-${PG_VERSION}.jar"

echo ">> Configuration de WildFly"
"$WILDFLY_HOME/bin/jboss-cli.sh" --connect <<CLI
module add --name=org.postgresql --resources=${JAR} --dependencies=javax.api,jakarta.transaction.api
/subsystem=datasources/jdbc-driver=postgresql:add(driver-name=postgresql,driver-module-name=org.postgresql,driver-xa-datasource-class-name=org.postgresql.xa.PGXADataSource)
data-source add --name=TelemedicineDS --jndi-name=java:jboss/datasources/TelemedicineDS --driver-name=postgresql --connection-url=${DB_URL} --user-name=${DB_USER} --password=${DB_PASSWORD} --enabled=true
/subsystem=datasources/data-source=TelemedicineDS:test-connection-in-pool
CLI

echo ">> Datasource TelemedicineDS prête."
