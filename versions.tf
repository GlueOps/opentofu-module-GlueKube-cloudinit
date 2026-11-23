terraform {
  # Pure HCL, no providers. optional() object attributes need 1.3+, `tofu test` 1.6+.
  required_version = ">= 1.6.0"
}
