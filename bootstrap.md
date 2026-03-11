# bootstrap
Hvordan får en angrepet inn på clusteret, uten å avdekke Github-tokenet for verden?

## Plan
Lag et skript som kan kjøres lokalt, bootstrap.sh, som spør om github token, oppretter en public gist med hjelp av `gh gist create`, der innholdet i gist er github token, endrer gist-kommandosenter.yaml med peker til public gist, i oppstart av gist-kommandosenter.md lese github token og sletter nevnte gist.
