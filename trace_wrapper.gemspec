require 'English'

require File.expand_path('lib/trace_wrapper/version', __dir__)

Gem::Specification.new do |s|
  s.name = 'trace_wrapper'
  s.version = TraceWrapper::VERSION
  s.license = 'Hippocratic-2.1'
  s.summary = 'TraceWrapper outputs method call and returns for a class'
  s.description = 'Wrap the methods of a class or module to output call info.

  See a tree of calls made to wrapped methods with argument values and return
  values.'
  s.authors = ['Bill Ruddock']

  s.files = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  s.test_files = s.files.grep(%r{test/})
  s.require_paths = ['lib']

  s.homepage = 'https://github.com/biinari/trace_wrapper'
  s.metadata = {
    'source_code_uri' => 'https://github.com/biinari/trace_wrapper'
  }
  s.rdoc_options << '--main' << 'README.md'
  s.extra_rdoc_files = ['README.md']

  s.add_development_dependency 'minitest', '~> 5.14'
  s.add_development_dependency 'rake', '~> 13.0'
  s.add_development_dependency 'rubocop', '~> 0.80.1'
end
