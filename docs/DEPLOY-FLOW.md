# Fluxo de deploy da imagem Airflow (CI/CD)

Este documento descreve como funciona o pipeline atual entre o repositório da imagem Docker (`airflow2-docker`), o repositório de manifests Helm (`kube-deploys`) e o **Argo CD** no cluster.

## Visão geral

1. **Só um tipo de evento dispara o fluxo principal:** push de uma **tag Git** no formato **`v*.*.*`** (por exemplo `v2.10.9-new-deploy-flow`).
2. O GitHub Actions em **`airflow2-docker`** constrói a imagem, publica no **GHCR** e dispara um evento no **`kube-deploys`** para atualizar os valores do Helm **dev**.
3. Um segundo job aguarda **aprovação obrigatória** no ambiente **`production`**; depois da aprovação, promove a mesma imagem (sem rebuild) para **produção** no GHCR e atualiza o Helm **prod** no `kube-deploys`.
4. O **Argo CD** observa o repositório `kube-deploys` e aplica as mudanças nos namespaces correspondentes (dev / prod).

Fluxo resumido:

```text
tag vX.Y.Z no airflow2-docker
  → build imagem :vX.Y.Z-rc.1 + dispatch dev (kube-deploys)
  → [pausa] aprovação GitHub Environment "production"
  → retag digest → :vX.Y.Z e :latest no GHCR + dispatch prod (kube-deploys)
  → Argo CD sincroniza clusters
```

## Repositório `airflow2-docker`

### Workflow principal: `.github/workflows/docker-publish-dev-first.yml`

**Gatilho:** apenas `push` de tags que casam com `v*.*.*`.  
**Push na branch `main` sem tag não dispara** este fluxo.

#### Job 1 — `build_rc_and_update_dev`

| Etapa | O que faz |
|-------|-----------|
| Tags da imagem | A partir da tag Git `VERSION` (ex.: `v2.10.9-new-deploy-flow`), calcula **`VERSION-rc.1`** (ex.: `v2.10.9-new-deploy-flow-rc.1`). |
| Build | Imagem Docker publicada no GHCR só com a tag **RC** (`…-rc.1`). |
| Dispatch | Chama a API `repository_dispatch` do repo **`gestaogovbr/kube-deploys`** com `event_type: update_airflow_dev` e payload com `repository` + **`tag` = RC**. |

#### Job 2 — `promote_to_prod`

| Etapa | O que faz |
|-------|-----------|
| Environment | Usa **`environment: production`**. O workflow **pausa** até existir **aprovação** conforme as regras do ambiente no GitHub (revisores obrigatórios, opcionalmente *prevent self-review*). |
| Retag | Usa `docker buildx imagetools create` para apontar as tags **`VERSION`** (sem `-rc.1`) e **`latest`** para o **mesmo digest** da imagem RC — **sem novo build**. |
| Dispatch | Chama `repository_dispatch` com `event_type: update_airflow_prod` e **`tag: VERSION`** no payload (tag imutável no Helm de prod, ex.: `v2.10.10-gx-compat`, para o Argo CD detectar diff e fazer rollout). A tag **`latest`** no GHCR continua sendo atualizada no retag, mas não é mais o valor gravado no `custom-values.yml`. |

### Segredo e permissões

- No repositório **`airflow2-docker`**, o secret **`PAT_KUBE_DEPLOYS`** deve ser um **fine-grained PAT** com acesso ao repo **`kube-deploys`** e permissões suficientes para disparar `repository_dispatch` e para o workflow lá conseguir commitar (conforme política da organização).

### Workflow legado: `.github/workflows/docker-publish.yml`

Mantido para outros gatilhos (por exemplo `repository_dispatch` de dependências). Tags no formato **`v*.*.*`** são **excluídas** deste workflow para não duplicar build com o fluxo *dev-first*.

### Aprovação obrigatória para produção

Configure em **Settings → Environments → `production`**:

- **Required reviewers:** quem pode aprovar a promoção.
- Opcional: **Wait timer**, **deployment branches**, **Prevent self-review** (quem disparou a execução não pode ser o mesmo que aprova).

Sem revisores configurados no ambiente `production`, o segundo job pode rodar **sem** etapa de aprovação visível — por isso a revisão manual deve estar **explicitamente** definida no Environment.

