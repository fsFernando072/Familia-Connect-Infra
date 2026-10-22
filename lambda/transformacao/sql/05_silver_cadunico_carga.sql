-- Tratamentos aplicados:
--  * Une todos os anos (particoes ano=2020, 2021, ...) da bronze.
--  * Texto vazio / espacos / "null" / "NaN" viram NULL; so digitos sao aceitos nos inteiros.
--  * Contagens nulas viram 0 (campo ausente no Solr = nenhuma familia na faixa).
--  * Taxas nulas continuam NULL (0 distorceria medias); virgula decimal vira ponto.
--  * anomes_s (ex.: 202301 ou 2023-01) vira ano, mes e ano_mes (date); mes invalido descarta a linha.
--  * Linhas sem codigo_ibge sao descartadas; duplicatas (codigo_ibge + ano_mes) ficam com 1 registro.
INSERT INTO {{database}}.silver_cadunico
WITH limpo AS (
  SELECT
    NULLIF(regexp_replace(codigo_ibge, '[^0-9]', ''), '') AS codigo_ibge,
    regexp_replace(anomes_s, '[^0-9]', '') AS anomes,
    NULLIF(regexp_replace(cadun_qtd_familias_atualizadas_i, '[^0-9]', ''), '') AS q_atual,
    NULLIF(regexp_replace(cadun_qtd_familias_atualizadas_pobreza_pbf_i, '[^0-9]', ''), '') AS q_pobreza,
    NULLIF(regexp_replace(cadun_qtd_familias_atualizadas_baixa_renda_i, '[^0-9]', ''), '') AS q_baixa,
    NULLIF(regexp_replace(cadun_qtd_familias_atualizadas_rfpc_ate_meio_sm_i, '[^0-9]', ''), '') AS q_ate_meio,
    NULLIF(regexp_replace(cadun_qtd_familias_atualizadas_rfpc_acima_meio_sm_i, '[^0-9]', ''), '') AS q_acima_meio,
    NULLIF(regexp_replace(cadun_qtd_familias_atualizadas_renda_zero_i, '[^0-9]', ''), '') AS q_zero,
    replace(trim(cadun_taxa_atualizacao_cadastral_d), ',', '.') AS t_atual,
    replace(trim(cadun_taxa_atualizacao_cadastral_rfpc_ate_meio_sm_d), ',', '.') AS t_ate_meio,
    "$path" AS arquivo
  FROM {{database}}.bronze_cadunico
),
tipado AS (
  SELECT
    codigo_ibge,
    TRY_CAST(substr(anomes, 1, 4) AS integer) AS ano,
    TRY_CAST(substr(anomes, 5, 2) AS integer) AS mes,
    COALESCE(TRY_CAST(q_atual AS bigint), 0) AS qtd_familias_atualizadas,
    COALESCE(TRY_CAST(q_pobreza AS bigint), 0) AS qtd_familias_pobreza_pbf,
    COALESCE(TRY_CAST(q_baixa AS bigint), 0) AS qtd_familias_baixa_renda,
    COALESCE(TRY_CAST(q_ate_meio AS bigint), 0) AS qtd_familias_rfpc_ate_meio_sm,
    COALESCE(TRY_CAST(q_acima_meio AS bigint), 0) AS qtd_familias_rfpc_acima_meio_sm,
    COALESCE(TRY_CAST(q_zero AS bigint), 0) AS qtd_familias_renda_zero,
    TRY_CAST(CASE WHEN lower(t_atual) IN ('', 'null', 'nan') THEN NULL ELSE t_atual END AS double) AS taxa_atualizacao_cadastral,
    TRY_CAST(CASE WHEN lower(t_ate_meio) IN ('', 'null', 'nan') THEN NULL ELSE t_ate_meio END AS double) AS taxa_atualizacao_cadastral_rfpc_ate_meio_sm,
    arquivo
  FROM limpo
),
valido AS (
  SELECT *,
    row_number() OVER (PARTITION BY codigo_ibge, ano, mes ORDER BY arquivo DESC) AS rn
  FROM tipado
  WHERE codigo_ibge IS NOT NULL
    AND ano BETWEEN 2000 AND 2100
    AND mes BETWEEN 1 AND 12
)
SELECT
  codigo_ibge,
  ano,
  mes,
  CAST(concat(CAST(ano AS varchar), '-', lpad(CAST(mes AS varchar), 2, '0'), '-01') AS date) AS ano_mes,
  qtd_familias_atualizadas,
  qtd_familias_pobreza_pbf,
  qtd_familias_baixa_renda,
  qtd_familias_rfpc_ate_meio_sm,
  qtd_familias_rfpc_acima_meio_sm,
  qtd_familias_renda_zero,
  taxa_atualizacao_cadastral,
  taxa_atualizacao_cadastral_rfpc_ate_meio_sm
FROM valido
WHERE rn = 1;
