-- GOLD | Visao anual do municipio de Sao Paulo juntando as duas bases:
-- Cadastro Unico (mes de referencia = primeiro mes disponivel do ano, comparavel ao snapshot de janeiro da Prefeitura)
-- x familias no Bolsa Familia somando os distritos.
CREATE TABLE IF NOT EXISTS {{database}}.gold_familias_sp_anual (
  ano int,
  mes_referencia_cadunico int,
  qtd_familias_atualizadas bigint,
  qtd_familias_baixa_renda bigint,
  qtd_familias_renda_zero bigint,
  taxa_atualizacao_cadastral double,
  total_familias_bolsa_sp bigint,
  qtd_distritos_bolsa_sp bigint,
  pct_bolsa_sobre_baixa_renda double
)
LOCATION 's3://{{gold_bucket}}/iceberg/gold_familias_sp_anual/'
TBLPROPERTIES ('table_type' = 'ICEBERG', 'format' = 'parquet');
