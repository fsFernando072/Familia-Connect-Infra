"""
AWS Glue (PySpark) - bronze -> silver

Le os CSVs crus do bucket bronze, trata nulos/tipos, junta os anos de cada base
e grava Parquet no bucket silver:

  s3://familia-connect-silver-g02/cadunico/ano=AAAA/...     (Base 1 - familias-cadastro-unico, MDS/SAGI)
  s3://familia-connect-silver-g02/bolsa-familia-sp/ano=AAAA/... (Base 2 - bolsa-familia-sp, Prefeitura de SP)

Parametros: --BRONZE_BUCKET  --SILVER_BUCKET  (definidos em modules/glue/main.tf)
"""

import codecs
import re
import sys
import unicodedata
import boto3

from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql import Window
from pyspark.sql import functions as F
from pyspark.sql.types import StringType

OPCIONAIS = ["CRAWLER_NAME"] if "--CRAWLER_NAME" in sys.argv else []
args = getResolvedOptions(sys.argv, ["JOB_NAME", "BRONZE_BUCKET", "SILVER_BUCKET"] + OPCIONAIS)
CRAWLER_NAME = args.get("CRAWLER_NAME")
BRONZE = args["BRONZE_BUCKET"]
SILVER = args["SILVER_BUCKET"]

sc = SparkContext()
glue = GlueContext(sc)
spark = glue.spark_session
spark.conf.set("spark.sql.sources.partitionOverwriteMode", "dynamic")
job = Job(glue)
job.init(args["JOB_NAME"], args)

s3 = boto3.client("s3")
NULOS = ["", "null", "none", "nan", "n/a", "na", "-"]


# ---------------------------------------------------------------------------
# Funcoes de limpeza
# ---------------------------------------------------------------------------
def texto_ou_nulo(c):
    """trim; vazio / 'null' / 'NaN' ... viram NULL."""
    t = F.trim(c.cast("string"))
    return F.when(F.lower(t).isin(NULOS), F.lit(None)).otherwise(t)


def inteiro(c):
    """Mantem so digitos (remove ponto de milhar, CR/LF, espacos). Vazio -> NULL."""
    d = F.regexp_replace(c.cast("string"), "[^0-9]", "")
    return F.when(d == "", F.lit(None)).otherwise(d.cast("long"))


def decimal(c):
    """Troca virgula por ponto; invalido/vazio -> NULL."""
    t = texto_ou_nulo(F.regexp_replace(c.cast("string"), ",", "."))
    return t.cast("double")


@F.udf(StringType())
def normalizar_nome(s):
    """Maiusculo, sem acento, sem espacos duplicados."""
    if s is None:
        return None
    s = unicodedata.normalize("NFD", s)
    s = "".join(ch for ch in s if unicodedata.category(ch) != "Mn")
    s = re.sub(r"\s+", " ", s).strip().upper()
    return s or None


