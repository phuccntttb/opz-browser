# Opz website: the landing page, plus /updates/ (update server for installed
# copies of Opz). Deployed by Dokploy from this repo (build context: site/).
#
# /updates/ is NOT in the image: Dokploy bind-mounts a directory on the
# server (e.g. /srv/opz/updates) to /usr/share/nginx/html/updates, and
# scripts/release.sh --publish rsyncs releases into it. Redeploying the
# landing page never touches the releases.
FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY index.html /usr/share/nginx/html/index.html
