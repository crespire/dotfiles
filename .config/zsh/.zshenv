gbc() {
  echo "Cleaning merged branches"
  git branch --merged | grep -v 'main$' | xargs git branch -d 2>/dev/null
  
  echo "Cleaning gone branches"
  BRANCHES=`git branch -v | grep " \[gone\] "`

  if echo "$BRANCHES" | grep -q '^\*'; then
    GONE=`echo "$BRANCHES" | grep '^\*' | cut -d " " -f 2`
    echo "Currently on gone branch $GONE, exiting"
    exit
  fi

  for x in `git branch -v | grep " \[gone\] " | cut -d " " -f 3`
  do
    git br -D $x
  done
}
