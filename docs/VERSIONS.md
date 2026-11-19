# Versions

Resolved 2026-11-19. Constraints are the ones in the version matrix. Lock files record the provider the registry actually served.

| Component | Pinned here | Newer stable seen the same day, not adopted |
|---|---|---|
| Terraform | `>= 1.8.0, < 2.0.0`; CI and `.terraform-version` = `1.17.2` | No `1.17.3`. `1.16.7` exists on the previous minor. |
| `kreuzwerker/docker` | `~> 4.5` | `4.7.0` (allowed by the constraint; the lock file records the resolved build) |
| `hashicorp/local` | `~> 2.5` | `2.9.1` |
| `hashicorp/random` | `~> 3.6` | `3.9.1` |
| TFLint | `v0.65.0` (bundled Terraform ruleset `0.15.0`) | `v0.66.0` |
| Trivy | `v0.76.2` | none (`v0.76.2` is the newest tag) |
| `aquasecurity/trivy-action` | `v0.36.0` at `ed142fd0673e97e23eac54620cfb913e5ce36c25` | none |
| `actions/checkout` | `v7.0.1` at `3d3c42e5aac5ba805825da76410c181273ba90b1` | none in v7 |
| `hashicorp/setup-terraform` | `v4.0.1` at `dfe3c3f87815947d99a8997f908cb6525fc44e9e` | none in v4 (`v4` points at this commit) |
| `terraform-linters/setup-tflint` | `v6.3.2` at `6ffdbaa3be476b3431f7275c26966ef32ff60337` | none (`v6` points at this commit) |
| `actions/setup-python` | `v7.1.0` at `6d4fd22b20465ccc0f7354476588e8df7c9ca0e0` | none in v7 |
| ansible | `~=14.0` (ansible-core 2.21.x) | community package `14.6.0` |
| ansible-lint | `26.11.0` | none in the 26 line |
| `ubuntu` | `24.04` digest `sha256:73b999393d07f2bf65a40373778a44dc9a6d54ad7718d29247d8ff9413c4d6a8` | floating tag not used |
| `postgres` | `17.12` digest `sha256:b60e90042aa6b8dbecd58e224b3e36114dbf8ad754465264c2476ad58a86e45c` | newest 17.x tag on that date |
| `nginx` | `1.30.7` digest `sha256:7fad6c0dff97965adbddf28027d934b111fc0221a554315dc274712f3fba24d3` | stable line on nginx.org. Mainline `1.31.9` is not used. |

Every third-party GitHub Action is pinned to a full commit SHA. `version: latest` is not passed to Trivy.
