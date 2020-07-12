# frozen_string_literal: true

require 'fb2rb/version'
require 'nokogiri'
require 'zip'

# Fiction Book 2 parser/generator library
module FB2rb
  FB2_NAMESPACE = 'http://www.gribuser.ru/xml/fictionbook/2.0'

  # Holds data of a single FB2 file
  class Book
    attr_reader(:binaries)
    attr_reader(:bodies)
    attr_reader(:description)

    def initialize(description = Description.new, bodies = [], binaries = [])
      @binaries = binaries
      @bodies = bodies
      @description = description
    end

    # Reads existing FB2 file from an IO object, and creates new Book object.
    def self.read(filename_or_io)
      Zip::InputStream.open(filename_or_io) do |zis|
        while (entry = zis.get_next_entry)
          next if entry.directory?

          xml = Nokogiri::XML::Document.parse(zis)
          fb2_prefix = xml.namespaces.key(FB2rb::FB2_NAMESPACE)
          return parse(xml, fb2_prefix)
        end
      end
    end

    def self.parse(xml, fb2_prefix)
      Book.new(
        Description.parse(xml.xpath("/#{fb2_prefix}:FictionBook/#{fb2_prefix}:description"), fb2_prefix),
        xml.xpath("/#{fb2_prefix}:FictionBook/#{fb2_prefix}:body").map(&:to_s),
        xml.xpath("#{fb2_prefix}:FictionBook/#{fb2_prefix}:binary").map do |binary|
          Binary.parse(binary)
        end
      )
    end

    def add_binary(name, filename_or_io, content_type = nil)
      if filename_or_io.respond_to?(:read)
        add_binary_io name, filename_or_io, content_type
      else
        File.open(filename_or_io, 'r') do |io|
          add_binary_io name, io, content_type
        end
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
      if filename_or_io.respond_to?(:write)
        Zip::OutputStream.write_buffer(filename_or_io) do |zos|
          write_to_zip(zos)
        end
      else
        Zip::OutputStream.open(path) do |zos|
          write_to_zip(zos)
        end
      end
    end

    def to_xml(xml)
      xml.FictionBook('xmlns' => FB2rb::FB2_NAMESPACE,
                      'xmlns:l' => 'http://www.w3.org/1999/xlink') do
        @description.to_xml(xml)
        @bodies.each do |body|
          xml << body
        end
        @binaries.each do |binary|
          binary.to_xml(xml)
        end
      end
    end

    private

    def write_to_zip(zos)
      # TODO: entry name
      zos.put_next_entry('book.fb2')
      write_to_stream(zos)
    end

    def add_binary_io(name, io, content_type = nil)
      io.binmode
      content = io.read
      @binaries << Binary.new(name, content, content_type)
      self
    end

    # Writes FB2 (uncompressed) to stream specified by the argument.
    def write_to_stream(io)
      builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        to_xml(xml)
      end
      io.write(builder.to_xml)
    end
  end

  # Holds <description> data
  class Description
    attr_reader(:title_info)
    attr_reader(:src_title_info)
    # TODO: document-info, publish-info, custom-info

    def initialize(title_info = TitleInfo.new, src_title_info = nil)
      @title_info = title_info
      @src_title_info = src_title_info
    end

    def self.parse(xml, fb2_prefix)
      title_info_xml = xml.at("./#{fb2_prefix}:title-info")
      src_title_info_xml = xml.at("./#{fb2_prefix}:src-title-info")
      Description.new(
        TitleInfo.parse(title_info_xml, fb2_prefix),
        src_title_info_xml.nil? ? nil : TitleInfo.parse(src_title_info_xml, fb2_prefix)
      )
    end

    def to_xml(xml)
      title_info.to_xml(xml, :'title-info')
      src_title_info&.to_xml(xml, :'src-title-info')
    end
  end

  # Holds <title-info>/<src-title-info> data
  class TitleInfo
    attr_reader(:genres)
    attr_reader(:authors)
    attr_reader(:book_title)
    attr_reader(:annotation)
    attr_reader(:keywords)

    # TODO: date, coverpage, lang, src-lang, translator, sequence

    def initialize(genres = [], authors = [], book_title = '', annotation = nil, keywords = nil)
      @genres = genres
      @authors = authors
      @book_title = book_title
      @annotation = annotation
      @keywords = keywords
    end

    def self.parse(xml, fb2_prefix)
      TitleInfo.new(
        xml.xpath("./#{fb2_prefix}:genre/text()").map(&:text),
        xml.xpath("./#{fb2_prefix}:author").map do |node|
          Author.parse(node, fb2_prefix)
        end,
        xml.at("./#{fb2_prefix}:book-title/text()")&.text,
        # TODO: is it correct?
        xml.at("./#{fb2_prefix}:annotation")&.text,
        xml.at("./#{fb2_prefix}:keywords/text()")&.text
      )
    end

    def to_xml(xml, tag) # rubocop:disable Metrics/MethodLength
      xml.description do
        xml.send(tag) do
          genres.each do |genre|
            xml.genre(genre)
          end
          authors.each do |author|
            author.to_xml(xml)
          end
          xml.send('book-title', @book_title)
          xml << @annotation unless @annotation.nil?
          xml.keywords(@keywords) unless keywords.nil?
        end
      end
    end
  end

  # Holds <author> data
  class Author
    attr_reader(:first_name)
    attr_reader(:middle_name)
    attr_reader(:last_name)
    attr_reader(:nickname)
    attr_reader(:home_pages)
    attr_reader(:emails)
    attr_reader(:id)

    def initialize(first_name = nil, # rubocop:disable Metrics/ParameterLists
                   middle_name = nil,
                   last_name = nil,
                   nickname = nil,
                   home_pages = [],
                   emails = [],
                   id = nil)
      @first_name = first_name
      @middle_name = middle_name
      @last_name = last_name
      @nickname = nickname
      @home_pages = home_pages
      @emails = emails
      @id = id
    end

    def self.parse(xml, fb2_prefix) # rubocop:disable Metrics/CyclomaticComplexity
      Author.new(
        xml.at("./#{fb2_prefix}:first-name/text()")&.text,
        xml.at("./#{fb2_prefix}:middle-name/text()")&.text,
        xml.at("./#{fb2_prefix}:last-name/text()")&.text,
        xml.at("./#{fb2_prefix}:nickname/text()")&.text,
        xml.xpath("./#{fb2_prefix}:home-page/text()").map(&:text),
        xml.xpath("./#{fb2_prefix}:email/text()").map(&:text),
        xml.at("./#{fb2_prefix}:id/text()")&.text
      )
    end

    def to_xml(xml) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
      xml.author do
        xml.send('first-name', @first_name) unless @first_name.nil?
        xml.send('middle-name', @middle_name) unless @middle_name.nil?
        xml.send('last-name', @last_name) unless @last_name.nil?
        xml.nickname(@nickname) unless @nickname.nil?
        @home_pages.each do |home_page|
          xml.send('home-page', home_page)
        end
        @emails.each do |email|
          xml.email(email)
        end
        xml.id(@id) unless @id.nil?
      end
    end
  end

  # Holds data of a single binary within FB2 file
  class Binary
    attr_reader(:id)
    attr_reader(:content)
    attr_reader(:content_type)

    def initialize(name, content, content_type = nil)
      @id = name
      @content = content
      @content_type = content_type
    end

    def self.parse(xml)
      Binary.new(xml['id'], xml.text, xml['content-type'])
    end

    def to_xml(xml)
      xml.binary('id' => @id, 'content-type' => @content_type) do
        xml.text(@content)
      end
    end
  end
end
