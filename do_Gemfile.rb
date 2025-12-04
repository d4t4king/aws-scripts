#!/usr/bin/env ruby

def package_installed?(gem_name)
  package_name = "ruby-#{gem_name}"
  system("dpkg -l | grep -q '^ii  #{package_name}'")
  $?.success?
end

# puts "Welcome to the Gemfile processor.  Popular, modern linux package implementations"
# puts "seem to want to manage language modules via package managers, rather than bundler."
# puts "This script will read the Gemfile in the lcoal directory and attempt to install the "
# puts "ruby gems specified in the Gemfile."

file_path = "./Gemfile"
if File.exist?(file_path)
    contents = File.read(file_path)
else
    puts "No Gemfile found in the current directory."
    exit 1
end

for each_line in contents.lines
    each_line.chomp!
    next if each_line.start_with?("#") || each_line.strip.empty?
    next if each_line.start_with?("source")
    match = each_line.match(/^gem\s+(\w+?)$/)
    if match
        # puts match.inspect
        gem_name = match[1]
        # puts "Installing gem: #{gem_name}"
        if ! package_installed?(gem_name)
            system("apt-get -q -y install ruby-#{gem_name}")
        else
            puts "Package ruby-#{gem_name} is already installed."
        end
        # puts "Simulated command: apt -qq -y install ruby-#{gem_name}"
    else
        puts "Unable to determine gem name from line: #{each_line}"
        # puts "Couldn't match regular expression against line: |#{each_line}|"
    end
end
