# create/populate base dir for each host
while read host
do
  for dir in "raw" "files" "workspace"
  do
    mkdir -p targets/${host}/${dir}
  done

  for file in "walkthrough.md" "notes.md"
  do
    touch targets/${host}/${file}
  done

  for symlink in "sec-lists" "common" "exploits"
  do
    ln -s $( pwd )/${symlink} targets/${host}/${symlink}
  done
done < hosts
