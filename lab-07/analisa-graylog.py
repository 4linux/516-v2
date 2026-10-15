#!/usr/bin/env python3
"""
analisa-graylog.py: Busca logs no Graylog via API e analisa com IA via OpenRouter.

Uso:
  python3 analisa-graylog.py [query] [pergunta]

Exemplos:
  python3 analisa-graylog.py
  python3 analisa-graylog.py "sshd OR auth" "Houve tentativas de login com falha?"
  python3 analisa-graylog.py "*" "Resuma o que aconteceu no sistema na última hora"

Variáveis de ambiente:
  OPENROUTER_API_KEY  : chave de API do OpenRouter (obrigatório)
  GRAYLOG_URL         : URL do Graylog (padrão: http://172.16.0.10:9000)
  GRAYLOG_USER        : usuário do Graylog (padrão: admin)
  GRAYLOG_PASS        : senha do Graylog (padrão: 4Linux@516!)
"""

import requests
import sys
import os
from requests.auth import HTTPBasicAuth

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

GRAYLOG_URL  = os.environ.get("GRAYLOG_URL",  "http://172.16.0.10:9000")
GRAYLOG_USER = os.environ.get("GRAYLOG_USER", "admin")
GRAYLOG_PASS = os.environ.get("GRAYLOG_PASS", "4Linux@516!")

MAX_MENSAGENS  = 100
JANELA_MINUTOS = 60
# -----------------------------------------------------------------------


def busca_logs_graylog(query="*"):
    url = f"{GRAYLOG_URL}/api/search/universal/relative"
    params = {
        "query": query,
        "range": JANELA_MINUTOS * 60,
        "limit": MAX_MENSAGENS,
        "fields": "timestamp,source,level,message",
    }
    resposta = requests.get(
        url,
        params=params,
        auth=HTTPBasicAuth(GRAYLOG_USER, GRAYLOG_PASS),
        headers={"Accept": "application/json"},
        timeout=30,
    )
    resposta.raise_for_status()
    return resposta.json().get("messages", [])


def formata_mensagens(mensagens):
    linhas = []
    for item in mensagens:
        msg  = item.get("message", {})
        ts   = msg.get("timestamp", "")
        host = msg.get("source", "")
        lvl  = msg.get("level", "")
        txt  = msg.get("message", "")
        linhas.append(f"[{ts}] [{host}] [nivel:{lvl}] {txt}")
    return "\n".join(linhas)


def analisa_logs(conteudo, pergunta):
    prompt = (
        "Você é um especialista em análise de logs de sistemas Linux.\n"
        "Analise os logs abaixo, coletados do Graylog, e responda à pergunta "
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

    query   = sys.argv[1] if len(sys.argv) > 1 else "*"
    pergunta = (
        sys.argv[2]
        if len(sys.argv) > 2
        else "O que está acontecendo de anormal nesses logs? Existe algo preocupante?"
    )

    print(f"\nBuscando logs no Graylog (query: '{query}', últimos {JANELA_MINUTOS} min)...")
    try:
        mensagens = busca_logs_graylog(query)
    except requests.exceptions.ConnectionError:
        print(f"Erro: não foi possível conectar ao Graylog em {GRAYLOG_URL}")
        print("Verifique se a VM graylog está em execução: vagrant up graylog")
        sys.exit(1)

    print(f"{len(mensagens)} mensagens encontradas.")
    if not mensagens:
        print("Nenhuma mensagem encontrada para o período.")
        sys.exit(0)

    conteudo = formata_mensagens(mensagens)
    print(f"Pergunta: {pergunta}\n")
    print("=" * 60)

    resultado = analisa_logs(conteudo, pergunta)
    print(resultado)
    print("=" * 60)


if __name__ == "__main__":
    main()
