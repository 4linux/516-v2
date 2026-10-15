#!/usr/bin/env python3
"""
analisa-opensearch.py: Busca logs no OpenSearch e analisa com IA via OpenRouter.

Uso:
  python3 analisa-opensearch.py [termo] [pergunta]

Exemplos:
  python3 analisa-opensearch.py
  python3 analisa-opensearch.py "error" "Quais são os erros mais frequentes?"
  python3 analisa-opensearch.py "sshd" "Há atividade suspeita nos logs de SSH?"

Variáveis de ambiente:
  OPENROUTER_API_KEY  : chave de API do OpenRouter (obrigatório)
  OPENSEARCH_URL      : URL do OpenSearch (padrão: https://172.16.0.20:9200)
  OPENSEARCH_USER     : usuário do OpenSearch (padrão: admin)
  OPENSEARCH_PASS     : senha do OpenSearch (padrão: 4Linux@516!)
  OPENSEARCH_INDEX    : índice a consultar (padrão: logs-*)
"""

import requests
import sys
import os
import json
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# -----------------------------------------------------------------------
# Configuração
# -----------------------------------------------------------------------
OPENROUTER_API_KEY = os.environ.get("OPENROUTER_API_KEY", "")
# Modelo gratuito preferido. A lista de modelos ":free" muda com frequência:
# para usar outro, exporte OPENROUTER_MODEL="fornecedor/modelo:free"
MODEL = os.environ.get("OPENROUTER_MODEL", "google/gemma-4-31b-it:free")
# Se o preferido estiver indisponível ou com limite de uso (erro 429), a
# OpenRouter tenta os próximos da lista. "openrouter/free" escolhe qualquer
# modelo gratuito disponível no momento.
MODELOS_RESERVA = ["nvidia/nemotron-3-super-120b-a12b:free", "openrouter/free"]
MAX_TOKENS = 1500  # Tamanho máximo da resposta

OPENSEARCH_URL   = os.environ.get("OPENSEARCH_URL",   "https://172.16.0.20:9200")
OPENSEARCH_USER  = os.environ.get("OPENSEARCH_USER",  "admin")
OPENSEARCH_PASS  = os.environ.get("OPENSEARCH_PASS",  "4Linux@516!")
OPENSEARCH_INDEX = os.environ.get("OPENSEARCH_INDEX", "logs-*")

MAX_DOCS = 100
# -----------------------------------------------------------------------


def busca_logs_opensearch(termo=""):
    url = f"{OPENSEARCH_URL}/{OPENSEARCH_INDEX}/_search"
    query_clause = (
        {"match": {"message": termo}} if termo else {"match_all": {}}
    )
    corpo = {
        "size": MAX_DOCS,
        "sort": [{"@timestamp": {"order": "desc"}}],
        "query": {
            "bool": {
                "must": [query_clause],
                "filter": [{"range": {"@timestamp": {"gte": "now-1h"}}}],
            }
        },
    }
    resposta = requests.post(
        url,
        headers={"Content-Type": "application/json"},
        data=json.dumps(corpo),
        auth=(OPENSEARCH_USER, OPENSEARCH_PASS),
        verify=False,
        timeout=30,
    )
    resposta.raise_for_status()
    return resposta.json().get("hits", {}).get("hits", [])


def formata_hits(hits):
    linhas = []
    for hit in hits:
        src  = hit.get("_source", {})
        ts   = src.get("@timestamp", "")
        host = src.get("hostname", src.get("host", ""))
        tag  = src.get("tag", "")
        txt  = src.get("log", src.get("message", ""))
        linhas.append(f"[{ts}] [{host}] [{tag}] {txt}")
    return "\n".join(linhas)


def analisa_logs(conteudo, pergunta):
    prompt = (
        "Você é um especialista em análise de logs de sistemas Linux.\n"
        "Analise os logs abaixo, coletados do OpenSearch, e responda à pergunta "
        "de forma clara e objetiva, em português.\n\n"
        f"PERGUNTA: {pergunta}\n\n"
        f"LOGS:\n{conteudo}"
    )
    resposta = requests.post(
        "https://openrouter.ai/api/v1/chat/completions",
        headers={
            "Authorization": f"Bearer {OPENROUTER_API_KEY}",
            "Content-Type": "application/json",
        },
        json={
            "models": [MODEL] + [m for m in MODELOS_RESERVA if m != MODEL],
            "messages": [{"role": "user", "content": prompt}],
            "max_tokens": MAX_TOKENS,
        },
        timeout=120,
    )
    if resposta.status_code != 200:
        try:
            detalhe = resposta.json().get("error", {}).get("message", resposta.text)
        except ValueError:
            detalhe = resposta.text
        print(f"\nErro {resposta.status_code} da OpenRouter (modelo {MODEL}):")
        print(f"  {detalhe}")
        if resposta.status_code == 401:
            print("  Chave inválida. Confira o valor exportado em OPENROUTER_API_KEY.")
        elif resposta.status_code == 404:
            print("  O modelo não existe mais. Veja os gratuitos em https://openrouter.ai/models?q=free")
            print("  e exporte OPENROUTER_MODEL com o nome do modelo escolhido.")
        elif resposta.status_code == 402:
            print("  Modelo pago ou sem crédito: use um modelo com sufixo ':free'.")
        elif resposta.status_code == 429:
            print("  Modelos gratuitos com limite de uso no momento. Aguarde alguns minutos e tente de novo.")
        sys.exit(1)
    dados = resposta.json()
    print(f"(modelo que respondeu: {dados.get('model', MODEL)})")
    return dados["choices"][0]["message"]["content"]


def main():
    if not OPENROUTER_API_KEY:
        print("Erro: variável OPENROUTER_API_KEY não definida.")
        print("Execute: export OPENROUTER_API_KEY='sua_chave_aqui'")
        sys.exit(1)

    termo    = sys.argv[1] if len(sys.argv) > 1 else ""
    pergunta = (
        sys.argv[2]
        if len(sys.argv) > 2
        else "O que está acontecendo de anormal nesses logs? Existe algo preocupante?"
    )

    print(f"\nBuscando logs no OpenSearch (índice: {OPENSEARCH_INDEX})...")
    try:
        hits = busca_logs_opensearch(termo)
    except requests.exceptions.ConnectionError:
        print(f"Erro: não foi possível conectar ao OpenSearch em {OPENSEARCH_URL}")
        print("Verifique se a VM opensearch está em execução: vagrant up opensearch")
        sys.exit(1)

    print(f"{len(hits)} documentos encontrados.")
    if not hits:
        print("Nenhum documento encontrado para o período.")
        sys.exit(0)

    conteudo = formata_hits(hits)
    print(f"Pergunta: {pergunta}\n")
    print("=" * 60)

    resultado = analisa_logs(conteudo, pergunta)
    print(resultado)
    print("=" * 60)


if __name__ == "__main__":
    main()
