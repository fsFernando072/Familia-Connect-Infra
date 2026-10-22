-- Tratamentos aplicados:
--  * Harmoniza os layouts: arquivo de 2 colunas (col4 NULL) -> distrito=col1, total=col2;
--    arquivo de 4 colunas -> distrito=col3, total=col4.
--  * Macrorregiao/subprefeitura ficam de fora: nos CSVs de 4 colunas so a 1a linha do grupo traz o valor
--    e o Athena nao garante a ordem das linhas para preencher as vazias.
--  * Numeros: remove ponto de milhar e lixo (CR/LF, espacos); vazio vira NULL e depois 0.
--  * Nome do distrito padronizado (sem acento, maiusculo, sem espacos duplicados) para permitir
--    juntar anos e bases; o texto original e mantido em distrito_original.
--  * Descarta linhas sem distrito e linhas de total/subtotal; duplicatas (ano + distrito) ficam com o maior total.
INSERT INTO {{database}}.silver_bolsa_sp
WITH harmonizado AS (
  SELECT
    ano,
    regexp_replace(CASE WHEN col4 IS NULL THEN col1 ELSE col3 END, '[\r\n]', '') AS distrito_original,
    regexp_replace(CASE WHEN col4 IS NULL THEN col2 ELSE col4 END, '[^0-9]', '') AS total_txt
  FROM {{database}}.bronze_bolsa_sp
),
limpo AS (
  SELECT
    ano,
    NULLIF(trim(distrito_original), '') AS distrito_original,
    NULLIF(
      trim(regexp_replace(upper(regexp_replace(normalize(trim(distrito_original), NFD), '\p{M}', '')), '\s+', ' ')),
      ''
    ) AS distrito,
    COALESCE(TRY_CAST(NULLIF(total_txt, '') AS bigint), 0) AS total_familias
  FROM harmonizado
),
valido AS (
  SELECT
    distrito,
    distrito_original,
    ano,
    total_familias,
    row_number() OVER (PARTITION BY ano, distrito ORDER BY total_familias DESC) AS rn
  FROM limpo
  WHERE distrito IS NOT NULL
    AND distrito NOT LIKE 'TOTAL%'
    AND distrito NOT LIKE 'SUBTOTAL%'
)
SELECT distrito, distrito_original, ano, total_familias
FROM valido
WHERE rn = 1;
