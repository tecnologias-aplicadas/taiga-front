# This source code is licensed under the terms of the
# GNU Affero General Public License found in the LICENSE file in
# the root directory of this source tree.
#
# Copyright (c) 2021-present Kaleidos INC

FROM nginx:1.23-alpine
LABEL maintainer="support@taiga.io"

COPY docker/default.conf /etc/nginx/conf.d/default.conf
COPY docker/conf.json.template /
COPY source.zip /
COPY docker/config_env_subst.sh /docker-entrypoint.d/40_config_env_subst.sh
COPY dist/ /dist

RUN set -eux; \
    apk update; \
    apk add --no-cache --virtual .build-deps \
       subversion; \
    apk add \
       bash; \
    # Install taiga-front core
    unzip source.zip; \
    mv /taiga-front-dist-base /taiga; \
    mv /dist /taiga; \
    mv /conf.json.template taiga/dist/; \
    rm -f taiga/dist/conf.json; \
    chmod +x /docker-entrypoint.d/40_config_env_subst.sh; \
    # Install taiga-front contribs
    #mkdir /taiga/dist/plugins; \
    #cd /taiga/dist/plugins; \
    # Slack
    #wget https://github.com/taigaio/taiga-contrib-slack/archive/6.8.0.zip -O source.zip; \
    #unzip -j source.zip "taiga-contrib-slack-6.8.0/front/dist/*" -d slack; \
    #rm source.zip; \
    # Github
    #wget http://github.com/taigaio/taiga-contrib-github-auth/archive/6.8.0.zip -O source.zip; \
    #unzip -j source.zip "taiga-contrib-github-auth-6.8.0/front/dist/*" -d github-auth; \
    #rm source.zip; \
    # Gitlab
    #wget http://github.com/taigaio/taiga-contrib-gitlab-auth/archive/6.8.0.zip -O source.zip; \
    #unzip -j source.zip "taiga-contrib-gitlab-auth-6.8.0/front/dist/*" -d gitlab-auth; \
    #rm source.zip; \
    cd /; \
    # Remove unused dependencies
    apk del --no-cache .build-deps; \
    rm source.zip; \
    # Ready for nginx
    mv /taiga/dist/* /usr/share/nginx/html; \
    rm -rf /taiga; \