# ---------------------------------------------------------------------------
# Base 1 - familias-cadastro-unico (CSV com cabecalho; leitura por NOME de coluna)
# ---------------------------------------------------------------------------
def processar_cadunico():
    df = (
        spark.read.option("header", True)
        .option("encoding", "UTF-8")
        .csv(f"s3://{BRONZE}/familias-cadastro-unico/*/*.csv")
        .withColumn("arquivo", F.input_file_name())
    )

    print(f"[cadunico] colunas lidas do CSV: {df.columns}")

    # colunas ausentes em algum ano entram como NULL
    esperadas = [
        "codigo_ibge", "anomes_s",
        "cadun_qtd_familias_atualizadas_i",
        "cadun_qtd_familias_atualizadas_pobreza_pbf_i",
        "cadun_qtd_familias_atualizadas_baixa_renda_i",
        "cadun_qtd_familias_atualizadas_rfpc_ate_meio_sm_i",
        "cadun_qtd_familias_atualizadas_rfpc_acima_meio_sm_i",
        "cadun_qtd_familias_atualizadas_renda_zero_i",
        "cadun_taxa_atualizacao_cadastral_d",
        "cadun_taxa_atualizacao_cadastral_rfpc_ate_meio_sm_d",
    ]
    for c in esperadas:
        if c not in df.columns:
            df = df.withColumn(c, F.lit(None).cast("string"))

    anomes = F.regexp_replace(F.col("anomes_s"), "[^0-9]", "")
    contagens = {
        "qtd_familias_atualizadas": "cadun_qtd_familias_atualizadas_i",
        "qtd_familias_pobreza_pbf": "cadun_qtd_familias_atualizadas_pobreza_pbf_i",
        "qtd_familias_baixa_renda": "cadun_qtd_familias_atualizadas_baixa_renda_i",
        "qtd_familias_rfpc_ate_meio_sm": "cadun_qtd_familias_atualizadas_rfpc_ate_meio_sm_i",
        "qtd_familias_rfpc_acima_meio_sm": "cadun_qtd_familias_atualizadas_rfpc_acima_meio_sm_i",
        "qtd_familias_renda_zero": "cadun_qtd_familias_atualizadas_renda_zero_i",
    }
    taxas = {
        "taxa_atualizacao_cadastral": "cadun_taxa_atualizacao_cadastral_d",
        "taxa_atualizacao_cadastral_rfpc_ate_meio_sm": "cadun_taxa_atualizacao_cadastral_rfpc_ate_meio_sm_d",
    }

    df = df.select(
        F.regexp_replace(F.col("codigo_ibge"), "[^0-9]", "").alias("codigo_ibge"),
        anomes.substr(1, 4).cast("int").alias("ano"),
        anomes.substr(5, 2).cast("int").alias("mes"),
        *[inteiro(F.col(orig)).alias(novo) for novo, orig in contagens.items()],
        *[decimal(F.col(orig)).alias(novo) for novo, orig in taxas.items()],
        "arquivo",
    )

    print(f"[cadunico] linhas antes do filtro: {df.count()}")
    df.show(5, truncate=False)

    # descarta registros invalidos
    df = df.filter(
        (F.col("codigo_ibge") != "")
        & F.col("codigo_ibge").isNotNull()
        & F.col("ano").between(2000, 2100)
        & F.col("mes").between(1, 12)
    )

    # contagens nulas -> 0 (taxas continuam NULL)
    df = df.fillna(0, subset=list(contagens.keys()))

    # duplicatas: 1 registro por municipio/mes
    w = Window.partitionBy("codigo_ibge", "ano", "mes").orderBy(F.col("arquivo").desc())
    df = (
        df.withColumn("rn", F.row_number().over(w))
        .filter("rn = 1")
        .drop("rn", "arquivo")
        .withColumn(
            "ano_mes",
            F.to_date(F.concat_ws("-", F.col("ano"), F.lpad(F.col("mes").cast("string"), 2, "0"), F.lit("01"))),
        )
    )

    total = df.count()
    if total == 0:
        raise RuntimeError(
            "[cadunico] 0 linhas apos o tratamento: nada foi gravado. "
            "Veja 'colunas lidas do CSV' e a amostra acima (separador/nomes de coluna/formato de anomes_s)."
        )
    (
        df.repartition("ano")
        .write.mode("overwrite")
        .partitionBy("ano")
        .parquet(f"s3://{SILVER}/cadunico/")
    )
    print(f"[cadunico] {total} linhas gravadas em s3://{SILVER}/cadunico/")

# ---------------------------------------------------------------------------
# Base 2 - bolsa-familia-sp (layout muda por ano; encoding/separador detectados)
# ---------------------------------------------------------------------------
def listar_anos_e_arquivos():
    """{ano: [chaves .csv]} em bolsa-familia-sp/{ano}/"""
    resultado = {}
    pag = s3.get_paginator("list_objects_v2")
    for page in pag.paginate(Bucket=BRONZE, Prefix="bolsa-familia-sp/"):
        for obj in page.get("Contents", []):
            m = re.match(r"bolsa-familia-sp/(\d{4})/.+\.csv$", obj["Key"], re.I)
            if m:
                resultado.setdefault(int(m.group(1)), []).append(obj["Key"])
    return resultado


def detectar_formato(chave):
    amostra = s3.get_object(Bucket=BRONZE, Key=chave, Range="bytes=0-20000")["Body"].read()
    try:
        # decoder incremental: um caractere multibyte cortado no fim da amostra nao conta como erro
        codecs.getincrementaldecoder("utf-8")().decode(amostra, final=False)
        encoding = "UTF-8"
    except UnicodeDecodeError:
        encoding = "ISO-8859-1"
    primeira = amostra.split(b"\n", 1)[0]
    sep = ";" if primeira.count(b";") >= primeira.count(b",") else ","
    return encoding, sep


