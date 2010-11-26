module Kernel
  def Progress(title = nil, total = nil, &block)
    Progress.start(title, total, &block)
  end
  private :Progress
end
