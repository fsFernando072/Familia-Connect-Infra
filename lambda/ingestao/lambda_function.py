"""
Lambda: baixa duas bases (CSV) por ano e salva no S3.

Base 1 - familias-cadastro-unico (API MDS/SAGI, ano na URL)
Base 2 - bolsa-familia-sp (scraping da página da Prefeitura de SP)

Variáveis de ambiente:
  BUCKET_NAME   (obrigatória) nome do bucket de destino
  ANO_INICIAL   (opcional, padrão 2020)
  ANO_FINAL     (opcional, padrão 2026)
  PAGINA_SP_URL (opcional) página com a tabela de anos/links da base 2

Só usa bibliotecas padrão + boto3 (já incluso no runtime da Lambda).
Runtime sugerido: Python 3.12 | Timeout: 15 min | Memória: 512 MB+
"""
import json
import logging
import os
import urllib.request
from html.parser import HTMLParser
from urllib.parse import urljoin
from datetime import datetime

import boto3

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")

BUCKET_NAME = os.environ.get("BUCKET_NAME", "")
ANO_INICIAL = int(os.environ.get("ANO_INICIAL", "2020"))
ANO_FINAL = int(os.environ.get("ANO_FINAL") or datetime.now().year)

PAGINA_SP_URL = os.environ.get(
    "PAGINA_SP_URL",
    "https://prefeitura.sp.gov.br/web/assistencia_social/w/"
    "observatorio_socioassistencial/georreferenciamento/327045",
)

# Base 1: o filtro de ano fica no final da URL (fq=anomes_s:ANO*)
URL_BASE1 = (
    "https://aplicacoes.mds.gov.br/sagi/servicos/misocial/"
    "?fl=codigo_ibge%2Canomes_s%20cadun_qtd_familias_atualizadas_i"
    "%20cadun_qtd_familias_atualizadas_pobreza_pbf_i"
    "%20cadun_qtd_familias_atualizadas_baixa_renda_i"
    "%20cadun_qtd_familias_atualizadas_rfpc_ate_meio_sm_i"
    "%20cadun_qtd_familias_atualizadas_rfpc_acima_meio_sm_i"
    "%20cadun_qtd_familias_atualizadas_renda_zero_i"
    "%20cadun_taxa_atualizacao_cadastral_d"
    "%20cadun_taxa_atualizacao_cadastral_rfpc_ate_meio_sm_d"
    "&fq=cadun_qtd_familias_cadastradas_i%3A*"
    "&q=*%3A*&rows=100000"
    "&sort=anomes_s%20desc%2C%20codigo_ibge%20asc"
    "&wt=csv&fq=anomes_s:{ano}*"
)

HEADERS = {"User-Agent": "Mozilla/5.0 (compatible; lambda-ingestao/1.0)"}
TIMEOUT = 120


# ----------------------------------------------------------------------------
# Utilitários
# ----------------------------------------------------------------------------
def abrir(url):
    req = urllib.request.Request(url, headers=HEADERS)
    return urllib.request.urlopen(req, timeout=TIMEOUT)


def baixar_bytes(url):
    with abrir(url) as resp:
        return resp.read()


def salvar_s3(conteudo, chave):
    s3.put_object(
        Bucket=BUCKET_NAME,
        Key=chave,
        Body=conteudo,
        ContentType="text/csv",
    )
    logger.info("Salvo s3://%s/%s (%d bytes)", BUCKET_NAME, chave, len(conteudo))


def csv_tem_dados(conteudo):
    """True se houver pelo menos cabeçalho + 1 linha de dados."""
    linhas = [l for l in conteudo.splitlines() if l.strip()]
    return len(linhas) > 1


# ----------------------------------------------------------------------------
# Base 1 - familias-cadastro-unico
# ----------------------------------------------------------------------------
def processar_base1(anos):
    resultado = {"ok": [], "vazio": [], "erro": {}}
    for ano in anos:
        try:
            conteudo = baixar_bytes(URL_BASE1.format(ano=ano))
            if not csv_tem_dados(conteudo):
                logger.warning("Base 1 sem dados para %s", ano)
                resultado["vazio"].append(ano)
                continue
            chave = f"familias-cadastro-unico/{ano}/familias-cadastro-unico-{ano}.csv"
            salvar_s3(conteudo, chave)
            resultado["ok"].append(ano)
        except Exception as e:  # noqa: BLE001
            logger.exception("Erro na base 1, ano %s", ano)
            resultado["erro"][ano] = str(e)
    return resultado


