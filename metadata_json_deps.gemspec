Gem::Specification.new do |s|
  s.name        = 'metadata_json_deps'
  s.version     = '2.0.0'
  s.licenses    = ['MIT']
  s.summary     = 'Check your Puppet metadata dependencies'
  s.description = 'Verify all your dependencies allow the latest versions on Puppet Forge'
  s.authors     = ['Ewoud Kohl van Wijngaarden']
  s.email       = 'ewoud+rubygems@kohlvanwijngaarden.nl'
  s.files       = Dir['lib/**/*.rb'] + Dir['bin/*'] + ['LICENSE']
  s.extra_rdoc_files = ['README.md']
  s.homepage    = 'https://github.com/ekohl/metadata_json_deps'
  s.metadata    = { 'source_code_uri' => 'https://github.com/ekohl/metadata_json_deps' }
  s.executables << 'bump-dependency-upper-bound'
  s.executables << 'generate-fixtures-yaml'
  s.executables << 'metadata-json-deps'

  # puppet_forge 6 requires Ruby 3.1
  s.required_ruby_version = '>= 3.1'

  s.add_runtime_dependency 'puppet_forge', '~> 6.0'
  s.add_runtime_dependency 'puppet_metadata', '>= 0.3.0', '< 6'

  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'rake', '~> 13.0'
end
