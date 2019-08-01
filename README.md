# curatescape_utility
A bash script for adding/updating [Curatescape](https://curatescape.org) tools on an existing [Omeka](https://omeka.org/classic) installation

# how to use it
Upload the `curatescape_utility.sh` file to your server (manually or with something like...) 
```
$ wget https://raw.githubusercontent.com/ebellempire/curatescape_utility/master/curatescape_utility.sh
```
Then just run it like any shell script, including one or more arguments indicating the location of the installation(s)
```
$ sh curatescape_utility.sh path/to/omeka
$ sh curatescape_utility.sh path/to/omeka another/path/to/omeka
```

# what it does
The script creates a new folder in your `~`home directory called `curatescape_utility` and into that pulls the latest tagged versions of [all required and optional](https://github.com/CPHDH/Curatescape#server-side-setup) Curatescape plugins, as well as the Curatescape theme (if any of the repos already exist there, it will check for updates). Then the script will copy the most recent theme and plugin versions (sans `.git` files) to where they need to go in the Omeka installation(s) you included as arguments (to verify if an argument is a valid path to Omeka, we just look for the `bootstrap.php` file and make sure it includes the string `OMEKA_VERSION`). The output while it's processing is useful but minimal. When it's done, it prints out a basic summary, just to let you know if it skipped something that didn't appear to be a valid Omeka installation. That's it. 

# what it doesn't do
The script does not install Omeka. It does not upgrade Omeka. It does not backup your database. Those are all things your hosting provider probably already does (or can do) for you or for which there are plenty of other options. 
