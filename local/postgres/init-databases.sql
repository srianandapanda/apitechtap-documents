-- Runs once on first Postgres container startup (docker-entrypoint-initdb.d).
-- One logical server; separate databases per service (local dev only).

CREATE USER authuser WITH PASSWORD 'authpass';
CREATE DATABASE authdb OWNER authuser;
GRANT ALL PRIVILEGES ON DATABASE authdb TO authuser;

CREATE USER ums WITH PASSWORD 'ums';
CREATE DATABASE ums OWNER ums;
GRANT ALL PRIVILEGES ON DATABASE ums TO ums;

CREATE USER assist WITH PASSWORD 'assist';
CREATE DATABASE assist OWNER assist;
GRANT ALL PRIVILEGES ON DATABASE assist TO assist;

CREATE USER planpayment WITH PASSWORD 'planpayment';
CREATE DATABASE planpayment OWNER planpayment;
GRANT ALL PRIVILEGES ON DATABASE planpayment TO planpayment;
