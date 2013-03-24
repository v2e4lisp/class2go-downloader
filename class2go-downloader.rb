require "mechanize"
require "uri"

if ARGV.size < 3
  puts "coursera-downloader.rb <username> <password> <course> [section:optional]"
  exit 1
end

# parse args
puts "Parsing the arguments..."
username = ARGV[0]
password = ARGV[1]
course = ARGV[2]
course = course[1..-1] if course[0] === "/"
course.chop! if course[-1] == "/"
the_section = ARGV[3].gsub(/\s+/, "") if ARGV[3]

# initialize agent
puts "Initialize the agent..."
agent = Mechanize.new
agent.pluggable_parser.default = Mechanize::Download

# login and go to the course-materials page
# These two course is under class.stanford.edu ,
# so when login we have to change to that site .
class2go = if ["networking/Fall2012", "solar/Fall2012"].include? course then "class"
           else "class2go" end
puts "Login the Class2go..."
agent.get "https://#{class2go}.stanford.edu/accounts/login?next=/#{course}/materials"
login_form = agent.page.forms.first
login_form.username = username
login_form.password = password
login_form.submit
puts agent.page.uri

# Download all files
puts "Start downloading #{course}..."
sections = course_page.search "div.course-section"
section_names = course_page.search("h3").map do |h3| h3.text.gsub(/\s+/, "") end

sections.each do |section|
  # make a dir for each section and save download file in that dir
  dir =  section_names.shift
  next if the_section and not the_section.downcase == dir.downcase
  puts "Section : #{dir}."
  unless dir.nil?
    Dir.mkdir dir unless Dir.exists? dir
    Dir.chdir dir
  end

  section.search("div.course-list-content").each do |content|
    # get file name without extension
    filename = content.search("h4").text.gsub(/\s+/,"").gsub(/\//, "-")
    filename = filename.gsub(/\(slides\)/i, "").gsub(/\([[:digit:]]+:[[:digit:]]+\)/, "")

    content.search("a").each do |a|
      url = a.attr("href")
      if url =~ URI::regexp and url =~ /attachment/ and not url =~ /small/
        # get file extension from url
        ext = /\/.+\.(.+)\?Signature=/.match(url)
        next if ext.nil?
        filename << "." << ext[1]

        if File.exists?(filename)
          puts "Skipping #{filename} as it already exists"
        else
          puts "Downloading #{filename}..."
          begin
            agent.get(url).save filename
            puts "Finished"
          rescue Mechanize::ResponseCodeError => exception
            if exception.response_code == '403'
              puts "Failed to download #{filename} for #{exception}"
            else
              raise exception # Some other error, re-raise
            end
          end
        end
      end
    end
  end

  # get out of this direcotry and continue to download the next section
  Dir.chdir ".." if not dir.nil?
end
