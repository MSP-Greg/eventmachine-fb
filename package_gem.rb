# frozen_string_literal: true

require 'rubygems'
require 'rubygems/package'

Dir.chdir ('./eventmachine') {
  spec = Gem::Specification::load("./eventmachine.gemspec")
  spec.required_ruby_version = ['>= 2.0', '< 2.6']
  spec.extensions = []
  spec.files.concat ['Rakefile', 'Rakefile_wintest', 'lib/fastfilereaderext.rb', 'lib/rubyeventmachine.rb']
  spec.files.concat Dir['lib/**/*.so']
  spec.platform = ARGV[0]

  spec.metadata.delete("msys2_mingw_dependencies") if spec.respond_to?(:metadata=)

  Gem::Package.build(spec)
}