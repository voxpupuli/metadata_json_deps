Gem::Specification.new do |s|
  s.name        = 'metadata_json_deps'
  s.version     = '2.1.0'
  s.licenses    = ['MIT']
  s.summary     = 'Check your Puppet metadata dependencies'
  s.description = 'Verify all your dependencies allow the latest versions on Puppet Forge'
  s.authors     = ['Ewoud Kohl van Wijngaarden', 'Vox Pupuli']
  s.email       = 'voxpupuli@groups.io'
  s.files       = Dir['lib/**/*.rb'] + Dir['bin/*'] + ['LICENSE']
  s.extra_rdoc_files = ['README.md']
  s.homepage    = 'https://github.com/voxpupuli/metadata_json_deps'
  s.metadata    = { 'source_code_uri' => 'https://github.com/ekohl/metadata_json_deps' }
  s.executables << 'bump-dependency-upper-bound'
  s.executables << 'generate-fixtures-yaml'
  s.executables << 'metadata-json-deps'

  # puppet_forge 6 requires Ruby 3.1
  s.required_ruby_version = '>= 3.1'

  s.add_runtime_dependency 'puppet_forge', '~> 6.0'
  s.add_runtime_dependency 'puppet_metadata', '>= 0.3.0', '< 6'
  # dependency for puppet_forge, see https://github.com/puppetlabs/forge-ruby/pull/129
  s.add_runtime_dependency 'base64', '>= 0.2', '< 0.4'

  s.add_development_dependency 'rspec', '~> 3.0'
  s.add_development_dependency 'rake', '~> 13.0'
end
