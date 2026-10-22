"""Glue ETL — logs bronze (JSON.gz) -> silver (Parquet).

Lê um dia inteiro (dt=AAAA-MM-DD) do bronze, tipa e enriquece os campos e grava
Parquet particionado por category/source/dt. Idempotente: reexecutar o mesmo dia
sobrescreve apenas as partições desse dia (partitionOverwriteMode=dynamic).

Argumentos: --bronze_bucket --silver_bucket [--process_date AAAA-MM-DD | YESTERDAY]
"""
import sys
from datetime import datetime, timedelta, timezone

from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql import functions as F
from pyspark.sql.types import IntegerType, LongType, StringType, StructField, StructType
from pyspark.sql.utils import AnalysisException

args = getResolvedOptions(sys.argv, ["JOB_NAME", "bronze_bucket", "silver_bucket", "process_date"])

sc = SparkContext()
glue = GlueContext(sc)
spark = glue.spark_session
spark.conf.set("spark.sql.sources.partitionOverwriteMode", "dynamic")
# mantém dt como string (não vira date)
spark.conf.set("spark.sql.sources.partitionColumnTypeInference.enabled", "false")
job = Job(glue)
job.init(args["JOB_NAME"], args)

process_date = args["process_date"]
if process_date.upper() == "YESTERDAY":
    process_date = (datetime.now(timezone.utc) - timedelta(days=1)).strftime("%Y-%m-%d")
else:
    datetime.strptime(process_date, "%Y-%m-%d")  # valida o formato

bronze_base = "s3://{}/logs/".format(args["bronze_bucket"])
bronze_src = "{}category=*/source=*/dt={}/".format(bronze_base, process_date)
silver_path = "s3://{}/silver_logs/".format(args["silver_bucket"])


def S(name):
    return StructField(name, StringType(), True)


# category / source / dt vêm do caminho (partições), não do corpo do JSON
schema = StructType([
    S("ts"), S("host"), S("role"), S("service"), S("task"), S("stream"),
    S("message"), S("container_id"), S("program"), S("pid"), S("unit"), S("priority"),
    S("client_ip"), S("remote_user"), S("nginx_time"), S("method"), S("path"),
    StructField("status", IntegerType(), True), StructField("bytes", LongType(), True),
    S("referer"), S("user_agent"),
])


def read_bronze():
    """DataFrame do dia ou None se não houver nenhum arquivo."""
    print("Processando", bronze_src)
    try:
        df = (spark.read.option("basePath", bronze_base).option("mode", "DROPMALFORMED")
              .schema(schema).json(bronze_src))
        df.head(1)  # força a resolução do caminho
        return df
    except AnalysisException as exc:
        if "Path does not exist" in str(exc):
            return None
        raise


def transform(df):
    msg = F.col("message")

    level_app = F.regexp_extract(msg, r"\b(TRACE|DEBUG|INFO|WARN|ERROR|FATAL)\b", 1)
    level_brk = F.upper(F.regexp_extract(msg, r"\[(emerg|alert|crit|error|warn|warning|notice|info|debug)\]", 1))
    level = (
        F.when(F.col("status") >= 500, "ERROR")
        .when(F.col("status") >= 400, "WARN")
        .when(F.col("status").isNotNull(), "INFO")
        .when(level_app != "", level_app)
        .when(level_brk == "WARNING", "WARN")
        .when(level_brk.isin("EMERG", "ALERT", "CRIT"), "FATAL")
        .when(level_brk != "", level_brk)
    )

    auth_event = (
        F.when(F.col("source") != "auth", F.lit(None).cast("string"))
        .when(msg.rlike(r"Failed password|Invalid user|authentication failure|Disconnected from (invalid|authenticating) user"), "ssh_failed")
        .when(msg.rlike(r"Accepted (publickey|password)"), "ssh_accepted")
        .when(msg.rlike(r"sudo:.*COMMAND="), "sudo_command")
    )

    auth_ip = F.regexp_extract(msg, r"from (\d{1,3}(?:\.\d{1,3}){3})", 1)
    src_ip = F.coalesce(
        F.col("client_ip"),
        F.when((F.col("source") == "auth") & (auth_ip != ""), auth_ip),
    )

    return (
        df.withColumn("event_ts", F.to_timestamp(F.col("ts")))
        .withColumn("level", level)
        .withColumn("auth_event", auth_event)
        .withColumn("src_ip", src_ip)
        .drop("ts", "nginx_time", "client_ip")
    )


bronze_df = read_bronze()
if bronze_df is None:
    print("Nenhum log em {}; nada a fazer.".format(bronze_src))
else:
    (transform(bronze_df).write.mode("overwrite")
     .option("compression", "snappy")
     .partitionBy("category", "source", "dt")
     .parquet(silver_path))
    print("Silver atualizado em", silver_path, "dt=" + process_date)

job.commit()
