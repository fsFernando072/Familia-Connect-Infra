-- SILVER | Base 2 tratada, todos os anos (layouts diferentes) em um unico esquema.
CREATE TABLE IF NOT EXISTS {{database}}.silver_bolsa_sp (
  distrito string,
  distrito_original string,
  ano int,
  total_familias bigint
)
PARTITIONED BY (ano)
LOCATION 's3://{{silver_bucket}}/iceberg/silver_bolsa_sp/'
TBLPROPERTIES ('table_type' = 'ICEBERG', 'format' = 'parquet');
