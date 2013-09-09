#!/usr/bin/env ruby
#
# wimgs - Wiki images bulk downloader
#
# developed and maintained by Asaf Bartov <asaf.bartov@gmail.com>
#
# tested on Ruby 2.0.  Should work on 1.9.3 as well.

require 'rubygems'
require 'getoptlong'
require 'media_wiki'
require 'sqlite3'

VERSION = "0.1 2013-09-08"
NONE = 1
PARTIAL = 2
DONE = 3
MISSING = 4
UNREACHABLE = 5

def usage
  puts <<-EOF
wimgs - Wiki images bulk downloader - version #{VERSION}

Usage: 

1. To dump all images for a set of articles with titles listed in UTF-8 in <fname> (one per line), from Wiki <wiki>, to directory <dumpdir>:

 wimgs --wiki <wiki> --articles <fname> --images-dir <dumpdir>
 Example: wimgs --wiki en.wikipedia.org --articles my_favorite_articles.txt --images-dir /home/moose/dump/images 
 Example with abbreviated options: wimgs -w en.wikipedia.org -i my_favorite_articles.txt -d /home/moose/dump/images

 --images-dir defaults to './images'

2. To NOT resume an interrupted dump, add the --no-resume (or -r) argument

3. To only check and show the status of a dump, add the --status (or -s) argument.  Nothing will be downloaded.

NOTE: wimgs will create a sqlite3 database in the current working directory named wimgs.db.  If the database already exists, wimgs will attempt to resume the dump unless instructed not to, in which case the database will be recreated and any existing image files overwritten.

To report issues or contribute to the code, see http://github.com/abartov/wimgs
  EOF
  exit
end

# main
cfg = { :list => nil, :imgdir => './images', :resume => true, :status => false, :wiki => nil }

opts = GetoptLong.new(
  [ '--help', '-h', GetoptLong::NO_ARGUMENT ],
  [ '--articles', '-i', GetoptLong::REQUIRED_ARGUMENT],
  [ '--images-dir', '-d', GetoptLong::REQUIRED_ARGUMENT],
  [ '--no-resume', '-r', GetoptLong::NO_ARGUMENT],
  [ '--status', '-s', GetoptLong::NO_ARGUMENT],
  [ '--wiki', '-w', GetoptLong::REQUIRED_ARGUMENT]
)

opts.each {|opt, arg|
  case opt
    when '--help'
      usage
    when '--articles'
      cfg[:list] = arg
    when '--wiki'
      cfg[:wiki] = arg
    when '--status'
      cfg[:status] = true
    when '--no-resume'
      cfg[:resume] = false
    when '--images-dir'
      cfg[:imgdir] = arg
  end
}

usage if cfg[:wiki].nil? or cfg[:list].nil?  # check args, print usage

print "reading article list... "
articles = File.open(cfg[:list], 'r:UTF-8').read.split "\n" # read article list
print "done!\nChecking database status... "
# initialize resources
mw = MediaWiki::Gateway.new("http://#{cfg[:wiki]}/w/api.php")
db = SQLite3::Database.new "wimgs.db"
db.results_as_hash = true
articles_exists = !(db.get_first_row("SELECT * FROM sqlite_master WHERE name ='articles' and type='table';").nil?)
images_exists = !(db.get_first_row("SELECT * FROM sqlite_master WHERE name = 'images' and type='table';").nil?)
unless articles_exists && images_exists && cfg[:resume] == true # if either table is missing, no meaningful work has been done or is recoverable
  # clobber everything and start afresh
  begin
    db.execute("DROP TABLE articles;")
  rescue
  end
  begin
    db.execute("DROP TABLE images;")
  rescue
  end
  db.execute("CREATE TABLE articles (id integer primary key autoincrement, title varchar(1000), status int);")
  db.execute("CREATE TABLE images (id integer primary key autoincrement, article_id int, filename varchar(1000), status int, filepath varchar(1000))")
  puts "Empty database created."
end

# check dump status
articles_count = db.execute("SELECT COUNT(id) FROM articles")[0]['COUNT(id)']
if articles_count != articles.length # stale DB, try to complement it from current list and weed out stale rows
  print "stale database!\nAdding articles from list, removing articles no longer on list, preserving status of existing article rows... "
  db.execute("SELECT id, title FROM articles") do |row|
    puts "DBG: title: #{row['title']}"
    unless articles.include?(row['title']) 
      db.execute("DELETE FROM articles WHERE id = #{row['id']}") # delete DB row if not in current list
      db.execute("DELETE FROM images WHERE article_id = #{row['id']}")
    else
      articles.delete(row['title']) # exists in DB, remove from list to leave only ones needing to be added
    end
  end
  articles.each {|a| # add missing articles to DB
   db.execute("INSERT INTO articles VALUES (NULL, ?, ?)", a, NONE)
  }
  puts "done!"
else
  puts "articles table okay... "
end
articles_count = db.execute("SELECT COUNT(id) FROM articles")[0]['COUNT(id)']
none_count = db.execute("SELECT COUNT(id) FROM articles WHERE status = ?", NONE)[0]['COUNT(id)']
partial_count = db.execute("SELECT COUNT(id) FROM articles WHERE status = ?", PARTIAL)[0]['COUNT(id)']
done_count = db.execute("SELECT COUNT(id) FROM articles WHERE status = ?", DONE)[0]['COUNT(id)']
puts "Stats: #{articles_count} total, #{done_count} done, #{partial_count} partial, #{none_count} not started."

exit if cfg[:status] # in which case we're done! :)

# collect image file names through Mediawiki API
puts "Completing image lists for #{none_count} articles and storing image file names in DB..."
db.execute("SELECT id, title FROM articles WHERE status = ?", 1) do |row|
  imgs = mw.images(row['title'])
  unless imgs.nil?
    imgs.each do |img|
      db.execute("INSERT INTO images VALUES (NULL, ?, ?, ?, NULL)", row['id'], img, NONE)
    end
    db.execute("UPDATE articles SET status = ? WHERE id = ?", PARTIAL, row['id']) 
    puts("Noted #{imgs.length} images in article #{row['title']}")
  else
    db.execute("UPDATE articles SET status = ? WHERE id = ?", DONE, row['id'])
    puts("No images in article #{row['title']}")
  end
end
puts '-='*3 + Time.now.to_s + '-='*20
puts 'populated database with image names for all articles in the list!'
puts '-='*35

# TODO: download remaining items, marking status after every download

images_count = db.execute("SELECT COUNT(id) FROM images")[0]['COUNT(id)']
none_count = db.execute("SELECT COUNT(id) FROM images WHERE status = ?", NONE)[0]['COUNT(id)']
done_count = db.execute("SELECT COUNT(id) FROM images WHERE status = ?", DONE)[0]['COUNT(id)']
missing_count = db.execute("SELECT COUNT(id) FROM images WHERE status = ?", MISSING)[0]['COUNT(id)']
puts "of #{images_count} known images:\n  #{done_count} have been downloaded\n  #{missing_count} were not found when we tried\n  #{none_count} are yet to be downloaded."
db.execute("SELECT id, title FROM articles WHERE status <> ?", DONE) do |article|
  # TODO: attempt to retrieve all non-missing images
  # TODO: update article status
end

# TODO: finalize DB, report results

puts "wimgs done!"

