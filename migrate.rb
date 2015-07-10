#! /usr/bin/env ruby
require "dbi"

$dbh = DBI.connect("DBI:Pg:lhl")

path = File.dirname(__FILE__) + '/migrations/*.rb'

files = Dir[path]

files.sort!

migrations_table_exists = $dbh.select_one(%|SELECT COUNT(*)
  FROM pg_catalog.pg_tables
  WHERE tablename = 'migrations'|)[0]

unless migrations_table_exists > 0
  $dbh.do(
    'CREATE TABLE migrations (
      "id" SERIAL,
      "file" character varying,
      "date" integer
    );'
  )
end

files.each do |file|
  require file
  class_name = "Migration_" + File.basename(file, '.rb').gsub('-','_')
  migration = Object.const_get(class_name).new

  migrated = $dbh.select_one(%|SELECT COUNT(date)
    FROM migrations
    WHERE file = ?|, file)[0]
  if migrated == 0
    migration.up
    puts "Running migrate.up on '#{file}'."
    sth = $dbh.prepare(
      'INSERT INTO migrations (
        file,
        date
      )
      VALUES (?,?)'
    )
    sth.bind_param 1, file
    sth.bind_param 2, Time.now.utc.to_i
    sth.execute
  else
    puts "file '#{file}' already executed."
  end

end
