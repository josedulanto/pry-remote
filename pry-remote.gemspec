require_relative './lib/pry/remote/version'

Gem::Specification.new do |s|
  s.name = 'pry-remote'

  s.version = Pry::Remote::VERSION

  s.summary     = 'Connect to Pry remotely'
  s.description = 'Connect to Pry remotely using DRb'
  s.homepage    = 'http://github.com/kevinthompson/pry-remote'

  s.email   = 'email@kevinthompson.info'
  s.authors = ['Kevin Thompson', 'Mon Ouie']

  s.files |= Dir['lib/**/*.rb']
  s.files |= Dir['*.md']
  s.files << 'LICENSE'

  s.require_paths = ['lib']
  s.add_dependency 'pry', '~> 0.11'
  s.executables = ['pry-remote']
end
