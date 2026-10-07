#!/usr/bin/env python3
"""
Auditoria do fork Indica Facil contra uma versao de referencia.

Responde a pergunta: "alguma modificacao minha sumiu?"

Uso:
    python script/audit_fork_features.py <pasta-de-referencia>

Exemplo:
    python script/audit_fork_features.py \\
      D:/dev2026/chatwoot-free-indicafacil-source-oficial/chatwoot-4.16.0-fazer-ai.90/chatwoot-4.16.0-fazer-ai.90

A referencia deve ser a versao da fazer.ai (ou um release anterior nosso) que
contem todas as features esperadas. O script reporta:

  1. Arquivos EXCLUSIVOS do fork que sumiram do nosso repo
  2. Contagem por feature (Baileys, Z-API, Chat Interno, Kanban, agendadas)
  3. Estado da marca (links de licenca, extensao, residuo de fazer.ai)

Saida diferente de zero = alguma verificacao falhou.

Contexto: em 2026-07-25 um patch do Chatwoot oficial sobrescreveu 39 arquivos
compartilhados e removeu Baileys, Z-API, Chat Interno e Kanban da interface.
O build Docker passou verde e o eslint ficou limpo. Este script existe para
que isso seja detectado em segundos, e nao depois da release.
"""
import os
import subprocess
import sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SKIP = {'.git', 'node_modules', 'vendor', 'tmp', 'log', 'coverage', '.bundle', 'public'}
SKIP_FILES = {'pnpm-lock.yaml', 'Gemfile.lock'}

falhas = []


def arvore(raiz):
    out = set()
    for dp, dn, fn in os.walk(raiz):
        dn[:] = [d for d in dn if d not in SKIP]
        for f in fn:
            if f in SKIP_FILES:
                continue
            p = os.path.relpath(os.path.join(dp, f), raiz).replace('\\', '/')
            if any(s in p.split('/') for s in SKIP):
                continue
            out.add(p)
    return out


def conta_grep(padrao, caminho, flags='-c'):
    alvo = os.path.join(REPO, caminho)
    if not os.path.exists(alvo):
        return 0
    r = subprocess.run(['grep', flags, padrao, alvo], capture_output=True, text=True)
    try:
        return int((r.stdout or '0').strip().splitlines()[0])
    except (ValueError, IndexError):
        return 0


def conta_arquivos(pasta):
    alvo = os.path.join(REPO, pasta)
    return len(os.listdir(alvo)) if os.path.isdir(alvo) else 0


def marca_em_strings():
    """Falha se 'Chatwoot' voltar a aparecer em texto que o usuario le.

    Esta verificacao nasceu tarde: oito releases sairam com 36 strings da
    interface nomeando o Chatwoot em vez da instalacao, e o audit passava verde
    porque so procurava residuo de fazer.ai. O painel usa o sentinela %BRAND%
    (resolvido no boot por i18n/applyBrand.js) e os locales do Rails usam
    %{brand}. Um sync que copie o arquivo do upstream por cima traz o nome de
    volta, sem quebrar teste nenhum -- dai o guard.
    """
    import json
    import re

    permitido = (
        'latestChatwootVersion',   # nome de variavel, nao texto exibido
        'Chatwoot app',            # o aplicativo do Slack chama-se assim de fato
        'aplicativo Chatwoot',
    )
    achados = []

    for locale in ('en', 'pt_BR'):
        pasta = os.path.join(REPO, 'app/javascript/dashboard/i18n/locale', locale)
        if not os.path.isdir(pasta):
            continue
        for nome in sorted(os.listdir(pasta)):
            if not nome.endswith('.json'):
                continue
            caminho = os.path.join(pasta, nome)
            try:
                bruto = open(caminho, encoding='utf-8').read()
            except OSError:
                continue
            for trecho in re.findall(r'"(?:[^"\\]|\\.)*Chatwoot(?:[^"\\]|\\.)*"', bruto):
                if any(ok in trecho for ok in permitido):
                    continue
                achados.append(f'{locale}/{nome}: {trecho[:70]}')

    for arquivo in ('config/locales/en.yml', 'config/locales/pt_BR.yml'):
        caminho = os.path.join(REPO, arquivo)
        if not os.path.exists(caminho):
            continue
        for linha in open(caminho, encoding='utf-8'):
            if 'Chatwoot' in linha and re.search(r'(description|short_description|name):', linha):
                achados.append(f'{arquivo}: {linha.strip()[:70]}')

    if achados:
        print(f"  FALHA {len(achados)} string(s) de interface citam Chatwoot:")
        for a in achados[:15]:
            print(f"        {a}")
        falhas.append('marca nas strings')
    else:
        print("  ok  nenhuma string de interface cita Chatwoot")

    sentinela_resolvido()


def sentinela_resolvido():
    """Falha se algum app que usa as mensagens do dashboard nao resolver %BRAND%.

    Existe por um defeito real: a substituicao entrou so no entrypoint do
    dashboard, e a tela de login e' outra aplicacao Vue que importa as mesmas
    mensagens. O resultado foi "Entrar no %BRAND%" em producao. Nenhum teste
    pegou, porque o sentinela e' texto valido.
    """
    faltando = []
    candidatos = []

    base = os.path.join(REPO, 'app/javascript')
    for pasta, _, arquivos in os.walk(base):
        if 'node_modules' in pasta.split(os.sep):
            continue
        for nome in arquivos:
            if not nome.endswith(('.js', '.ts')):
                continue
            caminho = os.path.join(pasta, nome)
            try:
                conteudo = open(caminho, encoding='utf-8').read()
            except OSError:
                continue
            # quem importa as mensagens do dashboard tem de aplicar a marca
            if "from 'dashboard/i18n'" not in conteudo:
                continue
            candidatos.append(caminho)
            if 'applyBrand' not in conteudo:
                faltando.append(os.path.relpath(caminho, REPO))

    if faltando:
        print(f"  FALHA {len(faltando)} app(s) usam as mensagens sem resolver %BRAND%:")
        for p in faltando:
            print(f"        {p}")
        falhas.append('sentinela nao resolvido')
    else:
        print(f"  ok  os {len(candidatos)} apps que usam as mensagens resolvem %BRAND%")


