build:
    typst compile main.typ

watch:
    typst watch main.typ

# Sort of like texcount
wordcount:
    @find chapters/01-introduction chapters/02-preparation chapters/03-implementation chapters/04-evaluation chapters/05-conclusion.typ \
        -name '*.typ' -print0 \
        | xargs -0 cat \
        | sed '/^```/,/^```/d' \
        | sed '/^#figure/,/^)/d' \
        | sed '/^#table/,/^)/d' \
        | sed '/^#align/,/^)/d' \
        | sed 's/\$[^$]*\$//g' \
        | sed '/^\$/,/^\$/d' \
        | sed 's/#include.*//g' \
        | sed 's/#import.*//g' \
        | sed 's/@[a-zA-Z0-9_]*//g' \
        | sed 's/`[^`]*`//g' \
        | sed '/^$/d' \
        | wc -w

# Raw pdftotext
wordcount-raw:
    typst compile count.typ count.pdf
    @pdftotext count.pdf - \
        | sed '/^Bibliography$/,$d' \
        | wc -w

clean:
    rm -f main.pdf count.pdf
