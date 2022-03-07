docker run -p 8000:8000 -it -v /storage/janos.vincze/xTemp/20210929/mkdocs/build:/build a8008ec9e732 mkdocs serve --config-file /build/mkdocs.yml -a 0.0.0.0:8000

docker run -p 8000:8000 -it --rm -v /tmp/jvincze84.github.io:/usr/src/mkdocs/build \
registry-ui.vincze.work/mkdocs/mkdocs-build:2.11 \
serve -a 0.0.0.0:8000


