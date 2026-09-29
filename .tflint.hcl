# The Snowflake provider has no TFLint ruleset, so this catches generic issues
# only (unused variables, deprecated syntax, unpinned modules). Stated honestly
# in the README instead of oversold.
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}
