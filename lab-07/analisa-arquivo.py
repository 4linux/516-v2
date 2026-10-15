#!/usr/bin/env python3
"""
analisa-arquivo.py: Analisa um arquivo de log local com auxílio de IA via OpenRouter.

Uso:
  python3 analisa-arquivo.py <arquivo> [pergunta]

Exemplos:
  python3 analisa-arquivo.py /var/log/syslog
  python3 analisa-arquivo.py /var/log/auth.log "Houve tentativas de acesso com falha?"
  python3 analisa-arquivo.py /var/log/audit/audit.log "Algum arquivo crítico foi acessado?"
"""

import requests
import sys
import os

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
MAX_CHARS = 6000  # Limite de caracteres enviados à IA por requisição
# -----------------------------------------------------------------------


def analisa_logs(conteudo, pergunta):
    prompt = (
        "Você é um especialista em análise de logs de sistemas Linux.\n"
        "Analise os logs abaixo e responda à pergunta de forma clara e objetiva, em português.\n\n"
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

    arquivo = sys.argv[1] if len(sys.argv) > 1 else "/var/log/syslog"
    pergunta = (
        sys.argv[2]
        if len(sys.argv) > 2
        else "O que está acontecendo de anormal nesses logs? Existe algo preocupante?"
    )

    if not os.path.isfile(arquivo):
        print(f"Erro: arquivo '{arquivo}' não encontrado.")
        sys.exit(1)

    print(f"\nLendo: {arquivo}")
    try:
        with open(arquivo, "r", errors="ignore") as f:
            conteudo = f.read()
    except PermissionError:
        print(f"Erro: sem permissão para ler {arquivo}.")
        print("Os logs do sistema só podem ser lidos pelo root. Execute 'sudo -i' e rode o script de novo.")
        sys.exit(1)

    trecho = conteudo[-MAX_CHARS:]
    print(f"Enviando {len(trecho)} caracteres para análise...")
    print(f"Pergunta: {pergunta}\n")
    print("=" * 60)

    resultado = analisa_logs(trecho, pergunta)
    print(resultado)
    print("=" * 60)


if __name__ == "__main__":
    main()
