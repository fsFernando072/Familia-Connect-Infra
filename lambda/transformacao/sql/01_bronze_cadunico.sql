-- BRONZE | Base 1 (MDS/SAGI) - tabela externa sobre os CSVs crus, particionada por ano.
-- Tudo como string: nenhuma conversao aqui, o tratamento fica na camada silver.
-- Atencao: o OpenCSVSerde mapeia por POSICAO. A ordem abaixo e a do parametro "fl" da URL na Lambda.
CREATE EXTERNAL TABLE IF NOT EXISTS {{database}}.bronze_cadunico (
  codigo_ibge string,
  anomes_s string,
  cadun_qtd_familias_atualizadas_i string,
  cadun_qtd_familias_atualizadas_pobreza_pbf_i string,
  cadun_qtd_familias_atualizadas_baixa_renda_i string,
  cadun_qtd_familias_atualizadas_rfpc_ate_meio_sm_i string,
  cadun_qtd_familias_atualizadas_rfpc_acima_meio_sm_i string,
  cadun_qtd_familias_atualizadas_renda_zero_i string,
  cadun_taxa_atualizacao_cadastral_d string,
  cadun_taxa_atualizacao_cadastral_rfpc_ate_meio_sm_d string
)
PARTITIONED BY (ano int)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.OpenCSVSerde'
WITH SERDEPROPERTIES ('separatorChar' = ',', 'quoteChar' = '"', 'escapeChar' = '\\')
STORED AS TEXTFILE
LOCATION 's3://{{bronze_bucket}}/familias-cadastro-unico/'
TBLPROPERTIES (
  'skip.header.line.count' = '1',
  'projection.enabled' = 'true',
  'projection.ano.type' = 'integer',
  'projection.ano.range' = '2000,2035',
  'storage.location.template' = 's3://{{bronze_bucket}}/familias-cadastro-unico/${ano}/'
);
