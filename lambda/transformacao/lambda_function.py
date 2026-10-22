"""
Lambda: transformação das bases no Athena (bronze -> silver -> gold).

Executa, em ordem alfabética, os arquivos de ./sql (um comando SQL por arquivo, terminado em ';').
Os placeholders {{database}}, {{bronze_bucket}}, {{silver_bucket}} e {{gold_bucket}} são
substituídos pelas variáveis de ambiente.

Variáveis de ambiente:
  ATHENA_DATABASE   banco no Glue Data Catalog
  ATHENA_WORKGROUP  workgroup do Athena (engine v3, necessário para Iceberg)
  BRONZE_BUCKET / SILVER_BUCKET / GOLD_BUCKET

Evento opcional: {"arquivos": ["05_", "08_"]}  -> roda só os arquivos cujo nome começa com os prefixos.
"""
import json
import logging
import os
import re
import time
from pathlib import Path

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

athena = boto3.client("athena")

SQL_DIR = Path(__file__).parent / "sql"
POLL_SEGUNDOS = 3

PLACEHOLDERS = {
    "{{database}}": os.environ.get("ATHENA_DATABASE", ""),
    "{{bronze_bucket}}": os.environ.get("BRONZE_BUCKET", ""),
    "{{silver_bucket}}": os.environ.get("SILVER_BUCKET", ""),
    "{{gold_bucket}}": os.environ.get("GOLD_BUCKET", ""),
}
WORKGROUP = os.environ.get("ATHENA_WORKGROUP", "primary")
DATABASE = os.environ.get("ATHENA_DATABASE", "")


def preparar_sql(texto):
    for chave, valor in PLACEHOLDERS.items():
        texto = texto.replace(chave, valor)
    # remove comentários de linha inteira
    linhas = [l for l in texto.splitlines() if not l.strip().startswith("--")]
    return "\n".join(linhas).strip().rstrip(";").strip()


def executar(sql, nome):
    qid = athena.start_query_execution(
        QueryString=sql,
        QueryExecutionContext={"Database": DATABASE},
        WorkGroup=WORKGROUP,
    )["QueryExecutionId"]
    logger.info("[%s] iniciado (%s)", nome, qid)

    while True:
        estado = athena.get_query_execution(QueryExecutionId=qid)["QueryExecution"]["Status"]
        if estado["State"] in ("SUCCEEDED", "FAILED", "CANCELLED"):
            break
        time.sleep(POLL_SEGUNDOS)

    if estado["State"] != "SUCCEEDED":
        motivo = estado.get("StateChangeReason", "sem detalhes")
        raise RuntimeError(f"{nome} {estado['State']}: {motivo}")
    logger.info("[%s] concluído", nome)
    return qid


def lambda_handler(event, context):
    faltando = [k for k, v in {**PLACEHOLDERS, "workgroup": WORKGROUP}.items() if not v]
    if faltando or not DATABASE:
        raise ValueError(f"Variáveis de ambiente ausentes: {faltando}")

    prefixos = (event or {}).get("arquivos")
    arquivos = sorted(SQL_DIR.glob("*.sql"))
    if prefixos:
        arquivos = [a for a in arquivos if any(a.name.startswith(p) for p in prefixos)]

    executados = []
    for arq in arquivos:
        sql = preparar_sql(arq.read_text(encoding="utf-8"))
        if not sql:
            continue
        # Falhou? A exceção interrompe a cadeia: não carrega silver/gold sobre dado incompleto.
        executar(sql, arq.name)
        executados.append(arq.name)

    resumo = {"executados": executados}
    logger.info("Resumo: %s", json.dumps(resumo))
    return {"statusCode": 200, "body": resumo}
