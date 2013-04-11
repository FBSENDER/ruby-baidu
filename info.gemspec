Gem::Specification.new do |s|
s.name 			= %q{baidu}
s.version 		= '1.1.4'
s.authors 		= ["seoaqua"]
s.date 			= %q{2012-06-13}
s.description 	= %q{to get keyword ranking,related queries and popularity from baidu.com. this is built by a newbie, so please be careful. welcome to check my homepage, http://seoaqua.com}
s.email 		= %q{seoaqua@qq.com}
s.files			=["lib/baidu.rb"]
s.homepage 		= %q{https://github.com/seoaqua/ruby-baidu}
s.summary = s.description
s.add_runtime_dependency 'nokogiri'
s.add_runtime_dependency 'mechanize'
s.add_runtime_dependency 'addressable'
s.add_runtime_dependency 'httparty'
end