def check(rotulo, valor, minimo):
    ok = valor >= minimo
    print(f"  {'ok ' if ok else 'FALHA'} {rotulo}: {valor} (minimo {minimo})")
    if not ok:
        falhas.append(rotulo)


def main():
    if len(sys.argv) > 1:
        ref = sys.argv[1]
        if not os.path.isdir(ref):
            print(f"Pasta de referencia nao encontrada: {ref}")
            return 2
        print("=" * 62)
        print("1) ARQUIVOS EXCLUSIVOS DO FORK")
        print("=" * 62)
        s_ref, s_nos = arvore(ref), arvore(REPO)
        # heuristica: tudo que a referencia tem e nos nao
        sumiu = sorted(s_ref - s_nos)
        # workflows e o middleware renomeado sao divergencias esperadas
        esperado = ('.github/workflows/', 'fazer_ai_platform_header.rb')
        real = [p for p in sumiu if not any(e in p for e in esperado)]
        print(f"  referencia: {len(s_ref)} arquivos | nosso: {len(s_nos)}")
        if real:
            print(f"  FALHA {len(real)} arquivo(s) sumiram:")
            for p in real[:40]:
                print(f"        {p}")
            falhas.append('arquivos ausentes')
        else:
            print("  ok  nenhum arquivo inesperado ausente")
        print()

    print("=" * 62)
    print("2) FEATURES DO FORK")
    print("=" * 62)
    print(" WhatsApp - Baileys e Z-API")
    check("provedores na tela de canal",
          conta_grep('baileys\\|zapi',
                     'app/javascript/dashboard/routes/dashboard/settings/inbox/channels/Whatsapp.vue',
                     '-ic'), 20)
    check("webhook controller",
          conta_grep('baileys\\|zapi', 'app/controllers/webhooks/whatsapp_controller.rb', '-ic'), 2)
    check("handlers baileys", conta_arquivos('app/services/whatsapp/baileys_handlers'), 11)
    check("handlers zapi", conta_arquivos('app/services/whatsapp/zapi_handlers'), 6)

    print(" Chat Interno")
    check("rotas backend", conta_grep('internal_chat', 'config/routes.rb'), 1)
    check("models", conta_arquivos('app/models/internal_chat'), 12)
    check("controllers", conta_arquivos('app/controllers/api/v1/accounts/internal_chat'), 9)
    check("modulos vuex", conta_grep('internalChat', 'app/javascript/dashboard/store/index.js'), 4)

    print(" Kanban / menu lateral")
    check("rotas dashboard",
          conta_grep('kanban\\|internalChat', 'app/javascript/dashboard/routes/dashboard/dashboard.routes.js'), 4)

    print(" Mensagens agendadas")
    check("rotas", conta_grep('scheduled_messages', 'config/routes.rb'), 1)

    print()
    print("=" * 62)
    print("3) MARCA")
    print("=" * 62)
    r = subprocess.run(['grep', '-rl', 'indicafacil.ai', os.path.join(REPO, 'app/javascript')],
                       capture_output=True, text=True)
    check("arquivos com link de licenca", len([x for x in r.stdout.splitlines() if x.strip()]), 4)
    check("extensao Chrome Indica Facil",
          conta_grep('lnkmkgmicadcmbocnbogggkemjihjjcm',
                     'app/javascript/dashboard/routes/dashboard/settings/inbox/components/WhatsappLinkDeviceModal.vue'), 1)

    r = subprocess.run(['grep', '-rl', 'fazer\\.ai\\|fazer-ai\\|fazer_ai\\|FazerAi',
                        '--include=*.rb', '--include=*.vue', '--include=*.js', '--include=*.erb',
                        os.path.join(REPO, 'app'), os.path.join(REPO, 'config'), os.path.join(REPO, 'lib')],
                       capture_output=True, text=True)
    resto = [x for x in r.stdout.splitlines() if x.strip()]
    if resto:
        print(f"  FALHA {len(resto)} arquivo(s) ainda citam fazer.ai:")
        for p in resto[:20]:
            print(f"        {os.path.relpath(p, REPO)}")
        falhas.append('residuo fazer.ai')
    else:
        print("  ok  nenhum residuo de fazer.ai")

    marca_em_strings()

    try:
        v = open(os.path.join(REPO, 'VERSION_CW'), encoding='utf-8').read().strip()
        app = open(os.path.join(REPO, 'config/app.yml'), encoding='utf-8').read()
        if v and v in app:
            print(f"  ok  VERSION_CW e app.yml batem ({v})")
        else:
            print(f"  FALHA VERSION_CW ({v}) nao aparece em config/app.yml")
            falhas.append('versao divergente')
    except OSError as e:
        print(f"  FALHA lendo versao: {e}")
        falhas.append('versao ilegivel')

    print()
    print("=" * 62)
    if falhas:
        print(f"RESULTADO: {len(falhas)} verificacao(oes) FALHARAM")
        for f in falhas:
            print(f"  - {f}")
        return 1
    print("RESULTADO: tudo certo - nenhuma modificacao do fork ausente")
    return 0


if __name__ == '__main__':
    sys.exit(main())
