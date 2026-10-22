-- GOLD | Familias no Bolsa Familia por distrito de SP, com variacao em relacao ao ano anterior.
CREATE TABLE IF NOT EXISTS {{database}}.gold_bolsa_familia_distrito (
  ano int,
  distrito string,
  total_familias bigint,
  total_familias_ano_anterior bigint,
  variacao_absoluta bigint,
  variacao_percentual double
)
LOCATION 's3://{{gold_bucket}}/iceberg/gold_bolsa_familia_distrito/'
TBLPROPERTIES ('table_type' = 'ICEBERG', 'format' = 'parquet');
