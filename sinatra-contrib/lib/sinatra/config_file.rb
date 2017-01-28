require 'sinatra/base'
require 'yaml'
require 'erb'

module Sinatra

  # = Sinatra::ConfigFile
  #
  # <tt>Sinatra::ConfigFile</tt> is an extension that allows you to load the
  # application's configuration from YAML files.  It automatically detects if
  # the files contain specific environment settings and it will use those
  # corresponding to the current one.
  #
  # You can access those options through +settings+ within the application. If
  # you try to get the value for a setting that hasn't been defined in the
  # config file for the current environment, you will get whatever it was set
  # to in the application.
  #
  # == Usage
  #
  # Once you have written your configurations to a YAML file you can tell the
  # extension to load them.  See below for more information about how these
  # files are interpreted.
  #
  # For the examples, lets assume the following config.yml file:
  #
  #     greeting: Welcome to my file configurable application
  #
  # === Classic Application
  #
  #     require "sinatra"
  #     require "sinatra/config_file"
  #
  #     config_file 'path/to/config.yml'
  #
  #     get '/' do
  #       @greeting = settings.greeting
  #       haml :index
  #     end
  #
  #     # The rest of your classic application code goes here...
  #
  # === Modular Application
  #
  #     require "sinatra/base"
  #     require "sinatra/config_file"
  #
  #     class MyApp < Sinatra::Base
  #       register Sinatra::ConfigFile
  #
  #       config_file 'path/to/config.yml'
  #
  #       get '/' do
  #         @greeting = settings.greeting
  #         haml :index
  #       end
  #
  #       # The rest of your modular application code goes here...
  #     end
  #
  # === Config File Format
  #
  # In its most simple form this file is just a key-value list:
  #
  #     foo: bar
  #     something: 42
  #     nested:
  #       a: 1
  #       b: 2
  #
  # But it also can provide specific environment configuration.  There are two
  # ways to do that: at the file level and at the settings level.
  #
  # At the settings level (e.g. in 'path/to/config.yml'):
  #
  #     development:
  #       foo: development
  #       bar: bar
  #     test:
  #       foo: test
  #       bar: bar
  #     production:
  #       foo: production
  #       bar: bar
  #
  # Or at the file level:
  #
  #     foo:
  #       development: development
  #       test: test
  #       production: production
  #     bar: bar
  #
  # In either case, <tt>settings.foo</tt> will return the environment name, and
  # <tt>settings.bar</tt> will return <tt>"bar"</tt>.
  #
  # If you wish to provide defaults that may be shared among all the
  # environments, this can be done by using a YAML alias, and then overwriting
  # values in environments where appropriate:
  #
  #     default: &common_settings
  #       foo: 'foo'
  #       bar: 'bar'
  #
  #     production:
  #       <<: *common_settings
  #       bar: 'baz' # override the default value
  #
  module ConfigFile

    # When the extension is registered sets the +environments+ setting to the
    # traditional environments: development, test and production.
    def self.registered(base)
      base.set :environments, %w[test production development]
    end

    # Loads the configuration from the YAML files whose +paths+ are passed as
    # arguments, filtering the settings for the current environment.  Note that
    # these +paths+ can actually be globs.
    def config_file(*paths)
      Dir.chdir(root || '.') do
        paths.each do |pattern|
          Dir.glob(pattern) do |file|
            raise UnsupportedConfigType unless ['.yml', '.erb'].include?(File.extname(file))
            logger.info "loading config file '#{file}'" if logging? && respond_to?(:logger)
            document = ERB.new(IO.read(file)).result
            yaml = config_for_env(YAML.load(document))
            yaml.each_pair { |key, value| set(key, value) }
          end
        end
      end
    end

    class UnsupportedConfigType < Exception
      def message
        'Invalid config file type, use .yml or .yml.erb'
      end
    end

    private

    # Given a +hash+ with some application configuration, returns the settings
    # applicable to the current +environment+.
    def config_for_env(config)
      return config[environment.to_s] || {} if has_environment_keys?(config)

      config.each_with_object({}) do |(key, value), acc|
        value = value[environment.to_s] if has_environment_keys?(value)
        acc.merge!(key => with_indifferent_access(value)) unless value.nil?
      end
    end

    # Returns true if supplied with a hash that has any recognized
    # +environments+ in it's root keys.
    def has_environment_keys?(hash)
      return false unless hash.is_a?(Hash)

      hash.keys.map(&:to_s).any? { |k| environments.include?(k) }
    end

    # Returns a hash that can be accessed by both strings and symbols, when
    # supplied with a hash with string keys.
    def with_indifferent_access(hash)
      return hash unless hash.is_a?(Hash)

      Hash.new { |h, key| h[key.to_s] if Symbol === key }.merge(hash)
    end
  end

  register ConfigFile
  Delegator.delegate :config_file
end
