# curatescape_utility

A bash script for adding/updating [Curatescape](https://curatescape.org) tools on an existing [Omeka](https://omeka.org/classic) installation

# how to use it

Upload the `curatescape_utility.sh` file to your server (manually or with something like...):

```
$ wget https://raw.githubusercontent.com/ebellempire/curatescape_utility/master/curatescape_utility.sh
```

Then just run it like any shell script, including one or more arguments indicating the location of the installation(s):

```
$ bash curatescape_utility.sh path/to/omeka
$ bash curatescape_utility.sh path/to/omeka another/path/to/omeka
```

# what it does

The script creates a new folder in your `~` home directory called `curatescape_utility` and into that pulls [all required and optional](https://github.com/CPHDH/Curatescape#server-side-setup) Curatescape plugins, as well as the Curatescape themes (if any of the repos already exist there, it will check for updates). Then the script will copy the theme and plugin files (sans `.git` files) to where they need to go in the Omeka installation(s) you included as arguments (to verify if an argument is a valid path to Omeka, we just look for the `bootstrap.php` file and make sure it includes the string `OMEKA_VERSION`). The output while it's processing is useful but minimal. When it's done, it prints out a basic summary, just to let you know if it skipped something that didn't appear to be a valid Omeka installation. That's it.

By default each repo is checked out at its latest GitHub release. You can customize this per-repo in the `GITHUB_REPOS_PLUGINS` and `GITHUB_REPOS_THEMES` arrays using an `@ref` suffix:

```
CPHDH/Curatescape          # defaults to latest release
CPHDH/Curatescape@latest   # same as above, explicit
CPHDH/Curatescape@master   # track a branch
CPHDH/Curatescape@1.0      # pin to a specific tag
```

# what it doesn't do

The script does not install Omeka. It does not upgrade Omeka. It does not backup your database. Those are all things your hosting provider probably already does (or can do) for you or for which there are plenty of other options.

# maintenance

Repos are cloned shallowly (`--depth 1`) to minimize memory usage and download size, so the `curatescape_utility` working directory stays relatively small. If you ever need to start fresh, just run `rm -rf curatescape_utility` and the script will re-clone everything on the next run.
