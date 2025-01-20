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
  s.required_ruby_version = '>= 2.6.0'

  s.files = `git ls-files`.split("\n").reject { |f| f.match(%r{^spec/}) }
  s.executables = `git ls-files -- bin/*`.split("\n").map do |f|
    File.basename(f)
  end
  s.require_paths = ['lib']

  s.add_runtime_dependency 'base64', '~> 0.2'
  s.add_runtime_dependency 'nokogiri', '>= 1.10', '< 2.0'
  s.add_runtime_dependency 'rubyzip', '>= 2.3.0', '< 3.0'

  s.add_development_dependency 'rake', '~> 13.2.0'
  s.add_development_dependency 'rspec', '~> 3.13.0'
  s.add_development_dependency 'rubocop', '~> 1.50.2'
  s.add_development_dependency 'rubocop-rake', '~> 0.6.0'
  s.add_development_dependency 'rubocop-rspec', '~> 2.20.0'
end
