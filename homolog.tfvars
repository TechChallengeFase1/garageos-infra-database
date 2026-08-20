# Ambiente de homologacao.
#
# ATENCAO AO CUSTO: o free tier do RDS cobre 750h/mes de UMA instancia
# db.t4g.micro. Com homolog e producao ligados ao mesmo tempo, o total passa de
# 1400h e o excedente e cobrado (~US$ 12/mes). Destrua este ambiente quando nao
# estiver em uso:
#
#   terraform workspace select homolog
#   terraform destroy -var-file=homolog.tfvars

db_instance_class = "db.t4g.micro"
allocated_storage = 20

# Sem backup: ambiente reconstruido do zero sempre que preciso.
backup_retention_days = 0
