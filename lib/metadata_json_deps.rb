require 'puppet_forge'
require 'puppet_metadata'

module MetadataJsonDeps
  class ForgeVersions
    def initialize(cache = {})
      @cache = cache
    end

    def get_module(name)
      name = PuppetForge::V3.normalize_name(name)
      begin
        @cache[name] ||= PuppetForge::Module.find(name)
      rescue Faraday::ResourceNotFound
        raise PuppetForge::ModuleNotFound.new("Dependency #{name} not found on forge.puppet.com")
      end
    end
  end

  def self.build_fixtures(filename)
    require 'yaml'

    result = {}

    dependencies = PuppetMetadata.read(filename).dependencies
    if dependencies.any?
      forge = ForgeVersions.new

      repositories = {}
      result['fixtures'] = {'repositories' => repositories}

      dependencies.each do |dependency, _constraint|
        mod = forge.get_module(dependency)
        # TODO: The forge should expose the source URL directly
        repositories[mod.name] = mod.current_release.metadata[:source]
      end
    end

    puts result.to_yaml
  end

  # Bump a dependency in a filename
  #
  # @param [String] filename A path to a metadata file. An error is raised if
  #   it's invalid metadata.
  # @param [String] module_name The module name listed in dependencies. It must
  #   be normalized to the forge style (using a dash). It can fall back to a
  #   slash if metadata uses a slash.
  # @param [String] upper_bound The new upper bound for the module name
  # @return [Array<String>] An array with the old and new version. Can be used
  #   to determine if a change was made.
  # @see PuppetMetadata.read
  def self.bump_dependency(filename, module_name, upper_bound)
    metadata = PuppetMetadata.read(filename)

    requirement = metadata.dependencies[module_name]
    unless requirement
      # TODO: normalize keys in puppet_metadata so we don't need 2 lookups?
      module_name = module_name.tr('-', '/')
      requirement = metadata.dependencies[module_name]
      raise Exception.new("Dependency #{module_name} not found") unless requirement
    end

    return [requirement.to_s, requirement.to_s] if requirement.end == upper_bound

    new = ">= #{requirement.begin} < #{upper_bound}"

    new_metadata = metadata.metadata.clone
    new_metadata['dependencies'].each do |dependency|
      if dependency['name'] == module_name
        dependency['version_requirement'] = new
      end
    end

    File.write(filename, JSON.pretty_generate(new_metadata) + "\n")

    [requirement.to_s, new]
  end

  # Build dependency check results for one metadata file (for pluggable formatters).
  #
  # @param [String] filename path to a metadata.json file
  # @param [ForgeVersions] forge forge client (for tests or shared cache)
  # @return [Hash] { filename: String, checks: Array<Hash> }. Each check is one of:
  #   - { type: :deprecated, name:, superseded_by:, deprecated_for: }
  #   - { type: :satisfies, name:, constraint:, current: }
  #   - { type: :unsatisfied, name:, constraint:, current: }
  def self.dependency_check_results(filename, forge)
    metadata = PuppetMetadata.read(filename)

    checks = metadata.dependencies.map do |dependency, constraint|
      mod = forge.get_module(dependency)

      if mod.deprecated_at
        {
          type: :deprecated,
          name: dependency,
          superseded_by: mod.superseded_by&.fetch(:slug, nil),
          deprecated_for: mod.deprecated_for,
        }
      else
        current = mod.current_release.version
        type = metadata.satisfies_dependency?(dependency, current) ? :satisfies : :unsatisfied
        {type: type, name: dependency, constraint: constraint.to_s, current: current}
      end
    end

    {filename: filename, name: metadata.name, checks: checks}
  end

  # Format dependency check results as text
  #
  # @param [Array[String]] filenames
  #   The filenames to run on
  # @param [ForgeVersions] forge forge client (for tests or shared cache)
  # @param [Boolean] verbose
  #   Whether or not to run in verbose mode
  # @return [Integer] the exit code  def self.format_text(filenames, forge, verbose)
  def self.format_text(filenames, forge, verbose)
    exit_code = 0

    filenames.each do |filename|
      puts "Checking #{filename}"
      results = dependency_check_results(filename, forge)
      results[:checks].each do | mod |
        if mod[:type] == :deprecated
          exit_code |= 2
          if mod[:superseded_by]
            puts "  #{mod[:name]} was superseded by #{mod[:superseded_by]}"
          elsif mod[:deprecated_for]
            puts "  #{mod[:name]} was deprecated: #{mod[:deprecated_for]}"
          else
            puts "  #{mod[:name]} was deprecated"
          end
        else
          if mod[:type] == :satisfies
            if verbose
              puts "  #{mod[:name]} (#{mod[:constraint]}) matches #{mod[:current]}"
            end
          else
            exit_code |= 1
            puts "  #{mod[:name]} (#{mod[:constraint]}) doesn't match #{mod[:current]}"
          end
        end
      end
    end

    exit_code
  end

  # @summary Run the application
  # @param [Array[String]] filenames
  #   The filenames to run on
  # @param [Boolean] verbose
  #   Whether or not to run in verbose mode
  # @return [Integer] the exit code
  def self.run(filenames, verbose = false)
    forge = ForgeVersions.new

    format_text(filenames, forge, verbose)
  rescue Interrupt
    0
  end
end
