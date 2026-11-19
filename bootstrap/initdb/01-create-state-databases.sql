-- Runs once, when the state volume is empty. The official Postgres image
-- executes every file in /docker-entrypoint-initdb.d as the POSTGRES_USER.
-- One database per environment keeps advisory locks from crossing dev,
-- staging and prod. Database names match Makefile: terraform_state_<env>.
CREATE DATABASE terraform_state_dev;
CREATE DATABASE terraform_state_staging;
CREATE DATABASE terraform_state_prod;
