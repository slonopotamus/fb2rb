# frozen_string_literal: true

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
end