## Repositório `kube-deploys`

### Workflow: `.github/workflows/update-airflow-custom-values.yml`

**Gatilho:** `repository_dispatch` com tipos:

- **`update_airflow_dev`** — atualiza `deploys/airflow-dev/helm/custom-values.yml` (`airflow.image.repository` e `airflow.image.tag`). O **tag** enviado é o da RC (ex.: `…-rc.1`).
- **`update_airflow_prod`** — atualiza `deploys/airflow/helm/custom-values.yml`. O **tag** enviado é **`VERSION`** (mesma tag Git da release, sem `-rc.1`).

Após editar o YAML com `yq`, o workflow faz **commit e push** na branch padrão (geralmente `main`).

## Papel do Argo CD

O Argo CD não é chamado pelo GitHub Actions diretamente. Ele:

1. Monitora o repositório **`kube-deploys`** (branch/paths configurados na Application).
2. Detecta o novo commit nos `custom-values.yml`.
3. Sincroniza o Helm/Application correspondente (**airflow-dev** vs **airflow** / produção), fazendo pull da nova imagem conforme `repository` + `tag` e política de pull no cluster.

Ou seja: **GitHub Actions atualiza o Git**; **Argo CD aplica no Kubernetes**.

## Como disparar um deploy

Ordem recomendada na sua máquina:

1. **Commitar** as alterações que devem entrar na imagem.
2. **Enviar a `main` para o GitHub:** `git push origin main` — assim o repositório remoto deixa de ficar **desatualizado** em relação ao que você vai etiquetar.
3. **Alinhar com o remoto:** `git pull origin main` (incorpora commits de outras pessoas e confirma que sua `main` local = `origin/main`).
4. **Só então** criar a tag no commit que você quer implantar e dar push da tag.

```bash
git add … && git commit -m "…"    # se houver mudanças locais
git push origin main               # não esquecer: senão a main no GitHub fica atrás
git pull origin main               # sincroniza com a equipe
git tag v2.11.0-minha-feature
git push origin v2.11.0-minha-feature
```

**Por que commit + push na `main` antes da tag**

- Se você **esquecer de commitar** ou **esquecer de dar `push` na `main`** e mesmo assim criar e enviar só a **tag**, o GitHub pode ficar num estado incoerente: a **`main` remota desatualizada** (sem seu trabalho) enquanto a **tag** aponta para um commit **à frente** — código que existe na sua máquina (ou só na tag) mas não aparece como último commit da `main` no repositório.
- O pipeline é disparado pelo **push da tag** e builda o commit que a tag referencia. Para o time e para o histórico, o ideal é esse commit ser **o mesmo** que está na ponta da **`main`** que todos veem no GitHub (depois do seu push da branch).

**Não esqueça — `pull` da `main` remota antes de etiquetar**

- Depois do **`git push origin main`**, rode **`git pull origin main`** antes de `git tag`, para não etiquetar um commit **antigo** por engano e para receber commits dos outros.
- Se você pular o **pull**, a tag pode ficar “atrás” da `origin/main` ou você pode não estar no commit que acha.

**Não esqueça — atualizar a `main` remota antes da tag**

- **Obrigatório** integrar o estado certo na **`main` remota** (`push` das suas mudanças + **`git pull origin main`**) **antes** de `git tag` e do **`git push` da tag**.
- O fluxo espera que o deploy reflita o que a equipe considera **integrado na `main`** no GitHub, não só uma tag isolada com código que nunca entrou na branch no remoto.

**Importante — tag Git é separada do push da branch**

- Criar a tag **só na sua máquina** (`git tag …`) **não dispara** o workflow nem aparece no GitHub até você **enviar a tag ao remoto**.
- `git push origin main` envia **commits** da branch `main`; **não envia tags**. Por isso é obrigatório o **`git push origin <nome-da-tag>`** (ou `git push origin --tags` se quiser enviar todas as tags locais de uma vez — use com cuidado).
- O fluxo CI/CD deste repositório é disparado pelo evento **push da tag no remoto**, não pelo push da `main` sozinho.

- Em seguida acompanhe **Actions** no `airflow2-docker`: primeiro job (dev), depois **Review deployments** / aprovação para o job de prod.
- Valide **dev**; depois **aprove** para liberar prod (se sua política exigir outra pessoa, ela deve aprovar no GitHub).

