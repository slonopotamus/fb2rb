# frozen_string_literal: true

require 'fb2rb/version'
require 'zip'

# Fiction Book 2 parser/generator library
module FB2rb
  # Book holds data of a single FB2 file
  class Book
    # Parses existing FB2 file from an IO object, and creates new Book object.
    def self.parse(filename_or_io)
      Zip::InputStream.open(filename_or_io) do |_zis|
        # TODO
        Book.new
      end
    end

    # Serializes and returns FB2 as StringIO.
    def to_ios
      Zip::OutputStream.write_buffer do |io|
        write_to_stream(io)
      end
    end

    # Writes FB2 to file or IO object. If file exists, it will be overwritten.
    def write(filename_or_io)
      if filename_or_io.respond_to?(:seek)
        Zip::OutputStream.write_buffer(filename_or_io) do |io|
          write_to_stream(io)
        end
      else
        Zip::OutputStream.open(path) do |io|
          write_to_stream(io)
        end
      end
    end

    private

    # Writes FB2 to stream specified by the argument.
    def write_to_stream(io)
      # TODO
    end
  end
end
