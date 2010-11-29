require 'spec/rake/spectask'

desc 'Default: run specs.'
task :default => :spec_with_rcov_and_open

desc 'Run the specs'
Spec::Rake::SpecTask.new(:spec) do |t|
  t.spec_opts = ['--colour --format progress --loadby mtime --reverse']
  t.spec_files = FileList['spec/**/*_spec.rb']
end

desc 'Run the specs with RCov'
Spec::Rake::SpecTask.new(:spec_with_rcov) do |t|
  t.spec_opts = ['--colour --format progress --loadby mtime --reverse']
  t.spec_files = FileList['spec/**/*_spec.rb']
  t.rcov = true
  t.rcov_opts = ['--exclude', '^/,spec,gems,lib/shell_escape,lib/continious_timeout']
end

task :spec_with_rcov_and_open => :spec_with_rcov do
  `open coverage/index.html`
end

desc 'unpack latest gems'
task :unpack_gems do
  rm_r 'gems' rescue nil
  mkpath 'gems'
  %w[progress archive-tar-minitar].each do |gem_name|
    sh *%W[gem unpack #{gem_name} --target=gems]
  end
end

desc 'update readme from env'
task :update_readme do
  $: << File.join(File.dirname(__FILE__), 'lib')
  require 'pathname'
  require 'dump_rake'

  readme = Pathname('README.rdoc')
  lines = readme.readlines.map(&:rstrip)
  readme.open('w') do |f|
    lines.each do |line|
      line.sub!(/^<tt>(.+?)<\/tt>.*—.*$/) do
        key, names = DumpRake::Env::DICTIONARY.find{ |key, values| values.include?($1) }
        if key
          names = names.map{ |name| "<tt>#{name}</tt>" }.join(', ')
          explanation = DumpRake::Env::EXPLANATIONS[key]
          "#{names} — #{explanation}"
        end
      end
      f.puts line
    end
  end
end
