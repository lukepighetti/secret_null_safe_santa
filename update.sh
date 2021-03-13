git add .
git stash
dart bin/tools.dart
git add .
git commit -m 'update'
git push
git stash pop