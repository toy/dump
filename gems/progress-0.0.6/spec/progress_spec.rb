require File.dirname(__FILE__) + '/spec_helper.rb'

describe Progress do
  before :each do
    @io = StringIO.new
    Progress.io = @io
  end
  
  def io_pop
    @io.seek(0)
    s = @io.read
    @io.truncate(0)
    @io.seek(0)
    s
  end

  def verify_output_before_step(i)
    io_pop.should =~ /#{Regexp.quote(i == 0 ? '......' : (i / 10.0).to_s)}/
  end
  def verify_output_after_stop
    io_pop.should =~ /100\.0.*\n$/
  end

  it "should show valid output for procedural version" do
    Progress.start('Test', 1000)
    1000.times do |i|
      verify_output_before_step(i)
      Progress.step
    end
    Progress.stop
    verify_output_after_stop
  end
  
  it "should show valid output for block version" do
    Progress.start('Test', 1000) do
      1000.times do |i|
        verify_output_before_step(i)
        Progress.step
      end
    end
    verify_output_after_stop
  end

  describe Enumerable do
    before :each do
      @a = Array.new(1000){ |n| n }
    end

    describe 'with each_with_progress' do
      it "should not break each" do
        c = 0
        @a.each_with_progress('Test') do |n|
          n.should == @a[c]
          c += 1
        end
      end

      it "should show valid output for each_with_progress" do
        @a.each_with_progress('Test') do |n|
          verify_output_before_step(n)
        end
        verify_output_after_stop
      end
    end

    describe 'with each_with_index_and_progress' do
      it "should not break each_with_index" do
        c = 0
        @a.each_with_index_and_progress('Test') do |n, i|
          n.should == @a[c]
          i.should == @a[c]
          c += 1
        end
      end

      it "should show valid output for each_with_progress" do
        @a.each_with_index_and_progress('Test') do |n, i|
          verify_output_before_step(n)
        end
        verify_output_after_stop
      end
    end
  end

  describe Integer do
    describe 'with times_with_progress' do
      it "should not break times" do
        c = 0
        1000.times_with_progress('Test') do |i|
          i.should == c
          c += 1
        end
      end

      it "should show valid output for each_with_progress" do
        1000.times_with_progress('Test') do |i|
          verify_output_before_step(i)
        end
        verify_output_after_stop
      end
    end
  end

  it "should allow enclosed progress" do
    10.times_with_progress('A') do |a|
      io_pop.should =~ /#{Regexp.quote(a == 0 ? '......' : (a * 10.0).to_s)}/
      10.times_with_progress('B') do |b|
        io_pop.should =~ /#{Regexp.quote(a == 0 ? '......' : (a * 10.0).to_s)}.*#{Regexp.quote(b == 0 ? '......' : (b * 10.0).to_s)}/
      end
      io_pop.should =~ /#{Regexp.quote(a == 0 ? '......' : (a * 10.0).to_s)}.*100\.0/
    end
    io_pop.should =~ /100\.0.*\n$/
  end

  it "should pipe result from block" do
    Progress.start('Test') do
      'qwerty'
    end.should == 'qwerty'
  end
end
