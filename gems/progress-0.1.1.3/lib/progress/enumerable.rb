require 'enumerator'
module Enumerable
  # executes any Enumerable method with progress
  # note that methods which don't necessarily go through all items (like find or any?) will not show 100%
  # ==== Example
  #   [1, 2, 3].with_progress('Numbers').each do |number|
  #     sleep(number)
  #   end
  #   [1, 2, 3].with_progress('Numbers').each_cons(2) do |numbers|
  #     p numbers
  #   end
  def with_progress(title)
    Progress::WithProgress.new(self, title)
  end

  # note that Progress.step is called automatically
  # ==== Example
  #   [1, 2, 3].each_with_progress('Numbers') do |number|
  #     sleep(number)
  #   end
  def each_with_progress(title, *args, &block)
    with_progress(title).each(*args, &block)
  end

  # note that Progress.step is called automatically
  # ==== Example
  #   [1, 2, 3].each_with_index_and_progress('Numbers') do |number, index|
  #     sleep(number)
  #   end
  def each_with_index_and_progress(title, *args, &block)
    with_progress(title).each_with_index(*args, &block)
  end

end
