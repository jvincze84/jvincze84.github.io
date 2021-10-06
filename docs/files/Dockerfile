FROM python:3-alpine

ARG USER=1001

RUN adduser -h /usr/src/mkdocs -D -u $USER mkdocs \
&& apk add bash \
&& apk add git

ENV PATH="${PATH}:/usr/src/mkdocs/.local/bin"

USER mkdocs

WORKDIR /usr/src/mkdocs

RUN pip install pymdown-extensions \
&& pip install mkdocs \
&& pip install mkdocs-material \
&& pip install mkdocs-rtd-dropdown

ENTRYPOINT ["/usr/src/mkdocs/.local/bin/mkdocs"]
