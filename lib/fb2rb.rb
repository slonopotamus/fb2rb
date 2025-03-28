# frozen_string_literal: true

require 'date'
require 'fb2rb/version'
require 'nokogiri'
require 'zip'

# Fiction Book 2 parser/generator library
module FB2rb
  FB2_NAMESPACE = 'http://www.gribuser.ru/xml/fictionbook/2.0'
  XLINK_NAMESPACE = 'http://www.w3.org/1999/xlink'

  # Holds data of a single FB2 file
  class Book # rubocop:disable Metrics/ClassLength
    # @return [Array<FB2rb::Stylesheet>]
    attr_accessor(:stylesheets)
    # @return [FB2rb::Description]
    attr_accessor(:description)
    # @return [Array<FB2rb::Body>]
    attr_accessor(:bodies)
    # @return [Array<FB2fb::Binary>]
    attr_accessor(:binaries)

    def initialize(description: Description.new, bodies: [], binaries: [], stylesheets: [])
      @binaries = binaries
      @bodies = bodies
      @description = description
      @stylesheets = stylesheets
    end

    class << self
      # Reads existing compressed FB2 file from an IO object, and creates new Book object.
      # @return [FB2rb::Book, nil]
      def read_compressed(filename_or_io)
        Zip::InputStream.open(filename_or_io) do |zis|
          while (entry = zis.get_next_entry)
            next if entry.directory?

            xml = Nokogiri::XML::Document.parse(zis)
            fb2_prefix = ns_prefix(FB2rb::FB2_NAMESPACE, xml.namespaces)
            xlink_prefix = ns_prefix(FB2rb::XLINK_NAMESPACE, xml.namespaces)
            return parse(xml, fb2_prefix, xlink_prefix)
          end
        end
        nil
      end

      # Reads existing uncompressed FB2 file from an IO object, and creates new Book object.
      # @return [FB2rb::Book]
      def read_uncompressed(filename_or_io)
        xml = read_xml(filename_or_io)
        fb2_prefix = ns_prefix(FB2rb::FB2_NAMESPACE, xml.namespaces)
        xlink_prefix = ns_prefix(FB2rb::XLINK_NAMESPACE, xml.namespaces)
        parse(xml, fb2_prefix, xlink_prefix)
      end

      def ns_prefix(namespace, namespaces)
        prefix = namespaces.key(namespace)
        prefix&.sub(/^xmlns:/, '')
      end

      private

      # @return [FB2rb::Book]
      def parse(xml, fb2_prefix, xlink_prefix) # rubocop:disable Metrics/MethodLength
        Book.new(
          description: Description.parse(
            xml.xpath("/#{fb2_prefix}:FictionBook/#{fb2_prefix}:description"), fb2_prefix, xlink_prefix
          ),
          bodies: xml.xpath("/#{fb2_prefix}:FictionBook/#{fb2_prefix}:body").map do |node|
            Body.parse(node)
          end,
          binaries: xml.xpath("#{fb2_prefix}:FictionBook/#{fb2_prefix}:binary").map do |node|
            Binary.parse(node)
          end,
          stylesheets: xml.xpath("/#{fb2_prefix}:FictionBook/#{fb2_prefix}:stylesheet").map do |node|
            Stylesheet.parse(node)
          end
        )
      end

      def read_xml(filename_or_io)
        if filename_or_io.respond_to? :read
          Nokogiri::XML::Document.parse(filename_or_io)
        else
          File.open(filename_or_io, 'rb') do |io|
            return Nokogiri::XML::Document.parse(io)
          end
        end
      end
    end

    def to_xml(xml) # rubocop:disable Metrics/MethodLength
      xml.FictionBook('xmlns' => FB2rb::FB2_NAMESPACE,
                      'xmlns:l' => 'http://www.w3.org/1999/xlink') do
        @stylesheets.each do |stylesheet|
          stylesheet.to_xml(xml)
        end
        @description.to_xml(xml)
        @bodies.each do |body|
          body.to_xml(xml)
        end
        @binaries.each do |binary|
          binary.to_xml(xml)
        end
      end
    end

    def add_binary(id, filename_or_io, content_type = nil)
      if filename_or_io.respond_to?(:read)
        add_binary_io id, filename_or_io, content_type
      else
        File.open(filename_or_io, 'r') do |io|
          add_binary_io id, io, content_type
        end
      end
    end

    def add_stylesheet(content_type, filename_or_io)
      if filename_or_io.respond_to?(:read)
        add_stylesheet_io(content_type, filename_or_io)
      else
        File.open(filename_or_io, 'r') do |io|
          add_stylesheet_io(content_type, io)
        end
      end
    end

    # Writes compressed FB2 to file or IO object. If file exists, it will be overwritten.
    def write_compressed(filename_or_io = StringIO.new)
      if filename_or_io.respond_to?(:write)
        Zip::OutputStream.write_buffer(filename_or_io) do |zos|
          write_to_zip(zos)
        end
      else
        Zip::OutputStream.open(filename_or_io) do |zos|
          write_to_zip(zos)
        end
      end
    end

    # Writes FB2 (uncompressed) to file or IO object specified by the argument.
    def write_uncompressed(filename_or_io = StringIO.new)
      data = (Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
        to_xml(xml)
      end).to_xml

      if filename_or_io.respond_to?(:write)
        filename_or_io.write(data)
      else
        File.binwrite(filename_or_io, data)
      end
      filename_or_io
    end

    private

    def write_to_zip(zos)
      mod_time = Zip::DOSTime.now
      unless (tm = description.document_info.date.value).nil?
        mod_time = Zip::DOSTime.gm(tm.year, tm.month, tm.day)
      end

      # TODO: entry name
      mimetype_entry = Zip::Entry.new(nil, 'book.fb2', nil, nil, nil, nil, nil, nil, mod_time)
      zos.put_next_entry(mimetype_entry, nil, nil, Zip::Entry::DEFLATED)
      write_uncompressed(zos)
    end

    def add_binary_io(id, io, content_type = nil)
      io.binmode
      content = io.read
      @binaries << Binary.new(id: id, content: content, content_type: content_type)
      self
    end

    def add_stylesheet_io(content_type, io)
      io.binmode
      content = io.read
      @stylesheets << Stylesheet.new(content_type: content_type, content: content)
      self
    end
  end

  # Holds <description> data
  class Description
    # @return [FB2rb::TitleInfo]
    attr_accessor(:title_info)
    # @return [FB2rb::TitleInfo, nil]
    attr_accessor(:src_title_info)
    # @return [FB2rb::DocumentInfo]
    attr_accessor(:document_info)
    # @return [FB2rb::PublishInfo, nil]
    attr_accessor(:publish_info)
    # @return [Array<FB2rb::CustomInfo>]
    attr_accessor(:custom_infos)

    # TODO: <output>

    def initialize(title_info: TitleInfo.new,
                   document_info: DocumentInfo.new,
                   publish_info: nil,
                   src_title_info: nil,
                   custom_infos: [])
      @title_info = title_info
      @document_info = document_info
      @publish_info = publish_info
      @src_title_info = src_title_info
      @custom_infos = custom_infos
    end

    # @return [FB2rb::Description]
    def self.parse(xml, fb2_prefix, xlink_prefix) # rubocop:disable Metrics/MethodLength
      publish_info_xml = xml.at("./#{fb2_prefix}:publish-info")
      src_title_info_xml = xml.at("./#{fb2_prefix}:src-title-info")
      Description.new(
        title_info: TitleInfo.parse(xml.at("./#{fb2_prefix}:title-info"), fb2_prefix, xlink_prefix),
        document_info: DocumentInfo.parse(xml.at("./#{fb2_prefix}:document-info"), fb2_prefix),
        publish_info: publish_info_xml.nil? ? nil : PublishInfo.parse(publish_info_xml, fb2_prefix),
        src_title_info: src_title_info_xml.nil? ? nil : TitleInfo.parse(src_title_info_xml, fb2_prefix, xlink_prefix),
        custom_infos: xml.xpath("./#{fb2_prefix}:custom-info").map do |node|
          CustomInfo.parse(node)
        end
      )
    end

    def to_xml(xml)
      xml.description do
        @title_info.to_xml(xml, :'title-info')
        @src_title_info&.to_xml(xml, :'src-title-info')
        @document_info.to_xml(xml)
        @publish_info&.to_xml(xml)
        @custom_infos.each do |custom_info|
          custom_info.to_xml(xml)
        end
      end
    end
  end

  # Holds <stylesheet> data
  class Stylesheet
    # @return [String]
    attr_accessor(:content_type)
    # @return [String, nil]
    attr_accessor(:content)

    def initialize(content_type: '', content: nil)
      @content_type = content_type
      @content = content
    end

    def self.parse(xml)
      Stylesheet.new(content_type: xml['type'], content: xml.text)
    end

    def to_xml(xml)
      return if @content.nil?

      xml.send('stylesheet', @content, 'type' => @content_type)
    end
  end

  # Holds <custom-info> data
  class CustomInfo
    # @return [String]
    attr_accessor(:type)
    # @return [String, nil]
    attr_accessor(:content)

    def initialize(type: '', content: nil)
      @type = type
      @content = content
    end

    # @return [FB2rb::CustomInfo]
    def self.parse(xml)
      CustomInfo.new(type: xml['info-type'], content: xml.text)
    end

    def to_xml(xml)
      return if @content.nil?

      xml.send('custom-info', @content, 'info-type' => @type)
    end
  end

  # Holds <publish-info> data
  class PublishInfo
    # @return [String, nil]
    attr_accessor(:book_name)
    # @return [String, nil]
    attr_accessor(:publisher)
    # @return [String, nil]
    attr_accessor(:city)
    # @return [String, nil]
    attr_accessor(:year)
    # @return [String, nil]
    attr_accessor(:isbn)
    # @return [Array<FB2RB::Sequence>]
    attr_accessor(:sequences)

    def initialize(book_name: nil, # rubocop:disable Metrics/ParameterLists
                   publisher: nil,
                   city: nil,
                   year: nil,
                   isbn: nil,
                   sequences: [])
      @book_name = book_name
      @publisher = publisher
      @city = city
      @year = year
      @isbn = isbn
      @sequences = sequences
    end

    # @return [FB2RB::PublishInfo]
    def self.parse(xml, fb2_prefix)
      PublishInfo.new(
        book_name: xml.at("./#{fb2_prefix}:book-name/text()")&.text,
        publisher: xml.at("./#{fb2_prefix}:publisher/text()")&.text,
        city: xml.at("./#{fb2_prefix}:city/text()")&.text,
        year: xml.at("./#{fb2_prefix}:year/text()")&.text,
        isbn: xml.at("./#{fb2_prefix}:isbn/text()")&.text,
        sequences: xml.xpath("./#{fb2_prefix}:sequence").map do |node|
          Sequence.parse(node)
        end
      )
    end

    def to_xml(xml)
      xml.send('publish-info') do
        xml.send('book-name', @book_name) unless @book_name.nil?
        xml.publisher(@publisher) unless @publisher.nil?
        xml.city(@city) unless @city.nil?
        xml.year(@year) unless @year.nil?
        xml.isbn(@isbn) unless @isbn.nil?
        @sequences.each do |sequence|
          sequence.to_xml(xml)
        end
      end
    end
  end

  # Holds <document-info> data
  class DocumentInfo
    # @return [Array<FB2rb::Author>]
    attr_accessor(:authors)
    # @return [String, nil]
    attr_accessor(:program_used)
    # @return [FB2rb::FB2Date]
    attr_accessor(:date)
    # @return [Array<String>]
    attr_accessor(:src_urls)
    # @return [String, nil]
    attr_accessor(:src_ocr)
    # @return [String]
    attr_accessor(:id)
    # @return [String]
    attr_accessor(:version)
    # @return [String, nil]
    attr_accessor(:history)
    # @return [Array<String>]
    attr_accessor(:publishers)

    def initialize(authors: [], # rubocop:disable Metrics/ParameterLists
                   program_used: nil,
                   date: FB2Date.new,
                   src_urls: [],
                   src_ocr: nil,
                   id: '',
                   version: '',
                   history: nil,
                   publishers: [])
      @authors = authors
      @program_used = program_used
      @date = date
      @src_urls = src_urls
      @src_ocr = src_ocr
      @id = id
      @version = version
      @history = history
      @publishers = publishers
    end

    # @return [FB2rb::DocumentInfo]
    def self.parse(xml, fb2_prefix) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      date = xml.at("./#{fb2_prefix}:date")
      DocumentInfo.new(
        authors: xml.xpath("./#{fb2_prefix}:author").map do |node|
          Author.parse(node, fb2_prefix)
        end,
        program_used: xml.at("./#{fb2_prefix}:program-used")&.text,
        date: date.nil? ? FB2Date.new : FB2Date.parse(date),
        src_urls: xml.xpath("./#{fb2_prefix}:src-url").map(&:text),
        src_ocr: xml.at("./#{fb2_prefix}:src-ocr")&.text,
        id: xml.at("./#{fb2_prefix}:id").text,
        version: xml.at("./#{fb2_prefix}:version")&.text,
        history: xml.at("./#{fb2_prefix}:history")&.children&.to_s&.strip,
        publishers: xml.xpath("./#{fb2_prefix}:publisher").map(&:text)
      )
    end

    def to_xml(xml) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength
      xml.send(:'document-info') do
        @authors.each do |author|
          author.to_xml(xml, 'author')
        end
        xml.send('program-used', @program_used) unless @program_used.nil?
        @date.to_xml(xml)
        @src_urls.each do |src_url|
          xml.send('src-url', src_url)
        end
        xml.send('src-ocr', @src_ocr) unless @src_ocr.nil?
        xml.id(@id)
        xml.version(@version) unless @version.nil?
        unless @history.nil?
          xml.history do
            xml << @history
          end
        end
        @publishers.each do |publisher|
          xml.publisher(publisher)
        end
      end
    end
  end

  # Holds <title-info>/<src-title-info> data
  class TitleInfo
    # @return [Array<String>]
    attr_accessor(:genres)
    # @return [Array<FB2rb::Author>]
    attr_accessor(:authors)
    # @return [String]
    attr_accessor(:book_title)
    # @return [String, nil]
    attr_accessor(:annotation)
    # @return [Array<String>]
    attr_accessor(:keywords)
    # @return [FB2rb::Date, nil]
    attr_accessor(:date)
    # @return [FB2rb::Coverpage, nil]
    attr_accessor(:coverpage)
    # @return [String]
    attr_accessor(:lang)
    # @return [String, nil]
    attr_accessor(:src_lang)
    # @return [Array<FB2rb::Author>]
    attr_accessor(:translators)
    # @return [Array<FB2rb::Sequence>]
    attr_accessor(:sequences)

    def initialize(genres: [], # rubocop:disable Metrics/MethodLength, Metrics/ParameterLists
                   authors: [],
                   book_title: '',
                   annotation: nil,
                   keywords: [],
                   date: nil,
                   coverpage: nil,
                   lang: 'en',
                   src_lang: nil,
                   translators: [],
                   sequences: [])
      @genres = genres
      @authors = authors
      @book_title = book_title
      @annotation = annotation
      @keywords = keywords
      @date = date
      @coverpage = coverpage
      @lang = lang
      @src_lang = src_lang
      @translators = translators
      @sequences = sequences
    end

    # @return [FB2rb::TitleInfo]
    def self.parse(xml, fb2_prefix, xlink_prefix) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      date = xml.at("./#{fb2_prefix}:date")
      coverpage = xml.at("./#{fb2_prefix}:coverpage")
      TitleInfo.new(
        genres: xml.xpath("./#{fb2_prefix}:genre/text()").map(&:text),
        authors: xml.xpath("./#{fb2_prefix}:author").map do |node|
          Author.parse(node, fb2_prefix)
        end,
        book_title: xml.at("./#{fb2_prefix}:book-title/text()")&.text,
        annotation: xml.at("./#{fb2_prefix}:annotation")&.children.to_s.strip,
        keywords: xml.at("./#{fb2_prefix}:keywords/text()")&.text&.split(', ') || [],
        date: date.nil? ? nil : FB2Date.parse(date),
        coverpage: coverpage.nil? ? nil : Coverpage.parse(coverpage, fb2_prefix, xlink_prefix),
        lang: xml.at("./#{fb2_prefix}:lang/text()").text,
        src_lang: xml.at("./#{fb2_prefix}:src-lang/text()")&.text,
        translators: xml.xpath("./#{fb2_prefix}:translator").map do |node|
          Author.parse(node, fb2_prefix)
        end,
        sequences: xml.xpath("./#{fb2_prefix}:sequence").map do |node|
          Sequence.parse(node)
        end
      )
    end

    def to_xml(xml, tag) # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
      xml.send(tag) do
        genres.each do |genre|
          xml.genre(genre)
        end
        authors.each do |author|
          author.to_xml(xml, 'author')
        end
        xml.send('book-title', @book_title)
        unless @annotation.nil?
          xml.annotation do
            xml << @annotation
          end
        end
        xml.keywords(@keywords.join(', ')) unless keywords.nil?
        @date.to_xml(xml) unless date.nil?
        @coverpage.to_xml(xml) unless coverpage.nil?
        xml.lang(@lang)
        xml.send('src-lang') unless src_lang.nil?
        @translators.each do |translator|
          translator.to_xml(xml, 'translator')
        end
        @sequences.each do |sequence|
          sequence.to_xml(xml)
        end
      end
    end
  end

  # Holds <coverpage> data
  class Coverpage
    # @return [Array<String>]
    attr_accessor(:images)

    def initialize(images: [])
      @images = images
    end

    def self.parse(xml, fb2_prefix, xlink_prefix)
      Coverpage.new(
        images: xml.xpath("./#{fb2_prefix}:image/@#{xlink_prefix}:href").map(&:to_s)
      )
    end

    def to_xml(xml)
      xml.coverpage do
        @images.each do |image|
          xml.image('l:href' => image)
        end
      end
    end
  end

  # Holds <date> data
  class FB2Date
    # @return [String]
    attr_accessor(:display_value)
    # @return [Date, nil]
    attr_accessor(:value)

    def initialize(display_value: '', value: nil)
      @display_value = display_value
      @value = value
    end

    def self.parse(xml)
      value = xml['value']
      FB2Date.new(
        display_value: xml.at('./text()')&.text || '',
        value: value.nil? ? nil : Date.parse(value)
      )
    end

    def to_xml(xml)
      xml.date(@display_value) do
        xml.parent['value'] = @value.to_s unless value.nil?
      end
    end
  end

  # Holds <sequence> data
  class Sequence
    # @return [String]
    attr_accessor(:name)
    # @return [Integer, nil]
    attr_accessor(:number)

    def initialize(name: '', number: nil)
      @name = name
      @number = number
    end

    # @return [FB2rb::Sequence]
    def self.parse(xml)
      Sequence.new(name: xml['name'], number: xml['number']&.to_i)
    end

    def to_xml(xml)
      xml.send('sequence', 'name' => @name) do
        xml.parent['number'] = @number unless @number.nil?
      end
    end
  end

  # Holds <author> data
  class Author
    # @return [String, nil]
    attr_accessor(:first_name)
    # @return [String, nil]
    attr_accessor(:middle_name)
    # @return [String, nil]
    attr_accessor(:last_name)
    # @return [String, nil]
    attr_accessor(:nickname)
    # @return [Array<String>]
    attr_accessor(:home_pages)
    # @return [Array<String>]
    attr_accessor(:emails)
    # @return [String, nil]
    attr_accessor(:id)

    def initialize(first_name: nil, # rubocop:disable Metrics/ParameterLists
                   middle_name: nil,
                   last_name: nil,
                   nickname: nil,
                   home_pages: [],
                   emails: [],
                   id: nil)
      @first_name = first_name
      @middle_name = middle_name
      @last_name = last_name
      @nickname = nickname
      @home_pages = home_pages
      @emails = emails
      @id = id
    end

    # @return [FB2rb::Author]
    def self.parse(xml, fb2_prefix) # rubocop:disable Metrics/CyclomaticComplexity
      Author.new(
        first_name: xml.at("./#{fb2_prefix}:first-name/text()")&.text,
        middle_name: xml.at("./#{fb2_prefix}:middle-name/text()")&.text,
        last_name: xml.at("./#{fb2_prefix}:last-name/text()")&.text,
        nickname: xml.at("./#{fb2_prefix}:nickname/text()")&.text,
        home_pages: xml.xpath("./#{fb2_prefix}:home-page/text()").map(&:text),
        emails: xml.xpath("./#{fb2_prefix}:email/text()").map(&:text),
        id: xml.at("./#{fb2_prefix}:id/text()")&.text
      )
    end

    def to_xml(xml, tag) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/MethodLength
      xml.send(tag) do
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

  # Holds <body> data
  class Body
    # @return [String, nil]
    attr_accessor(:name)
    # @return [String]
    attr_accessor(:content)

    def initialize(name: nil, content: '')
      @name = name
      @content = content
    end

    # @return [FB2rb::Body]
    def self.parse(xml)
      Body.new(
        name: xml['name'],
        content: xml.children.to_s.strip
      )
    end

    def to_xml(xml)
      return if @content.nil?

      xml.body do
        xml.parent['name'] = @name unless @name.nil?
        xml << @content
      end
    end
  end

  # Holds data of a single binary within FB2 file
  class Binary
    # @return [String]
    attr_accessor(:id)
    # @return [String]
    attr_accessor(:content)
    # @return [String, nil]
    attr_accessor(:content_type)

    def initialize(id: nil, content: ''.b, content_type: nil)
      @id = id
      @content = content
      @content_type = content_type
    end

    def self.parse(xml)
      decoded = xml.text.unpack1('m0')
      Binary.new(id: xml['id'], content: decoded, content_type: xml['content-type'])
    end

    def to_xml(xml)
      encoded = [@content].pack('m0')
      xml.binary(encoded, 'id' => @id, 'content-type' => @content_type)
    end
  end
end
