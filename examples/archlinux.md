Arch Linux instances, run from repo root.

## GitLab

```bash
export BASE_URL=https://gitlab.archlinux.org/api/v4
tools/gitlab-fetch.sh archlinux/developer-manual content/package-guidelines/_index.md
tools/gitlab-fetch.sh pacman/pacman README
tools/gitlab-fetch.sh pacman/pacman wi/334
tools/gitlab-fetch.sh pacman/pacman mr/314
tools/gitlab-fetch.sh pacman/pacman cmp/master...allan/splitpkg2
tools/gitlab-fetch.sh pacman/pacman cmp/master..allan/splitpkg2
tools/gitlab-fetch.sh archlinux/packaging/packages/coreutils wi/10
tools/gitlab-fetch.sh https://gitlab.archlinux.org/pacman/pacman/-/merge_requests/314
tools/gitlab-fetch.sh pacman/pacman 'wi?signature'
tools/gitlab-fetch.sh pacman/pacman 'mr?makepkg lint'
REF=v7.0.0 tools/gitlab-fetch.sh pacman/pacman README
```

## Wiki

```bash
tools/wiki-fetch.sh wiki.archlinux.org 'Installation guide'
tools/wiki-fetch.sh wiki.archlinux.org 'Pacman/Tips and tricks'
tools/wiki-fetch.sh wiki.archlinux.org '?pacman hooks'
API=https://wiki.archlinux.org/api.php tools/wiki-fetch.sh - Pacman
```
