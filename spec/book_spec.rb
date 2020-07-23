# frozen_string_literal: true

require 'date'
require 'spec_helper'

describe FB2rb::Book do # rubocop:disable Metrics/BlockLength
  it 'has stylesheets' do
    b = FB2rb::Book.new
    stylesheet = FB2rb::Stylesheet.new('text/css', 'p { color: red; }')
    b.stylesheets << stylesheet

    io = StringIO.new
    b.write(io)

    b2 = FB2rb::Book.read(io)
    stylesheet2 = b2.stylesheets[0]
    expect(stylesheet2).not_to be_nil
    expect(stylesheet2.type).to eq(stylesheet.type)
    expect(stylesheet2.content).to eq(stylesheet.content)
  end

  it 'has binaries' do
    b = FB2rb::Book.new
    b.add_binary 'file', StringIO.new('text'), 'text/plain'

    expect(b.binaries.size).to eq(1)

    io = StringIO.new
    b.write(io)

    b2 = FB2rb::Book.read(io)
    expect(b2.binaries.size).to eq(1)
  end

  it 'has bodies' do
    b = FB2rb::Book.new
    body = FB2rb::Body.new('bla', '<p>text</p>')
    b.bodies << body

    io = StringIO.new
    b.write(io)

    b2 = FB2rb::Book.read(io)
    body2 = b2.bodies[0]
    expect(body2).not_to be_nil
    expect(body2.name).to eq(body.name)
    expect(body2.content).to match(%r{<p( xmlns=".*")?>text</p>})
  end

  it 'has title info' do # rubocop:disable Metrics/BlockLength
    b = FB2rb::Book.new
    b.description.title_info.genres << 'science'
    b.description.title_info.book_title = 'Bla'
    b.description.title_info.annotation = '<empty-line/>'
    b.description.title_info.keywords << 'keyword'
    b.description.title_info.date = FB2rb::FB2Date.new('12 July 2020', Date.parse('2020-07-12'))
    b.description.title_info.coverpage = FB2rb::Coverpage.new(['foo.png'])
    a = FB2rb::Author.new(
      'Marat',
      'Spartakovich',
      'Radchenko',
      'Slonopotamus',
      ['https://slonopotamus.org'],
      ['marat@slonopotamus.org'],
      'slonopotamus'
    )
    b.description.title_info.authors << a
    b.description.title_info.translators << a
    s = FB2rb::Sequence.new('seq', 42)
    b.description.title_info.sequences << s

    io = StringIO.new
    b.write(io)

    b2 = FB2rb::Book.read(io)
    expect(b2.description.title_info.genres).to eq(['science'])
    expect(b2.description.title_info.book_title).to eq(b.description.title_info.book_title)
    expect(b2.description.title_info.keywords).to eq(['keyword'])
    expect(b2.description.title_info.annotation).to match(%r{<empty-line( xmlns=".*")?/>})
    expect(b2.description.title_info.date.value).to eq(b.description.title_info.date.value)
    expect(b2.description.title_info.date.display_value).to eq(b.description.title_info.date.display_value)
    expect(b2.description.title_info.coverpage.images).to eq(b.description.title_info.coverpage.images)

    a2 = b2.description.title_info.authors[0]
    expect(a2).not_to be_nil
    expect(a2.first_name).to eq(a.first_name)
    expect(a2.middle_name).to eq(a.middle_name)
    expect(a2.last_name).to eq(a.last_name)
    expect(a2.nickname).to eq(a.nickname)
    expect(a2.home_pages).to eq(a.home_pages)
    expect(a2.emails).to eq(a.emails)
    expect(a2.id).to eq(a.id)

    t2 = b2.description.title_info.translators[0]
    expect(t2.first_name).to eq(a.first_name)
    expect(t2.middle_name).to eq(a.middle_name)
    expect(t2.last_name).to eq(a.last_name)
    expect(t2.nickname).to eq(a.nickname)
    expect(t2.home_pages).to eq(a.home_pages)
    expect(t2.emails).to eq(a.emails)
    expect(t2.id).to eq(a.id)

    s2 = b2.description.title_info.sequences[0]
    expect(s2).not_to be_nil
    expect(s2.name).to eq(s.name)
    expect(s2.number).to eq(s.number)
  end

  it 'has document info' do # rubocop:disable Metrics/BlockLength
    b = FB2rb::Book.new
    a = FB2rb::Author.new(
      'Marat',
      'Spartakovich',
      'Radchenko',
      'Slonopotamus',
      ['https://slonopotamus.org'],
      ['marat@slonopotamus.org'],
      'slonopotamus'
    )
    b.description.document_info.authors << a
    b.description.document_info.program_used = '/dev/hands'
    b.description.document_info.date = FB2rb::FB2Date.new('12 July 2020', Date.parse('2020-07-12'))
    b.description.document_info.src_urls << 'https://slonopotamus.org'
    b.description.document_info.src_ocr = '/dev/eyes'
    b.description.document_info.version = '0.1'
    b.description.document_info.history = '<empty-line/>'
    b.description.document_info.publishers << 'MyPublisher'

    io = StringIO.new
    b.write(io)

    b2 = FB2rb::Book.read(io)
    expect(b2.description.document_info.program_used).to eq(b.description.document_info.program_used)
    expect(b2.description.document_info.date.display_value).to eq(b.description.document_info.date.display_value)
    expect(b2.description.document_info.date.value).to eq(b.description.document_info.date.value)
    expect(b2.description.document_info.src_urls).to eq(b.description.document_info.src_urls)
    expect(b2.description.document_info.version).to eq(b.description.document_info.version)
    expect(b2.description.document_info.history).to match(%r{<empty-line( xmlns=".*")?/>})
    expect(b2.description.document_info.publishers).to eq(b.description.document_info.publishers)

    a2 = b2.description.document_info.authors[0]
    expect(a2).not_to be_nil
    expect(a2.first_name).to eq(a.first_name)
    expect(a2.middle_name).to eq(a.middle_name)
    expect(a2.last_name).to eq(a.last_name)
    expect(a2.nickname).to eq(a.nickname)
    expect(a2.home_pages).to eq(a.home_pages)
    expect(a2.emails).to eq(a.emails)
    expect(a2.id).to eq(a.id)
  end

  it 'has publish info' do
    b = FB2rb::Book.new
    b.description.publish_info = FB2rb::PublishInfo.new
    b.description.publish_info.book_name = 'Book'
    b.description.publish_info.publisher = 'Publisher'
    b.description.publish_info.city = 'Moscow'
    b.description.publish_info.year = '2020'
    b.description.publish_info.isbn = '12345'
    s = FB2rb::Sequence.new('seq', 42)
    b.description.publish_info.sequences << s

    io = StringIO.new
    b.write(io)

    b2 = FB2rb::Book.read(io)
    expect(b2.description.publish_info.book_name).to eq(b.description.publish_info.book_name)
    expect(b2.description.publish_info.publisher).to eq(b.description.publish_info.publisher)
    expect(b2.description.publish_info.city).to eq(b.description.publish_info.city)
    expect(b2.description.publish_info.year).to eq(b.description.publish_info.year)
    expect(b2.description.publish_info.isbn).to eq(b.description.publish_info.isbn)

    s2 = b2.description.publish_info.sequences[0]
    expect(s2).not_to be_nil
    expect(s2.name).to eq(s.name)
    expect(s2.number).to eq(s.number)
  end

  it 'has custom info' do
    b = FB2rb::Book.new
    c = FB2rb::CustomInfo.new('fb2rb', 'custom data')
    b.description.custom_infos << c

    io = StringIO.new
    b.write(io)

    b2 = FB2rb::Book.read(io)
    c2 = b2.description.custom_infos[0]
    expect(c2).not_to be_nil
    expect(c2.info_type).to eq(c.info_type)
    expect(c2.content).to eq(c.content)
  end
end
