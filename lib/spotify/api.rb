module Spotify
  # API is the class which has all libspotify functions attached.
  #
  # All functions are attached as both instance methods and class methods, mainly
  # because that’s how FFI works it’s magic with attach_function. However, as this
  # is a class it allows to be instantiated.
  #
  # @note The API is private because this class is an implementation detail.
  #
  # @note You should never call any Spotify::API.method() directly, but instead
  #       you should call them via Spotify.method(). libspotify is not thread-safe,
  #       but it is documented to be okay to call the API from multiple threads *if*
  #       you only call one function at a time, which is ensured by the lock in the
  #       Spotify module.
  #
  # @api private
  class API
    extend FFI::Library

    begin
      ffi_lib [LIBSPOTIFY_BIN, 'spotify', 'libspotify', '/Library/Frameworks/libspotify.framework/libspotify']
      ffi_convention :stdcall if FFI::Platform.windows?
    rescue LoadError
      $stderr.puts <<-ERROR.gsub(/^ */, '')
        Failed to load the `libspotify` library. It is possible that the libspotify gem
        does not exist for your platform, in which case you'll need to install it manually.

        For manual installation instructions, please see:
          https://github.com/Burgestrand/Hallon/wiki/How-to-install-libspotify
      ERROR
      raise
    end

    # Overloaded to ensure all methods are defined as blocking,
    # and they return a managed pointer with the correct refcount.
    #
    # @param [#to_s] name function name sans `sp_` prefix.
    # @param [Array] args
    # @param [Object] returns
    def self.attach_function(c_name = nil, name, args, returns, &block)
      if returns.respond_to?(:retaining_class) && name !~ /create/
        returns = returns.retaining_class
      end

      options  = { blocking: true }
      name = name.to_sym
      c_name ||= :"sp_#{name}"
      super(name, c_name, args, returns, options)

      if block_given?
        alias_method c_name, name
        define_method name, &block

        singleton_class.instance_eval do
          alias_method c_name, name
          define_method name, &block
        end

        name
      end
    end

    helpers = Module.new do
      module_function

      def with_buffer(type, options = {})
        size = options.fetch(:size, 1)
        clear = options.fetch(:clear, false)

        if size > 0
          FFI::MemoryPointer.new(type, size, clear) do |buffer|
            return yield buffer, buffer.size
          end
        end
      end

      def with_string_buffer(length, *args)
        if length > 0
          with_buffer(:char, size: length + 1) do |buffer, size|
            error = yield buffer, size

            if error.is_a?(Symbol) and error != :ok
              ""
            else
              buffer.get_string(0, length).force_encoding(Encoding::UTF_8)
            end
          end
        else
          ""
        end
      end
    end

    singleton_class.send(:include, helpers)
    include helpers
  end
end

require 'spotify/data_converters'
require 'spotify/types'
require 'spotify/structs'

require 'spotify/api/miscellaneous'
require 'spotify/api/album'
require 'spotify/api/album_browse'
require 'spotify/api/artist'
require 'spotify/api/artist_browse'
require 'spotify/api/error'
require 'spotify/api/image'
require 'spotify/api/inbox'
require 'spotify/api/link'
require 'spotify/api/playlist'
require 'spotify/api/playlist_container'
require 'spotify/api/search'
require 'spotify/api/session'
require 'spotify/api/toplist_browse'
require 'spotify/api/track'
require 'spotify/api/user'
