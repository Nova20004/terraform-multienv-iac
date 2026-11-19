config {
  # Inspect local module sources when a root module calls them.
  call_module_type = "local"
  force            = false
}

# Bundled with TFLint v0.65. The recommended preset is the Terraform language
# ruleset only. Do not add the AWS, Google or Azure rulesets: this repo has
# no cloud provider.
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}
