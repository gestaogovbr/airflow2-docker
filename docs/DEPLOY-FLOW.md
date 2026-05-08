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
| Dispatch | Chama `repository_dispatch` com `event_type: update_airflow_prod` e **`tag: latest`** no payload (valores Helm de prod usam a tag mutável `latest`; o digest já foi fixado no GHCR no passo anterior). |

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
- **`update_airflow_prod`** — atualiza `deploys/airflow/helm/custom-values.yml`. O **tag** enviado é **`latest`** (alinhado ao fluxo atual no `airflow2-docker`).

Após editar o YAML com `yq`, o workflow faz **commit e push** na branch padrão (geralmente `main`).

## Papel do Argo CD

O Argo CD não é chamado pelo GitHub Actions diretamente. Ele:

1. Monitora o repositório **`kube-deploys`** (branch/paths configurados na Application).
2. Detecta o novo commit nos `custom-values.yml`.
3. Sincroniza o Helm/Application correspondente (**airflow-dev** vs **airflow** / produção), fazendo pull da nova imagem conforme `repository` + `tag` e política de pull no cluster.

Ou seja: **GitHub Actions atualiza o Git**; **Argo CD aplica no Kubernetes**.

## Como disparar um deploy

Na máquina local, com a `main` atualizada:

```bash
git pull origin main
git tag v2.11.0-minha-feature
git push origin v2.11.0-minha-feature
```

- Em seguida acompanhe **Actions** no `airflow2-docker`: primeiro job (dev), depois **Review deployments** / aprovação para o job de prod.
- Valide **dev**; depois **aprove** para liberar prod (se sua política exigir outra pessoa, ela deve aprovar no GitHub).

## Imagens no GHCR (referência)

| Momento | Tags criadas/atualizadas no GHCR |
|---------|-----------------------------------|
| Após job dev | `…:VERSION-rc.1` apenas |
| Após aprovação + job prod | `…:VERSION` e `…:latest` (mesmo digest da RC) |

## Rollback (orientação)

- **Dev:** voltar `deploys/airflow-dev/helm/custom-values.yml` para uma RC anterior ou novo dispatch/commit manual.
- **Prod:** ajustar tag/digest no `kube-deploys` ou usar uma tag de imagem imutável documentada pela equipe; com `latest` no Helm, o histórico no Git do `kube-deploys` ajuda a saber qual deploy foi aplicado.
