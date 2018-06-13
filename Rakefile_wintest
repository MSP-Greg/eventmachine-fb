# Run with rake -N -R norakefiles

require "rake/testtask"

Rake::TestTask.new(:win_test) do |t|
  t.libs << "tests"
  t.test_files = FileList['tests/**/test_*.rb']
  t.warning = true
  t.options = '--verbose --no-show-detail-immediately'
end

task :default => [:win_test]
