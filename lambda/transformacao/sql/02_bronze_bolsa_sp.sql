-- BRONZE | Base 2 (Prefeitura de SP) - tabela externa sobre os CSVs crus, particionada por ano.
-- O layout muda entre os anos, por isso as colunas sao genericas (posicionais):
--   2020-2021: 2 colunas  -> DISTRITO ; TOTAL
--   2022+    : 4 colunas  -> MACRORREGIAO ; SUBPREFEITURA ; DISTRITO ; TOTAL DE FAMILIAS
-- Arquivos de 2 colunas deixam col3 e col4 NULL. O cabecalho e ignorado (nomes mudam por ano).
-- Os CSVs da Prefeitura vem em ISO-8859-1 (latin1).
CREATE EXTERNAL TABLE IF NOT EXISTS {{database}}.bronze_bolsa_sp (
  col1 string,
  col2 string,
  col3 string,
  col4 string
)
PARTITIONED BY (ano int)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe'
WITH SERDEPROPERTIES ('field.delim' = ';', 'serialization.encoding' = 'ISO-8859-1')
STORED AS TEXTFILE
LOCATION 's3://{{bronze_bucket}}/bolsa-familia-sp/'
TBLPROPERTIES (
  'skip.header.line.count' = '1',
  'projection.enabled' = 'true',
  'projection.ano.type' = 'integer',
  'projection.ano.range' = '2000,2035',
  'storage.location.template' = 's3://{{bronze_bucket}}/bolsa-familia-sp/${ano}/'
);
