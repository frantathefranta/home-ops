resource "akeyless_static_secret" "item" {
  path = var.name
  value = jsonencode({
    AWS_ACCESS_KEY_ID = var.username
    AWS_SECRET_ACCESS_KEY = var.password
  })
  # username = var.username
  # password = var.password

  # section {
  #   label = "Token for ${var.name}"
  #   field {
  #     label = "AWS_ACCESS_KEY_ID"
  #     type  = "STRING"
  #     value = var.username
  #   }
  #   field {
  #     label = "AWS_SECRET_ACCESS_KEY"
  #     type  = "CONCEALED"
  #     value = var.password
  #   }
  # }
}
