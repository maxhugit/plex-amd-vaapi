# Plex AMD VAAPI pour Radeon 890M

Image expérimentale basée sur `lscr.io/linuxserver/plex`, complétée avec un
pilote VAAPI AMD construit pour la bibliothèque `musl` employée par Plex
Transcoder.

Le projet reprend le diagnostic publié par
[`grio-co/plex-amd-vaapi`](https://github.com/grio-co/plex-amd-vaapi). La
différence principale est l'utilisation de Mesa 25, afin de prendre en charge
les GPU AMD récents comme la Radeon 890M, tout en compilant sur Alpine 3.15
pour conserver la compatibilité avec `musl 1.2.2`.

## Image

```text
ghcr.io/maxhugit/plex-amd-vaapi:latest
```

Le workflow GitHub Actions construit et publie automatiquement une image
`linux/amd64` à chaque modification de la branche `main` et une fois par mois.

## Paramètres requis dans Unraid

Conserver les volumes et paramètres du conteneur Plex existant, puis utiliser :

- Repository : `ghcr.io/maxhugit/plex-amd-vaapi:latest`
- Device : `/dev/dri` vers `/dev/dri`
- Variable : `LIBVA_DRIVERS_PATH=/opt/vaapi/dri`
- Variable : `LIBVA_DRIVER_NAME=radeonsi`
- Variable LinuxServer habituelle : `VERSION=docker`

Ne jamais créer un nouveau dossier `/config` pour le test : le conteneur doit
continuer d'utiliser le dossier appdata Plex existant.

## Test avant migration

Il est recommandé de télécharger l'image puis de lancer un conteneur de test
sans monter la configuration Plex. Une fois le pilote validé, le modèle Unraid
peut être modifié et recréé avec les volumes existants.

Dans Plex, activer **Utiliser l'accélération matérielle si disponible**. Une
lecture distante nécessitant un transcodage doit ensuite afficher
`Transcode (hw)`. Dans les journaux, l'encodeur attendu est `h264_vaapi` et non
`libx264`.

## Retour arrière

Remettre simplement le dépôt Docker du modèle Unraid sur :

```text
lscr.io/linuxserver/plex
```

Les données Plex restent dans `/config` et ne sont pas intégrées à l'image.

## Avertissement

Cette image n'est affiliée ni à Plex, ni à LinuxServer.io. Le transcodage AMD
sous Plex Linux reste moins officiellement pris en charge que les solutions
Intel ou NVIDIA. Tester l'image avant de remplacer le conteneur de production.
