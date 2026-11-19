# Partial configuration. Nothing environment-specific is stored in this file.
# `make` sets PG_CONN_STR to postgres://.../terraform_state_<env>, which the
# pg backend reads as conn_str. The password is not written next to the config.
terraform {
  backend "pg" {}
}
