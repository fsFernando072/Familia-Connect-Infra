-- SILVER | Base 1 tratada, todos os anos em uma unica tabela Iceberg (Parquet).
CREATE TABLE IF NOT EXISTS {{database}}.silver_cadunico (
  codigo_ibge string,
  ano int,
  mes int,
  ano_mes date,
  qtd_familias_atualizadas bigint,
  qtd_familias_pobreza_pbf bigint,
  qtd_familias_baixa_renda bigint,
  qtd_familias_rfpc_ate_meio_sm bigint,
  qtd_familias_rfpc_acima_meio_sm bigint,
  qtd_familias_renda_zero bigint,
  taxa_atualizacao_cadastral double,
  taxa_atualizacao_cadastral_rfpc_ate_meio_sm double
)
PARTITIONED BY (ano)
LOCATION 's3://{{silver_bucket}}/iceberg/silver_cadunico/'
TBLPROPERTIES ('table_type' = 'ICEBERG', 'format' = 'parquet');
