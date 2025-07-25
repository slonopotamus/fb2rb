# frozen_string_literal: true

require_relative 'lib/fb2rb/version'

Gem::Specification.new do |s|
  s.name = 'fb2rb'
  s.version = FB2rb::VERSION
  s.authors = ['Marat Radchenko']
  s.email = ['marat@slonopotamus.org']
  s.summary = 'Fiction Book 2 parser/generator library'
  s.homepage = 'https://github.com/slonopotamus/fb2rb'
  s.license = 'MIT'
  s.required_ruby_version = '>= 2.7.0'

  s.files = `git ls-files`.split("\n").reject { |f| f.match(%r{^spec/}) }
  s.executables = `git ls-files -- bin/*`.split("\n").map do |f|
    File.basename(f)
  end
  s.require_paths = ['lib']

  s.add_dependency 'nokogiri', '>= 1.10', '< 2.0'
  s.add_dependency 'rubyzip', '>= 2.3.0', '< 3.0'

  s.add_development_dependency 'rake', '~> 13.3.0'
  s.add_development_dependency 'rspec', '~> 3.13.0'
  s.add_development_dependency 'rubocop', '~> 1.79.0'
  s.add_development_dependency 'rubocop-rake', '~> 0.7.1'
  s.add_development_dependency 'rubocop-rspec', '~> 3.3'
end
