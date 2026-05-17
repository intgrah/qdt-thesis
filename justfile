build: metrics
    typst compile main.typ

watch:
    typst watch main.typ

metrics:
    ./metrics.fish

clean:
    rm -f main.pdf
