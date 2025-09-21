# https://just.systems/man/en/

publish:
  mix hex.publish

docs:
  mix docs

outdated:
  mix hex.outdated

remove-unused-deps:
  mix deps.clean --unused 
  mix deps.clean --unlock --unused