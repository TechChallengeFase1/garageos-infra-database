# Ambiente de producao (branch main).
#
# "Producao" aqui e o ambiente da entrega e da demonstracao. As escolhas abaixo
# sao de projeto academico com orcamento limitado, nao de producao real - as
# diferencas estao registradas no README como decisoes conscientes.

db_instance_class = "db.t4g.micro"
allocated_storage = 20

# 1 dia de retencao. Suficiente para recuperar um erro do mesmo dia sem custo
# relevante de snapshot. Producao real usaria 7 a 30 dias, com Multi-AZ.
backup_retention_days = 1
