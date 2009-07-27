class Integer
  # note that Progress.step is called automatically
  # ==== Example
  #   100.times_with_progress('Numbers') do |number|
  #     sleep(number)
  #   end
  def times_with_progress(name, options = {})
    Progress.start(name, self, options) do
      times do |i|
        yield i
        Progress.step
      end
    end
  end
end
