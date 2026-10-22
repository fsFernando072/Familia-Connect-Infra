-- Sao Paulo capital = 3550308 (IBGE, 7 digitos) ou 355030 (6 digitos), conforme a base.
INSERT INTO {{database}}.gold_familias_sp_anual
WITH cad AS (
  SELECT
    ano,
    mes,
    qtd_familias_atualizadas,
    qtd_familias_baixa_renda,
    qtd_familias_renda_zero,
    taxa_atualizacao_cadastral,
    row_number() OVER (PARTITION BY ano ORDER BY mes ASC) AS rn
  FROM {{database}}.silver_cadunico
  WHERE codigo_ibge IN ('3550308', '355030')
),
bolsa AS (
  SELECT ano, SUM(total_familias) AS total_familias, COUNT(*) AS qtd_distritos
  FROM {{database}}.silver_bolsa_sp
  GROUP BY ano
)
SELECT
  COALESCE(c.ano, b.ano) AS ano,
  c.mes AS mes_referencia_cadunico,
  c.qtd_familias_atualizadas,
  c.qtd_familias_baixa_renda,
  c.qtd_familias_renda_zero,
  c.taxa_atualizacao_cadastral,
  b.total_familias AS total_familias_bolsa_sp,
  b.qtd_distritos AS qtd_distritos_bolsa_sp,
  CASE WHEN c.qtd_familias_baixa_renda > 0
       THEN CAST(b.total_familias AS double) / c.qtd_familias_baixa_renda * 100
  END AS pct_bolsa_sobre_baixa_renda
FROM (SELECT * FROM cad WHERE rn = 1) c
FULL OUTER JOIN bolsa b ON c.ano = b.ano;
