require 'pathname'
require 'rubygems'

EXAMPLES_ROOT = Pathname(__FILE__).dirname.expand_path
require EXAMPLES_ROOT.parent + 'lib/ken'

Ken::Session.new('https://www.googleapis.com/freebase/v1')

resource = Ken.get('/en/the_police')

resource.views.each do |view|
  puts view
  puts "="*20
  view.attributes.each do |a|
    puts a.property
    puts "-"*20
    puts a
    puts # newline
  end
end