# ----------------------------------------------------------------------------
# Base 2 - bolsa-familia-sp (scraping)
# ----------------------------------------------------------------------------
class TabelaParser(HTMLParser):
    """Extrai as tabelas da página como lista de linhas.
    Cada célula vira {"texto": str, "links": [href, ...]}."""

    def __init__(self):
        super().__init__()
        self.tabelas = []
        self._tabela = None
        self._linha = None
        self._celula = None

    def handle_starttag(self, tag, attrs):
        if tag == "table":
            self._tabela = []
        elif tag == "tr" and self._tabela is not None:
            self._linha = []
        elif tag in ("td", "th") and self._linha is not None:
            self._celula = {"texto": "", "links": []}
        elif tag == "a" and self._celula is not None:
            href = dict(attrs).get("href")
            if href:
                self._celula["links"].append(href)

    def handle_data(self, data):
        if self._celula is not None:
            self._celula["texto"] += data

    def handle_endtag(self, tag):
        if tag in ("td", "th") and self._celula is not None:
            self._celula["texto"] = self._celula["texto"].strip()
            self._linha.append(self._celula)
            self._celula = None
        elif tag == "tr" and self._linha is not None:
            if self._linha:
                self._tabela.append(self._linha)
            self._linha = None
        elif tag == "table" and self._tabela is not None:
            self.tabelas.append(self._tabela)
            self._tabela = None


def descobrir_links_base2():
    """Retorna {ano: url_do_csv} lendo a tabela da página."""
    html = baixar_bytes(PAGINA_SP_URL).decode("utf-8", errors="replace")
    parser = TabelaParser()
    parser.feed(html)

    links = {}
    for tabela in parser.tabelas:
        if not tabela:
            continue
        cabecalho = [c["texto"].strip().upper() for c in tabela[0]]
        if "CSV" not in cabecalho or "ANO" not in cabecalho:
            continue
        idx_ano = cabecalho.index("ANO")
        idx_csv = cabecalho.index("CSV")

        for linha in tabela[1:]:
            if len(linha) <= max(idx_ano, idx_csv):
                continue
            texto_ano = linha[idx_ano]["texto"].strip()
            hrefs = linha[idx_csv]["links"]
            if texto_ano.isdigit() and hrefs:
                links[int(texto_ano)] = urljoin(PAGINA_SP_URL, hrefs[0])
    return links


def processar_base2(anos):
    resultado = {"ok": [], "vazio": [], "sem_link": [], "erro": {}}
    try:
        links = descobrir_links_base2()
    except Exception as e:  # noqa: BLE001
        logger.exception("Erro ao ler a página da base 2")
        resultado["erro"]["pagina"] = str(e)
        return resultado

    logger.info("Links encontrados na base 2: %s", json.dumps(links, indent=1))

    for ano in anos:
        url = links.get(ano)
        if not url:
            logger.warning("Base 2: sem link para %s", ano)
            resultado["sem_link"].append(ano)
            continue
        try:
            conteudo = baixar_bytes(url)
            if not csv_tem_dados(conteudo):
                resultado["vazio"].append(ano)
                continue
            chave = f"bolsa-familia-sp/{ano}/bolsa-familia-sp-{ano}.csv"
            salvar_s3(conteudo, chave)
            resultado["ok"].append(ano)
        except Exception as e:  # noqa: BLE001
            logger.exception("Erro na base 2, ano %s (%s)", ano, url)
            resultado["erro"][ano] = str(e)
    return resultado


# ----------------------------------------------------------------------------
# Handler
# ----------------------------------------------------------------------------
def lambda_handler(event, context):
    """
    Evento opcional para sobrescrever os padrões:
    {"ano_inicial": 2020, "ano_final": 2026, "bases": ["base1", "base2"]}
    """
    if not BUCKET_NAME:
        raise ValueError("Defina a variável de ambiente BUCKET_NAME")

    event = event or {}
    ano_ini = int(event.get("ano_inicial") or ANO_INICIAL)
    ano_fim = int(event.get("ano_final") or ANO_FINAL)

    if event.get("somente_ano_atual"):
        ano_ini = ano_fim = datetime.now().year

    bases = event.get("bases", ["base1", "base2"])
    anos = list(range(ano_ini, ano_fim + 1))

    resumo = {"anos": anos}
    if "base1" in bases:
        resumo["familias-cadastro-unico"] = processar_base1(anos)
    if "base2" in bases:
        resumo["bolsa-familia-sp"] = processar_base2(anos)

    logger.info("Resumo: %s", json.dumps(resumo, ensure_ascii=False))
    return {"statusCode": 200, "body": resumo}
