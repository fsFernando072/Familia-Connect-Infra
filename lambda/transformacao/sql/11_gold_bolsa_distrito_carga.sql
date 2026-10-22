INSERT INTO {{database}}.gold_bolsa_familia_distrito
SELECT
  ano,
  distrito,
  total_familias,
  LAG(total_familias) OVER (PARTITION BY distrito ORDER BY ano) AS total_familias_ano_anterior,
  total_familias - LAG(total_familias) OVER (PARTITION BY distrito ORDER BY ano) AS variacao_absoluta,
  CASE
    WHEN LAG(total_familias) OVER (PARTITION BY distrito ORDER BY ano) > 0
    THEN CAST(total_familias - LAG(total_familias) OVER (PARTITION BY distrito ORDER BY ano) AS double)
         / LAG(total_familias) OVER (PARTITION BY distrito ORDER BY ano) * 100
  END AS variacao_percentual
FROM {{database}}.silver_bolsa_sp;
