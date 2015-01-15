wimgs - Wiki images downloader
=====

Usage: 

1. To dump all images for a set of articles with titles listed in UTF-8 in <fname> (one per line), from Wiki <wiki>, to directory <dumpdir>:

 ruby wimgs.rb --wiki <wiki> --articles <fname> --images-dir <dumpdir>
 Example: wimgs --wiki en.wikipedia.org --articles my_favorite_articles.txt --images-dir /home/moose/dump/images 
 Example with abbreviated options: wimgs -w en.wikipedia.org -i my_favorite_articles.txt -d /home/moose/dump/images

 --images-dir defaults to './images'

2. To dump all images of a particular category on Commons, use --category instead of --articles:

 ruby wimgs.rb --wiki commons.wikimedia.org --category "Images from Wiki Loves Africa 2014 in Ghana" --images-dir /home/moose/wlm_gh/images
 
3. To NOT download the full/original resolution, but a given width, specify the maximum width using --width:

 wimgs --wiki tr.wikipedia.org --articles my_favorite_turkish_articles.txt --width 800

4. To NOT resume an interrupted dump, add the --no-resume (or -r) argument

5. To only check and show the status of a dump, add the --status (or -s) argument.  Nothing will be downloaded.

NOTE: wimgs will create a sqlite3 database in the current working directory named wimgs.db.  If the database already exists, wimgs will attempt to resume the dump unless instructed not to, in which case the database will be recreated and any existing image files overwritten.

