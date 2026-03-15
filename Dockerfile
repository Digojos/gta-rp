FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Instala dependências necessárias
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    xz-utils \
    lib32gcc-s1 \
    ca-certificates \
    python3 \
    git \
    && rm -rf /var/lib/apt/lists/*

# Cria diretórios do servidor
RUN mkdir -p /app/fxserver /app/server-data/resources

WORKDIR /app/fxserver

# Baixa a versão mais recente recomendada do FXServer para Linux usando Python
RUN python3 - <<'EOF'
import urllib.request, json, re, os, subprocess

# Obtém versão recomendada
with urllib.request.urlopen("https://changelogs-live.fivem.net/api/changelog/versions/linux/server") as r:
    data = json.loads(r.read())
    recommended = data["recommended"]

print(f"Build recomendado: {recommended}")

# Obtém listagem de artefatos
with urllib.request.urlopen("https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/") as r:
    content = r.read().decode()

# Extrai o nome completo do artefato (ex: 25770-abc123def/)
match = re.search(rf"{recommended}-[0-9a-f]+", content)
if not match:
    raise Exception(f"Artefato {recommended} não encontrado na listagem")

artifact = match.group(0)
url = f"https://runtime.fivem.net/artifacts/fivem/build_proot_linux/master/{artifact}/fx.tar.xz"
print(f"Baixando: {url}")
subprocess.run(["wget", "-q", "--show-progress", url, "-O", "fx.tar.xz"], check=True)
EOF

RUN tar -xJf fx.tar.xz \
    && rm fx.tar.xz \
    && chmod +x /app/fxserver/run.sh

# Clona os resources padrão do FiveM (cfx-server-data)
RUN git clone --depth=1 https://github.com/citizenfx/cfx-server-data.git /app/cfx-server-data

# Cria entrypoint que copia resources padrão se a pasta estiver vazia
RUN printf '#!/bin/bash\n\
if [ -z "$(ls -A /app/server-data/resources 2>/dev/null)" ]; then\n\
    echo "[entrypoint] Copiando resources padrao do FXServer..."\n\
    cp -r /app/cfx-server-data/resources/. /app/server-data/resources/\n\
fi\n\
exec /app/fxserver/run.sh +exec /app/server-data/server.cfg\n' > /app/entrypoint.sh \
    && chmod +x /app/entrypoint.sh

# Porta do FiveM e txAdmin
EXPOSE 30120/tcp
EXPOSE 30120/udp
EXPOSE 40120/tcp

VOLUME ["/app/server-data"]

WORKDIR /app/server-data

CMD ["/app/entrypoint.sh"]
