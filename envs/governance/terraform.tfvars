# Monthly credit budgets. The trial has roughly 130-200 credits in total; these
# sum well below it. In production these numbers come from a FinOps owner.
monitors = {
  ACCOUNT_MONITOR = { credit_quota = 100 }
  DEV_MONITOR     = { credit_quota = 10 }
  QA_MONITOR      = { credit_quota = 10 }
  PROD_MONITOR    = { credit_quota = 20 }
}

account_monitor = "ACCOUNT_MONITOR"

# Apply order: env stacks first (they create the warehouses), then this stack.
warehouse_monitors = {
  DEV_LOAD_WH = "DEV_MONITOR"
  DEV_BI_WH   = "DEV_MONITOR"
  # QA_LOAD_WH   = "QA_MONITOR"  # enable after the env stack is applied
  # QA_BI_WH     = "QA_MONITOR"  # enable after the env stack is applied
  # PROD_LOAD_WH = "PROD_MONITOR"  # enable after the env stack is applied
  # PROD_BI_WH   = "PROD_MONITOR"  # enable after the env stack is applied
}
