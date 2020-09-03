# Curator examples

This directory contains curator examples. Curator is expected to be run
under it’s own system user `curator`, which has a directory created for it in
`/var/log/curator` where this user can write to.

If you use Ansible and DebOps, you can use this host inventory snippet to achieve this:

```YAML

resources__host_paths:

  - dest: '/var/log/curator'
    mode: '0750'
    owner: 'curator'
    group: 'adm'
    state: 'directory'

## No such DebOps role exists yet.
## FIXME: Maybe the `curator__home_path` should better by `/etc/curator`?
curator__home_path: '{{ (ansible_local.root.home
                         if (ansible_local|d() and ansible_local.root|d() and
                             ansible_local.root.home|d())
                         else "/var/local") + "/" + "curator" }}'

users__host_accounts:

  - name: 'curator'
    system: True
    home: '{{ curator__home_path }}'
    move_home: True
    groups:
      - 'sshusers'
    shell: '/bin/zsh'
    sshkeys:
      - '{{ lookup("file", "changeme") }}'

```

## Example cron entry

```
5 2     * * *   curator /etc/curator/delete_indices.yml; curator/etc/curator/snapshot.yml; curator /etc/curator/delete_snapshots.yml
```
