# infrastructure-hosted-large-rdf-bench

Ansible that deploys the [**LargeRDFBench Interoperable Edition**](https://zenodo.org/records/22140177) as 13 **QLever SPARQL endpoints**,
one per node of a **jFed Virtual Wall** experiment.

Each node downloads `rdf_datasets.zip` (5.1 GB, md5-checked), extracts only the dataset it serves,
builds its QLever index, and serves it in a Docker container at

```
http://<wall address>:3002/sparql
```

## Files

- `inventory.yml` — the topology: one host per dataset, named after it, with its wall address and
  port (copy from `inventory.yml.example`, git-ignored).
- `group_vars/all.yml` — global settings: Virtual Wall connection and provisioning, Zenodo URL + md5,
  data directory, dataset → file mapping, QLever image, memory/timeout defaults and cache modes.
- `deploy.yml` — provision the nodes, download the data, index and serve.
- `serve.yml` — restart the endpoints in another cache mode, without provisioning.
- `requirements.yml` — Ansible collections needed (`community.docker`).

## 1. Prerequisites

- A jFed experiment swapped in with 13 nodes on Ubuntu, and its **PEM key** at `~/.ssh/ilabt.pem`
  (`chmod 600`). jFed dumps the key under `~/.jFed/tmp/`; copy it once:
  ```bash
  cp "$(ls -t ~/.jFed/tmp/sshKeyUsr*.pem | head -1)" ~/.ssh/ilabt.pem && chmod 600 ~/.ssh/ilabt.pem
  ```
- Ansible on your laptop.

The playbook expands each node's root disk (one reboot), enables outbound IPv4 (NAT) and installs
Docker.

## 2. Configure

`cp inventory.yml.example inventory.yml` and replace every `nXXX-XXa` placeholder with the wall
address of the node serving that dataset:

```yaml
qlever:
  hosts:
    Affymetrix: { ansible_host: n061-20a.wall2.ilabt.iminds.be, endpoint_port: 3002 }
```

The SSH user, PEM key and bastion are set in the inventory's `vars` (keep them in sync with
`group_vars/all.yml`). QLever settings default to `group_vars/all.yml` and can be overridden per host:

- `qlever_memory_max` → `qlever-server -m`
- `qlever_query_timeout` → `qlever-server -s`
- `qlever_index_memory` → `qlever-index -m`

## 3. Cache modes

The QLever query-result cache depends on `MODE`:

| Mode | Cache | Use |
|------|-------|-----|
| `experiment` (default) | off (`-c 0B -k 0`): every run and every query is evaluated cold | federated query experiments |
| `shapes` | on (`-c 4G -k 1000`) | shape extraction |

Each container carries its mode as the label `qlever.mode`, shown by `make health`. Only the
query-result cache is controlled; the OS page cache is not dropped.

## 4. Run

```bash
make ping                # all nodes reachable
make deploy              # provision, download, index and serve in MODE (re-runnable)
make serve MODE=shapes   # restart the endpoints in another mode (index reused)
make health              # per container: status, mode, restart count, OOM-killed
make stop                # remove every QLever container (data and indexes are kept)
```

Use another inventory with `make deploy INVENTORY=...`.

`make deploy` is idempotent: the disk is expanded once, the download and extraction are skipped
once the RDF file exists, an index is built only if missing, and a running container is only
recreated when its settings (mode included) or the pulled image change. Indexing the large
datasets takes a while.

## Layout on each node

```
~/data/
├── rdf_datasets.zip
└── <Dataset>/
    ├── <Dataset>.nt | .ttl     # extracted RDF
    └── <Dataset>.index.*       # QLever index
```

The container is named `qlever-<Dataset>`.