def processar_bolsa_sp():
    partes = []
    for ano, chaves in sorted(listar_anos_e_arquivos().items()):
        for chave in chaves:
            encoding, sep = detectar_formato(chave)
            df = (
                spark.read.option("header", True)
                .option("sep", sep)
                .option("encoding", encoding)
                .csv(f"s3://{BRONZE}/{chave}")
            )
            cols = df.columns
            # 2 colunas: DISTRITO;TOTAL  |  4 colunas: MACRORREGIAO;SUBPREFEITURA;DISTRITO;TOTAL
            if len(cols) >= 4:
                i_dist, i_tot = 2, 3
            elif len(cols) >= 2:
                i_dist, i_tot = 0, 1
            else:
                print(f"[bolsa-sp] {chave}: layout inesperado {cols}, ignorado")
                continue
            partes.append(
                df.select(
                    F.col(f"`{cols[i_dist]}`").alias("distrito_original"),
                    F.col(f"`{cols[i_tot]}`").alias("total_txt"),
                ).withColumn("ano", F.lit(ano))
            )
            print(f"[bolsa-sp] {chave}: {cols} (enc={encoding}, sep='{sep}')")

    if not partes:
        print("[bolsa-sp] nenhum arquivo encontrado")
        return

    df = partes[0]
    for p in partes[1:]:
        df = df.unionByName(p)

    df = df.select(
        "ano",
        texto_ou_nulo(F.regexp_replace(F.col("distrito_original"), "[\r\n]", "")).alias("distrito_original"),
        inteiro(F.col("total_txt")).alias("total_familias"),
    )
    df = df.withColumn("distrito", normalizar_nome(F.col("distrito_original")))

    df = df.filter(
        F.col("distrito").isNotNull()
        & ~F.col("distrito").startswith("TOTAL")
        & ~F.col("distrito").startswith("SUBTOTAL")
    ).fillna(0, subset=["total_familias"])

    w = Window.partitionBy("ano", "distrito").orderBy(F.col("total_familias").desc())
    df = (
        df.withColumn("rn", F.row_number().over(w))
        .filter("rn = 1")
        .select("distrito", "distrito_original", "total_familias", "ano")
    )

    total = df.count()
    if total == 0:
        raise RuntimeError("[bolsa-sp] 0 linhas apos o tratamento: nada foi gravado.")
    (
        df.repartition("ano")
        .write.mode("overwrite")
        .partitionBy("ano")
        .parquet(f"s3://{SILVER}/bolsa-familia-sp/")
    )
    print(f"[bolsa-sp] {total} linhas gravadas em s3://{SILVER}/bolsa-familia-sp/")

def limpar_marcadores_folder():
    """Remove os objetos vazios '*_$folder$' que o conector S3 do Hadoop/EMRFS cria
    ao gravar (ex: cadunico_$folder$). Sao so marcadores de 'pasta', sem dados."""
    chaves = []
    for pagina in s3.get_paginator("list_objects_v2").paginate(Bucket=SILVER):
        chaves += [o["Key"] for o in pagina.get("Contents", []) if o["Key"].endswith("_$folder$")]
    for i in range(0, len(chaves), 1000):
        s3.delete_objects(
            Bucket=SILVER,
            Delete={"Objects": [{"Key": k} for k in chaves[i:i + 1000]], "Quiet": True},
        )
    print(f"[limpeza] {len(chaves)} marcadores _$folder$ removidos de s3://{SILVER}/")


def tem_csv_no_bronze(prefixo):
    """True se existir ao menos um .csv sob s3://BRONZE/prefixo (evita ler 'pasta' inexistente)."""
    for page in s3.get_paginator("list_objects_v2").paginate(Bucket=BRONZE, Prefix=prefixo):
        if any(o["Key"].lower().endswith(".csv") for o in page.get("Contents", [])):
            return True
    return False


resumo = {}

if tem_csv_no_bronze("familias-cadastro-unico/"):
    processar_cadunico()
    resumo["cadunico"] = "processado"
else:
    print("[cadunico] AVISO: nenhum CSV em bronze/familias-cadastro-unico/ - base pulada")
    resumo["cadunico"] = "pulado (sem arquivos no bronze)"

if tem_csv_no_bronze("bolsa-familia-sp/"):
    processar_bolsa_sp()
    resumo["bolsa-familia-sp"] = "processado"
else:
    print("[bolsa-sp] AVISO: nenhum CSV em bronze/bolsa-familia-sp/ - base pulada")
    resumo["bolsa-familia-sp"] = "pulado (sem arquivos no bronze)"

limpar_marcadores_folder()
print(f"[resumo] {resumo}")

if all(v.startswith("pulado") for v in resumo.values()):
    raise RuntimeError("Nenhuma base tinha arquivos no bronze: nada foi processado.")


def iniciar_crawler():
    """Cataloga o silver no Data Catalog. Nao derruba o job se falhar."""
    if not CRAWLER_NAME:
        return
    cliente = boto3.client("glue")
    try:
        cliente.start_crawler(Name=CRAWLER_NAME)
        print(f"[crawler] {CRAWLER_NAME} iniciado")
    except cliente.exceptions.CrawlerRunningException:
        print(f"[crawler] {CRAWLER_NAME} ja esta em execucao")
    except Exception as e:
        print(f"[crawler] AVISO: nao foi possivel iniciar {CRAWLER_NAME}: {e}")


iniciar_crawler()

job.commit()