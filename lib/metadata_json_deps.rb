require 'json'
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

  # @summary Run the application
  # @param [Array[String]] filenames
  #   The filenames to run on
  # @param [Boolean] verbose
  #   Whether or not to run in verbose mode
  # @param [Symbol] format
  #   :text or :json
  # @return [Integer] the exit code
  def self.run(filenames, verbose = false, format: :text)
    forge = ForgeVersions.new

    exit_code = 0
    json = format.to_sym == :json
    doc = {'files' => []} if json

    filenames.each do |filename|
      unless json
        puts "Checking #{filename}"
      end
      metadata = PuppetMetadata.read(filename)
      file_entry = json ? {'path' => filename, 'dependencies' => []} : nil

      metadata.dependencies.each do |dependency, constraint|
        mod = forge.get_module(dependency)

        if mod.deprecated_at
          exit_code |= 2
          if json
            dep = {'name' => dependency, 'version_requirement' => constraint.to_s, 'status' => 'deprecated'}
            dep['superseded_by'] = mod.superseded_by[:slug] if mod.superseded_by
            dep['deprecated_for'] = mod.deprecated_for if mod.deprecated_for
            file_entry['dependencies'] << dep
          elsif mod.superseded_by
            puts "  #{dependency} was superseded by #{mod.superseded_by[:slug]}"
          elsif mod.deprecated_for
            puts "  #{dependency} was deprecated: #{mod.deprecated_for}"
          else
            puts "  #{dependency} was deprecated"
          end
        else
          current = mod.current_release.version

          if metadata.satisfies_dependency?(dependency, current)
            if json
              file_entry['dependencies'] << {
                'name' => dependency,
                'version_requirement' => constraint.to_s,
                'status' => 'satisfies',
                'current_release' => current,
              }
            elsif verbose
              puts "  #{dependency} (#{constraint}) matches #{current}"
            end
          else
            exit_code |= 1
            if json
              file_entry['dependencies'] << {
                'name' => dependency,
                'version_requirement' => constraint.to_s,
                'status' => 'unsatisfied',
                'current_release' => current,
              }
            else
              puts "  #{dependency} (#{constraint}) doesn't match #{current}"
            end
          end
        end
      end

      doc['files'] << file_entry if json
    end

    puts JSON.pretty_generate(doc) if json

    exit_code
  rescue Interrupt
    0
  end
end
