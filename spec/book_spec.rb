# frozen_string_literal: true

require 'date'
require 'spec_helper'

describe FB2rb::Book do # rubocop:disable Metrics/BlockLength
  it 'saves and loads to StringIO' do
    b = FB2rb::Book.new

    io = StringIO.new
    b.write(io)

    b2 = FB2rb::Book.read(io)
    expect(b2).not_to be_nil
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
    expect(b2.bodies[0].name).to eq(body.name)
    expect(b2.bodies[0].content.to_s).to eq(body.content)
  end

  it 'has genres' do
    b = FB2rb::Book.new
    b.description.title_info.genres << 'science'

    io = StringIO.new
    b.write(io)

    b2 = FB2rb::Book.read(io)
    expect(b2.description.title_info.genres).to eq(['science'])
  end

  it 'has authors' do
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
    b.description.title_info.authors << a

    io = StringIO.new
    b.write(io)

    b2 = FB2rb::Book.read(io)
    a2 = b2.description.title_info.authors[0]
    expect(a2.first_name).to eq(a.first_name)
    expect(a2.middle_name).to eq(a.middle_name)
    expect(a2.last_name).to eq(a.last_name)
    expect(a2.nickname).to eq(a.nickname)
    expect(a2.home_pages).to eq(a.home_pages)
    expect(a2.emails).to eq(a.emails)
    expect(a2.id).to eq(a.id)
  end

  it 'has book-title' do
    b = FB2rb::Book.new
    b.description.title_info.book_title = 'Bla'

    io = StringIO.new
    b.write(io)

    b2 = FB2rb::Book.read(io)
    expect(b2.description.title_info.book_title).to eq(b.description.title_info.book_title)
  end

  it 'has keywords' do
    b = FB2rb::Book.new
    b.description.title_info.keywords << 'keyword'

    io = StringIO.new
    b.write(io)

    b2 = FB2rb::Book.read(io)
    expect(b2.description.title_info.keywords).to eq(['keyword'])
  end

  it 'has date' do
    b = FB2rb::Book.new
    b.description.title_info.date = FB2rb::FB2Date.new('12 July 2020', Date.parse('2020-07-12'))

    io = StringIO.new
    b.write(io)

    b2 = FB2rb::Book.read(io)
    expect(b2.description.title_info.date.value).to eq(b.description.title_info.date.value)
    expect(b2.description.title_info.date.display_value).to eq(b.description.title_info.date.display_value)
  end

  it 'has cover page' do
    b = FB2rb::Book.new
    b.description.title_info.coverpage = FB2rb::Coverpage.new(['foo.png'])

    io = StringIO.new
    b.write(io)

    b2 = FB2rb::Book.read(io)
    expect(b2.description.title_info.coverpage.images).to eq(b.description.title_info.coverpage.images)
  end

  it 'has translators' do
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
    b.description.title_info.translators << a

    io = StringIO.new
    b.write(io)

    b2 = FB2rb::Book.read(io)
    a2 = b2.description.title_info.translators[0]
    expect(a2.first_name).to eq(a.first_name)
    expect(a2.middle_name).to eq(a.middle_name)
    expect(a2.last_name).to eq(a.last_name)
    expect(a2.nickname).to eq(a.nickname)
    expect(a2.home_pages).to eq(a.home_pages)
    expect(a2.emails).to eq(a.emails)
    expect(a2.id).to eq(a.id)
  end

  it 'has sequences' do
    b = FB2rb::Book.new
    s = FB2rb::Sequence.new('seq', 42)
    b.description.title_info.sequences << s

    io = StringIO.new
    b.write(io)

    b2 = FB2rb::Book.read(io)
    s2 = b2.description.title_info.sequences[0]
    expect(s2.name).to eq(s.name)
    expect(s2.number).to eq(s.number)
  end
end