## Imagens no GHCR (referência)

| Momento | Tags criadas/atualizadas no GHCR |
|---------|-----------------------------------|
| Após job dev | `…:VERSION-rc.1` apenas |
| Após aprovação + job prod | `…:VERSION` e `…:latest` (mesmo digest da RC) |

## Recomendações e atenções

Boas práticas para reduzir falhas e bloqueios no fluxo.

### Git e tags

- **Antes da tag:** conferir se há mudanças **commitadas** e se você já rodou **`git push origin main`**. Sem isso, a `main` no GitHub pode continuar antiga e a tag pode apontar para commits que **não** aparecem como evolução normal da branch — confusão para o time e risco de imagem “à frente” do que está na `main` remota.
- Depois do push da `main`, **`git pull origin main`** e só então **`git tag`** — assim sua `main` local está alinhada com `origin/main` no momento de etiquetar.
- Manter um **padrão estável** de nome (`v*.*.*`). Mudanças no glob do workflow exigem atualizar o YAML e esta documentação.
- Evitar **reutilizar** o mesmo nome de tag no remoto (apagar e recriar) sem necessidade — confunde histórico e execuções no Actions.
- Lembrete: só `git push origin <nome-da-tag>` dispara o pipeline; push da `main` **não** envia tags.

### GitHub Actions (`airflow2-docker`)

- **`PAT_KUBE_DEPLOYS`:** acompanhar **validade** do fine-grained PAT; renovar antes de expirar. Confirmar escopo no repo **`kube-deploys`** e permissões exigidas pela org (dispatch + commits lá).
- **Environment `production`:** manter **Required reviewers** sempre definidos e lista de pessoas **atualizada**.
- Se **Prevent self-review** estiver ativo, garantir **pelo menos um revisor diferente** de quem fez o push da tag — senão a aprovação pode ficar impossível.
- Se o passo de **dispatch** devolver erro (HTTP ≠ 204 no log), **corrigir token/permissões** antes de insistir em produção.
- No YAML dos workflows, em scripts `run: |` com **continuação de linha (`\`)**, **não** inserir linhas em branco entre as linhas do comando — o shell quebra e comandos como `curl` falham de forma confusa.

### Dockerfile e imagem

- O build deve continuar **falhando** se o módulo **`fastetl`** não puder ser importado após a instalação — evita imagem que quebra plugins em runtime.
- Mudanças grandes em dependências: preferir validar antes em **dev** (tag + RC) antes de aprovar **prod**.

### Repositório `kube-deploys`

- **Não mover ou renomear** os arquivos `deploys/airflow-dev/helm/custom-values.yml` e `deploys/airflow/helm/custom-values.yml` sem ajustar o workflow **`update-airflow-custom-values.yml`** (paths do `yq`).
- Edições manuais nos values: conferir se **`airflow.image.repository`** permanece **`ghcr.io/gestaogovbr/airflow2-docker`** (ou o valor oficial acordado).

### Argo CD

- Confirmar que cada **Application** aponta para a **branch** e o **path** corretos dentro do `kube-deploys`.
- Se produção usar **sync manual**, definir **quem** executa o Sync após o commit automático do GitHub Actions.
- Respeitar **sync windows** ou políticas da org: o pipeline pode estar correto e o cluster só atualizar na janela permitida.

### Operação e checklist rápido

1. Actions **verde** no `airflow2-docker` (job dev; depois aprovação e job prod).
2. **Novo commit** no `kube-deploys` nos `custom-values.yml` esperados.
3. No Argo CD: app **OutOfSync → Synced** (ou equivalente) e pods com **imagem/digest** esperados.

### Documentação

- Ao mudar gatilhos, paths Helm, comportamento de **`latest`** vs RC ou ambientes do GitHub, **atualizar este arquivo** (`DEPLOY-FLOW.md`) para o time não operar com informação desatualizada.

## Rollback (orientação)

- **Dev:** voltar `deploys/airflow-dev/helm/custom-values.yml` para uma RC anterior ou novo dispatch/commit manual.
- **Prod:** o Helm usa tag **imutável** (`VERSION`); o histórico no Git do `kube-deploys` indica qual release está aplicada. Rollback: voltar `airflow.image.tag` no `custom-values.yml` para a release anterior.
