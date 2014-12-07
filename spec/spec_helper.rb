ENV['RAILS_ENV'] ||= 'test'

require 'dummy_rails_app'
require 'dump_rake'

ActiveRecord::Base.logger = Logger.new(File.join(DumpRake::RailsRoot, 'log/dump.log'))

class Chicken < ActiveRecord::Base
end

def grab_output
  real_stdout, $stdout = $stdout, StringIO.new
  real_stderr, $stderr = $stderr, StringIO.new
  begin
    yield
    {:stdout => $stdout.string, :stderr => $stderr.string}
  ensure
    $stdout = real_stdout
    $stderr = real_stderr
  end
end
