#!/usr/bin/env ruby

require 'colorize'
require 'net/http'
require 'uri'
require 'digest'

url = "/076207363151/vaults/Website_Backups/archives"
host = "glacier.us-west-2.amazonaws.com"
glacier_version = "2012-06-01"
date = Time.now
descr = "Backup"
sha256 = Digest::SHA256.hexdigest File.read ARGV[0]
filesize = File.open(ARGV[0]).size

if ((filesize / 1024) / 1024) > 100
	puts "File is greater than 100 MB.  Recommend multipart upload.".yellow
end

puts <<-EOF

POST #{url}
Host: #{host}
x-amz-glacier-version: #{glacier_version}
Date: #{date.year}-#{date.mon}-#{date.day}
Authorization:
x-amz-archive-description: #{descr}
x-amz-sha256-tree-hash:
x-amz-content-sha256: #{sha256}
Content-Length: #{filesize}

<Request body.>

EOF


