variable "frontends" {
  description = "Buckets e respectivas pastas dos front-ends"

  type = map(string)

  default = {
    "app-frontend-vendas"  = "../Desafio 1"
    "app-frontend-admin"   = "../Desafio 2"
    "app-frontend-cliente" = "../Desafio 3"
  }
}