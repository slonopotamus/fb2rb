# frozen_string_literal: true

require 'spec_helper'

describe FB2rb::Book do
  it 'saves and loads' do
    b = FB2rb::Book.new

    io = StringIO.new
    b.write(io)

    b2 = FB2rb::Book.parse(io)
    expect(b2).not_to be_nil
  end
end
