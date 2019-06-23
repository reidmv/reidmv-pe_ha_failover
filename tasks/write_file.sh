#!/bin/bash

main() {
  cat <<< "$PT_content" > "$PT_path"
}

outfile=$(mktemp)
main "$@" >"$outfile" 2>&1
exit_code=$?

cat <<EOS
  {
    "output": $(python -c "import json; print json.dumps(open('$outfile','r').read())"),
    "exit-code": $?
  }
EOS

rm "$outfile"
