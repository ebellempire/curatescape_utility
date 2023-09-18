# curatescape_utility

A bash script for adding/updating [Curatescape](https://curatescape.org) tools on an existing [Omeka](https://omeka.org/classic) installation

# how to use it

Upload the `curatescape_utility.sh` file to your server (manually or with something like...):

```
$ wget https://raw.githubusercontent.com/ebellempire/curatescape_utility/master/curatescape_utility.sh
```

Then just run it like any shell script, including one or more arguments indicating the location of the installation(s):

```
$ sh curatescape_utility.sh path/to/omeka
$ sh curatescape_utility.sh path/to/omeka another/path/to/omeka
```
Depending on your server configuration, you may need to use the following syntax instead:
```
$ bash ./curatescape_utility.sh arlingtonhistorical.com path/to/omeka
```

# what it does

The script creates a new folder in your `~` home directory called `curatescape_utility` and into that pulls the latest tagged versions of [all required and optional](https://github.com/CPHDH/Curatescape#server-side-setup) Curatescape plugins, as well as the Curatescape theme (if any of the repos already exist there, it will check for updates). Then the script will copy the most recent theme and plugin versions (sans `.git` files) to where they need to go in the Omeka installation(s) you included as arguments (to verify if an argument is a valid path to Omeka, we just look for the `bootstrap.php` file and make sure it includes the string `OMEKA_VERSION`). The output while it's processing is useful but minimal. When it's done, it prints out a basic summary, just to let you know if it skipped something that didn't appear to be a valid Omeka installation. That's it.

# what it doesn't do

The script does not install Omeka. It does not upgrade Omeka. It does not backup your database. Those are all things your hosting provider probably already does (or can do) for you or for which there are plenty of other options.

# notes

This script assumes that the default branch for all repositories is called "master." You should be able to add additional themes and plugins here, but they'll _all_ need to have a `master` branch. If your repo's default branch is `main` (or something else), you'll need to update the script to handle that. So far, I haven't had a reason to do so. Pull requests welcome.

This script also assumes that your theme repositories will be structured like the two default Curatescape themes, i.e. where the actual theme directory sits inside the root directory, next to the .git file (e.g. _theme-curatescape/curatescape/_). This is another limitation I haven't had occasion to address. If your theme repo is not structured in this manner, you'll need to update the script. Pull requests welcome.

This script _also_ assumes the latest tag corresponds to the latest production release. Again, pull requests welcome.

You might want to occasionally remove the `curatescape_utlity` directory, which can get pretty big from always checking out the latest tag. Just run `rm -rf curatescape_utlity` as needed.
